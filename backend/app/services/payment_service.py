"""Payments service (M4 Step 2: initiation flow)."""

from __future__ import annotations

import hashlib
import hmac
import json
import re
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal
from typing import Any
from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload

from app.core.config import Settings, get_settings
from app.core.constants import (
    DEFAULT_CURRENCY,
    PAYMENT_METHOD_BANK_TRANSFER,
    PAYMENT_METHOD_MOBILE_MONEY,
    PAYMENT_PROVIDER_PAYSTACK,
    PAYMENT_STATUS_FAILED,
    PAYMENT_STATUS_PENDING_PROVIDER,
    PAYMENT_STATUS_SUCCEEDED,
    PAYSTACK_MODE_LIVE,
    PAYSTACK_MODE_TEST,
    PROVIDER_PAYMENT_FAILED,
    PROVIDER_PAYMENT_PENDING,
    PROVIDER_PAYMENT_SUCCEEDED,
    RECEIVABLE_STATUS_CANCELLED,
    RECEIVABLE_STATUS_PARTIALLY_PAID,
    RECEIVABLE_STATUS_SETTLED,
    SALE_STATUS_VOIDED,
)
from app.integrations.paystack.client import (
    PaystackClient,
    PaystackClientError,
    PaystackVerifyResult,
)
from app.models.customer import Customer
from app.models.merchant import Merchant
from app.models.payment import Payment
from app.models.payment_provider_connection import PaymentProviderConnection
from app.models.payment_webhook_event import PaymentWebhookEvent
from app.models.receivable import Receivable, ReceivablePayment
from app.models.sale import Sale
from app.models.store import Store
from app.services.audit_service import log_audit
from app.services.payment_settings_service import get_decrypted_secret_for_mode
from app.services.store_context import StoreContextError, get_merchant_and_store

_MONEY_SCALE = Decimal("0.01")
_TERMINAL_RECEIVABLE_STATUSES = {RECEIVABLE_STATUS_SETTLED, RECEIVABLE_STATUS_CANCELLED}

# Receivable payment links expire after this window. Pending Payment rows past
# the TTL are auto-expired when the merchant tries to initiate a new payment
# (or when the sheet calls verify), and the receivable's cached payment_link /
# payment_provider_reference are reset so a fresh Paystack reference can be
# minted. Authoritative on the server; clients render the countdown from
# `payment_link_expires_at` only.
RECEIVABLE_PAYMENT_LINK_TTL = timedelta(hours=24)


def _paystack_display_text_from_raw(raw: dict[str, Any]) -> str | None:
    data = raw.get("data")
    if not isinstance(data, dict):
        return None
    dt = data.get("display_text")
    if isinstance(dt, str) and dt.strip():
        return dt.strip()
    return None


def _payment_is_momo_number_charge(payment: Payment) -> bool:
    """True when this payment was started via our MoMo-on-number `/charge` flow."""
    raw = payment.raw_provider_payload
    if not isinstance(raw, dict):
        return False
    data = raw.get("data")
    if not isinstance(data, dict):
        return False
    meta = data.get("metadata")
    if not isinstance(meta, dict):
        return False
    return meta.get("payment_flow") == "momo_number_charge"


class PaymentInitiationContextError(Exception):
    """Caller has no merchant/store context."""


class PaymentInitiationTargetNotFoundError(Exception):
    """Requested payment target does not exist in caller scope."""


class PaymentInitiationStateError(Exception):
    """Receivable target exists but is not payable."""


class PaystackConnectionMissingError(Exception):
    """Merchant has no active Paystack connection."""


class PaystackSecretKeyMissingError(Exception):
    """Server-side Paystack secret key is not configured for selected mode."""


class PaymentGatewayError(Exception):
    """Downstream payment provider rejected the initiation request."""


class PaystackWebhookSignatureError(Exception):
    """Webhook signature failed validation."""


class PaystackWebhookPayloadError(Exception):
    """Webhook payload is malformed."""


@dataclass(slots=True)
class PaymentInitiationSnapshot:
    payment_id: UUID
    provider: str
    provider_reference: str
    checkout_url: str
    access_code: str | None
    amount: Decimal
    currency: str
    status: str
    receivable_id: UUID


@dataclass(slots=True)
class SalePaymentInitiationSnapshot:
    payment_id: UUID
    provider: str
    provider_reference: str
    checkout_url: str
    access_code: str | None
    amount: Decimal
    currency: str
    status: str
    sale_id: UUID


@dataclass(slots=True)
class SaleMomoChargeSnapshot:
    payment_id: UUID
    provider: str
    provider_reference: str
    amount: Decimal
    currency: str
    status: str
    sale_id: UUID
    display_text: str | None = None
    needs_otp: bool = False


@dataclass(slots=True)
class PaymentVerifySnapshot:
    payment_id: UUID
    sale_id: UUID
    provider_payment_status: str
    sale_payment_status: str
    paystack_transaction_status: str
    display_text: str | None = None
    needs_otp: bool = False


@dataclass(slots=True)
class ReceivableMomoChargeSnapshot:
    payment_id: UUID
    provider: str
    provider_reference: str
    amount: Decimal
    currency: str
    status: str
    receivable_id: UUID
    display_text: str | None = None
    needs_otp: bool = False


@dataclass(slots=True)
class ReceivablePaymentVerifySnapshot:
    payment_id: UUID
    receivable_id: UUID
    provider_payment_status: str
    receivable_status: str
    outstanding_amount: Decimal
    paystack_transaction_status: str
    display_text: str | None = None
    needs_otp: bool = False


@dataclass(slots=True)
class PaymentWebhookSnapshot:
    status: str
    payment_id: UUID | None = None
    provider_reference: str | None = None


@dataclass(slots=True)
class PaymentService:
    db: Session
    paystack_client: PaystackClient | None = None
    settings: Settings | None = None

    def initiate_receivable_payment(
        self,
        *,
        user_id: UUID,
        receivable_id: UUID,
        amount: Decimal | None = None,
    ) -> PaymentInitiationSnapshot:
        try:
            merchant, store = get_merchant_and_store(user_id=user_id, db=self.db)
        except StoreContextError as exc:
            raise PaymentInitiationContextError(str(exc)) from exc

        receivable = self.db.scalar(
            select(Receivable)
            .options(selectinload(Receivable.customer))
            .where(
                Receivable.id == receivable_id,
                Receivable.store_id == store.id,
            )
        )
        if receivable is None:
            msg = "Receivable not found."
            raise PaymentInitiationTargetNotFoundError(msg)

        self._validate_receivable_state(receivable=receivable)
        self._ensure_no_pending_receivable_payment(receivable=receivable)

        connection = self._load_connected_paystack_connection(merchant_id=merchant.id)

        configured = self.settings or get_settings()
        secret_key = self._resolve_secret_key_for_connection(
            connection=connection,
            merchant_id=merchant.id,
            settings=configured,
        )
        reference = self._build_reference(merchant_id=merchant.id, receivable_id=receivable.id)
        outstanding = self._money(receivable.outstanding_amount)
        if amount is not None:
            charge_amount = self._money(amount)
            if charge_amount <= Decimal("0.00") or charge_amount > outstanding:
                msg = f"Amount must be between 0.01 and {outstanding}."
                raise PaymentInitiationStateError(msg)
        else:
            charge_amount = outstanding
        amount = charge_amount
        result = self._client(configured).initialize_transaction(
            secret_key=secret_key,
            email=_customer_email(receivable.customer),
            amount_kobo=int((amount * 100).to_integral_value(rounding=ROUND_HALF_UP)),
            reference=reference,
            currency=merchant.currency_code or DEFAULT_CURRENCY,
            metadata={
                "receivable_id": str(receivable.id),
                "customer_id": str(receivable.customer_id),
                "merchant_id": str(merchant.id),
                "invoice_number": receivable.invoice_number,
            },
        )

        payment = Payment(
            merchant_id=merchant.id,
            receivable_id=receivable.id,
            provider=PAYMENT_PROVIDER_PAYSTACK,
            provider_reference=result.reference,
            internal_reference=reference,
            provider_mode=connection.mode,
            amount=amount,
            currency=merchant.currency_code or DEFAULT_CURRENCY,
            status=PROVIDER_PAYMENT_PENDING,
            initiated_at=datetime.now(tz=UTC),
            raw_provider_payload=result.raw_payload,
        )
        self.db.add(payment)

        receivable.payment_link = result.authorization_url
        receivable.payment_provider_reference = result.reference
        self.db.add(receivable)
        self.db.flush()

        log_audit(
            db=self.db,
            actor_user_id=user_id,
            business_id=merchant.id,
            action="payment.initiated",
            entity_type="payment",
            entity_id=payment.id,
            meta={
                "provider": payment.provider,
                "provider_reference": payment.provider_reference,
                "receivable_id": str(receivable.id),
                "amount": str(payment.amount),
                "currency": payment.currency,
            },
        )

        self.db.commit()
        self.db.refresh(payment)
        self.db.refresh(receivable)
        return PaymentInitiationSnapshot(
            payment_id=payment.id,
            provider=payment.provider,
            provider_reference=payment.provider_reference or result.reference,
            checkout_url=result.authorization_url,
            access_code=result.access_code,
            amount=payment.amount,
            currency=payment.currency,
            status=payment.status,
            receivable_id=receivable.id,
        )

    def initiate_sale_payment(
        self,
        *,
        user_id: UUID,
        sale_id: UUID,
    ) -> SalePaymentInitiationSnapshot:
        try:
            merchant, store = get_merchant_and_store(user_id=user_id, db=self.db)
        except StoreContextError as exc:
            raise PaymentInitiationContextError(str(exc)) from exc

        sale = self.db.scalar(
            select(Sale)
            .where(Sale.id == sale_id, Sale.store_id == store.id)
            .options(selectinload(Sale.customer))
        )
        if sale is None:
            msg = "Sale not found."
            raise PaymentInitiationTargetNotFoundError(msg)
        self._validate_sale_state(sale=sale)

        connection = self._load_connected_paystack_connection(merchant_id=merchant.id)

        configured = self.settings or get_settings()
        secret_key = self._resolve_secret_key_for_connection(
            connection=connection,
            merchant_id=merchant.id,
            settings=configured,
        )
        reference = self._build_sale_reference(merchant_id=merchant.id, sale_id=sale.id)
        amount = self._money(sale.total_amount)
        result = self._client(configured).initialize_transaction(
            secret_key=secret_key,
            email=_sale_contact_email(sale=sale),
            amount_kobo=int((amount * 100).to_integral_value(rounding=ROUND_HALF_UP)),
            reference=reference,
            currency=merchant.currency_code or DEFAULT_CURRENCY,
            metadata={
                "sale_id": str(sale.id),
                "merchant_id": str(merchant.id),
                "store_id": str(store.id),
                "cashier_id": str(sale.cashier_id) if sale.cashier_id is not None else None,
                "payment_method_label": sale.payment_method_label,
            },
        )

        payment = Payment(
            merchant_id=merchant.id,
            sale_id=sale.id,
            provider=PAYMENT_PROVIDER_PAYSTACK,
            provider_reference=result.reference,
            internal_reference=reference,
            provider_mode=connection.mode,
            amount=amount,
            currency=merchant.currency_code or DEFAULT_CURRENCY,
            status=PROVIDER_PAYMENT_PENDING,
            initiated_at=datetime.now(tz=UTC),
            raw_provider_payload=result.raw_payload,
        )
        self.db.add(payment)
        sale.payment_status = PAYMENT_STATUS_PENDING_PROVIDER
        self.db.add(sale)
        self.db.flush()

        log_audit(
            db=self.db,
            actor_user_id=user_id,
            business_id=merchant.id,
            action="payment.initiated",
            entity_type="payment",
            entity_id=payment.id,
            meta={
                "provider": payment.provider,
                "provider_reference": payment.provider_reference,
                "sale_id": str(sale.id),
                "amount": str(payment.amount),
                "currency": payment.currency,
            },
        )

        self.db.commit()
        self.db.refresh(payment)
        self.db.refresh(sale)
        return SalePaymentInitiationSnapshot(
            payment_id=payment.id,
            provider=payment.provider,
            provider_reference=payment.provider_reference or result.reference,
            checkout_url=result.authorization_url,
            access_code=result.access_code,
            amount=payment.amount,
            currency=payment.currency,
            status=payment.status,
            sale_id=sale.id,
        )

    def initiate_sale_momo_charge(
        self,
        *,
        user_id: UUID,
        sale_id: UUID,
        phone: str,
        provider: str,
    ) -> SaleMomoChargeSnapshot:
        """Push a Paystack mobile-money charge to the customer's handset (no smartphone needed)."""
        try:
            merchant, store = get_merchant_and_store(user_id=user_id, db=self.db)
        except StoreContextError as exc:
            raise PaymentInitiationContextError(str(exc)) from exc

        sale = self.db.scalar(
            select(Sale)
            .where(Sale.id == sale_id, Sale.store_id == store.id)
            .options(selectinload(Sale.customer))
        )
        if sale is None:
            msg = "Sale not found."
            raise PaymentInitiationTargetNotFoundError(msg)
        self._validate_sale_state(sale=sale)

        connection = self._load_connected_paystack_connection(merchant_id=merchant.id)

        configured = self.settings or get_settings()
        secret_key = self._resolve_secret_key_for_connection(
            connection=connection,
            merchant_id=merchant.id,
            settings=configured,
        )
        reference = self._build_sale_reference(merchant_id=merchant.id, sale_id=sale.id)
        amount = self._money(sale.total_amount)
        normalized_phone = _normalize_ghana_momo_phone(phone)
        paystack_provider = _paystack_gh_momo_provider_code(provider)

        result = self._client(configured).charge_mobile_money(
            secret_key=secret_key,
            email=_sale_contact_email(sale=sale),
            amount_kobo=int((amount * 100).to_integral_value(rounding=ROUND_HALF_UP)),
            reference=reference,
            currency=merchant.currency_code or DEFAULT_CURRENCY,
            phone=normalized_phone,
            provider=paystack_provider,
            metadata={
                "sale_id": str(sale.id),
                "merchant_id": str(merchant.id),
                "store_id": str(store.id),
                "cashier_id": str(sale.cashier_id) if sale.cashier_id is not None else None,
                "payment_method_label": PAYMENT_METHOD_MOBILE_MONEY,
                "payment_flow": "momo_number_charge",
                "momo_provider": provider,
            },
        )

        if isinstance(result.raw_payload, dict):
            raw_for_store: dict[str, Any] = {**result.raw_payload}
            inner = raw_for_store.get("data")
            if isinstance(inner, dict):
                inner_copy = {**inner}
                meta = inner_copy.get("metadata")
                if not isinstance(meta, dict):
                    meta = {}
                else:
                    meta = {**meta}
                meta.setdefault("payment_flow", "momo_number_charge")
                inner_copy["metadata"] = meta
                raw_for_store["data"] = inner_copy
        else:
            raw_for_store = result.raw_payload

        payment = Payment(
            merchant_id=merchant.id,
            sale_id=sale.id,
            provider=PAYMENT_PROVIDER_PAYSTACK,
            provider_reference=result.reference,
            internal_reference=reference,
            provider_mode=connection.mode,
            amount=amount,
            currency=merchant.currency_code or DEFAULT_CURRENCY,
            status=PROVIDER_PAYMENT_PENDING,
            initiated_at=datetime.now(tz=UTC),
            raw_provider_payload=raw_for_store,
        )
        self.db.add(payment)
        sale.payment_status = PAYMENT_STATUS_PENDING_PROVIDER
        self.db.add(sale)
        self.db.flush()

        log_audit(
            db=self.db,
            actor_user_id=user_id,
            business_id=merchant.id,
            action="payment.momo_charge_initiated",
            entity_type="payment",
            entity_id=payment.id,
            meta={
                "provider": payment.provider,
                "provider_reference": payment.provider_reference,
                "sale_id": str(sale.id),
                "amount": str(payment.amount),
                "currency": payment.currency,
                "momo_provider": provider,
            },
        )

        paystack_charge_status = result.status.strip().lower()
        needs_otp = paystack_charge_status == "send_otp"

        if paystack_charge_status == "success":
            verified = self._client(configured).verify_transaction(
                secret_key=secret_key,
                reference=str(payment.provider_reference).strip(),
            )
            self._apply_paystack_verify_to_sale_payment(
                user_id=user_id,
                merchant=merchant,
                payment=payment,
                sale=sale,
                verified=verified,
            )

        self.db.commit()
        self.db.refresh(payment)
        self.db.refresh(sale)
        return SaleMomoChargeSnapshot(
            payment_id=payment.id,
            provider=payment.provider,
            provider_reference=payment.provider_reference or result.reference,
            amount=payment.amount,
            currency=payment.currency,
            status=payment.status,
            sale_id=sale.id,
            display_text=result.display_text,
            needs_otp=needs_otp,
        )

    def _apply_paystack_verify_to_sale_payment(
        self,
        *,
        user_id: UUID,
        merchant: Merchant,
        payment: Payment,
        sale: Sale,
        verified: PaystackVerifyResult,
    ) -> str:
        """Apply Paystack transaction verify result to sale payment; flush only, no commit."""
        verified_amount = self._kobo_to_money(verified.amount_kobo)
        expected_amount = self._money(sale.total_amount)
        paystack_status = verified.status.strip().lower()

        if paystack_status == "success":
            if verified_amount is not None and verified_amount >= expected_amount:
                payment.status = PROVIDER_PAYMENT_SUCCEEDED
                payment.confirmed_at = _parse_iso_datetime(verified.paid_at) or datetime.now(
                    tz=UTC
                )
                sale.payment_status = PAYMENT_STATUS_SUCCEEDED
                action = "payment.succeeded"
            else:
                payment.status = PROVIDER_PAYMENT_FAILED
                sale.payment_status = PAYMENT_STATUS_FAILED
                action = "payment.failed"
        elif paystack_status in {"failed", "abandoned", "reversed"}:
            payment.status = PROVIDER_PAYMENT_FAILED
            sale.payment_status = PAYMENT_STATUS_FAILED
            action = "payment.failed"
        else:
            action = "payment.verify_pending"

        prev_payload: dict[str, Any] = (
            payment.raw_provider_payload
            if isinstance(payment.raw_provider_payload, dict)
            else {}
        )
        payment.raw_provider_payload = {**prev_payload, "manual_verify": verified.raw_payload}
        self.db.add(payment)
        self.db.add(sale)
        self.db.flush()

        if action != "payment.verify_pending":
            log_audit(
                db=self.db,
                actor_user_id=user_id,
                business_id=merchant.id,
                action=action,
                entity_type="payment",
                entity_id=payment.id,
                meta={
                    "provider_reference": payment.provider_reference,
                    "sale_id": str(sale.id),
                    "paystack_status": paystack_status,
                    "verified_amount": str(verified_amount)
                    if verified_amount is not None
                    else None,
                    "expected_amount": str(expected_amount),
                },
            )

        return paystack_status

    def submit_sale_momo_otp(
        self,
        *,
        user_id: UUID,
        payment_id: UUID,
        otp: str,
    ) -> PaymentVerifySnapshot:
        """Submit OTP/voucher after Paystack returns ``send_otp`` on the MoMo charge."""
        try:
            merchant, store = get_merchant_and_store(user_id=user_id, db=self.db)
        except StoreContextError as exc:
            raise PaymentInitiationContextError(str(exc)) from exc

        payment = self.db.scalar(
            select(Payment)
            .join(Sale, Sale.id == Payment.sale_id)
            .where(
                Payment.id == payment_id,
                Sale.store_id == store.id,
                Payment.sale_id.isnot(None),
            )
        )
        if payment is None:
            msg = "Payment not found."
            raise PaymentInitiationTargetNotFoundError(msg)

        sale = self.db.scalar(select(Sale).where(Sale.id == payment.sale_id))
        if sale is None:
            msg = "Sale not found."
            raise PaymentInitiationTargetNotFoundError(msg)

        if payment.provider_reference is None or not str(payment.provider_reference).strip():
            msg = "Payment has no provider reference."
            raise PaymentInitiationStateError(msg)

        if (
            payment.status == PROVIDER_PAYMENT_SUCCEEDED
            and sale.payment_status == PAYMENT_STATUS_SUCCEEDED
        ):
            return PaymentVerifySnapshot(
                payment_id=payment.id,
                sale_id=sale.id,
                provider_payment_status=payment.status,
                sale_payment_status=sale.payment_status,
                paystack_transaction_status="success",
                display_text=None,
                needs_otp=False,
            )

        if (
            payment.status == PROVIDER_PAYMENT_FAILED
            or sale.payment_status == PAYMENT_STATUS_FAILED
        ):
            msg = "Payment is no longer pending."
            raise PaymentInitiationStateError(msg)

        configured = self.settings or get_settings()
        secret_key = self._resolve_secret_key_for_payment(
            payment=payment,
            settings=configured,
        )
        charge_out = self._client(configured).submit_charge_otp(
            secret_key=secret_key,
            reference=str(payment.provider_reference).strip(),
            otp=otp,
        )

        new_ref = str(charge_out.reference).strip()
        if new_ref:
            payment.provider_reference = new_ref

        prev_payload: dict[str, Any] = (
            payment.raw_provider_payload
            if isinstance(payment.raw_provider_payload, dict)
            else {}
        )
        payment.raw_provider_payload = {**prev_payload, "submit_otp_charge": charge_out.raw_payload}
        self.db.add(payment)
        self.db.add(sale)
        self.db.flush()

        charge_status = charge_out.status.strip().lower()
        paystack_status: str
        response_display = charge_out.display_text or _paystack_display_text_from_raw(
            charge_out.raw_payload
        )
        response_needs_otp = charge_status == "send_otp"

        if charge_status == "success":
            verified = self._client(configured).verify_transaction(
                secret_key=secret_key,
                reference=str(payment.provider_reference).strip(),
            )
            paystack_status = self._apply_paystack_verify_to_sale_payment(
                user_id=user_id,
                merchant=merchant,
                payment=payment,
                sale=sale,
                verified=verified,
            )
            response_needs_otp = paystack_status == "send_otp"
            response_display = response_display or _paystack_display_text_from_raw(
                verified.raw_payload
            )
        elif charge_status in {"failed", "abandoned", "reversed"}:
            payment.status = PROVIDER_PAYMENT_FAILED
            sale.payment_status = PAYMENT_STATUS_FAILED
            self.db.add(payment)
            self.db.add(sale)
            self.db.flush()
            log_audit(
                db=self.db,
                actor_user_id=user_id,
                business_id=merchant.id,
                action="payment.failed",
                entity_type="payment",
                entity_id=payment.id,
                meta={
                    "provider_reference": payment.provider_reference,
                    "sale_id": str(sale.id),
                    "paystack_status": charge_status,
                    "source": "submit_otp",
                },
            )
            paystack_status = charge_status
            response_needs_otp = False
        else:
            paystack_status = charge_status

        self.db.commit()
        self.db.refresh(payment)
        self.db.refresh(sale)
        return PaymentVerifySnapshot(
            payment_id=payment.id,
            sale_id=sale.id,
            provider_payment_status=payment.status,
            sale_payment_status=sale.payment_status,
            paystack_transaction_status=paystack_status,
            display_text=response_display,
            needs_otp=response_needs_otp,
        )

    def verify_sale_payment(
        self,
        *,
        user_id: UUID,
        payment_id: UUID,
    ) -> PaymentVerifySnapshot:
        """Re-query Paystack for a sale-linked payment (MoMo prompt / webhook delay)."""
        try:
            merchant, store = get_merchant_and_store(user_id=user_id, db=self.db)
        except StoreContextError as exc:
            raise PaymentInitiationContextError(str(exc)) from exc

        payment = self.db.scalar(
            select(Payment)
            .join(Sale, Sale.id == Payment.sale_id)
            .where(
                Payment.id == payment_id,
                Sale.store_id == store.id,
                Payment.sale_id.isnot(None),
            )
        )
        if payment is None:
            msg = "Payment not found."
            raise PaymentInitiationTargetNotFoundError(msg)

        sale = self.db.scalar(select(Sale).where(Sale.id == payment.sale_id))
        if sale is None:
            msg = "Sale not found."
            raise PaymentInitiationTargetNotFoundError(msg)

        if payment.provider_reference is None or not str(payment.provider_reference).strip():
            msg = "Payment has no provider reference."
            raise PaymentInitiationStateError(msg)

        if (
            payment.status == PROVIDER_PAYMENT_SUCCEEDED
            and sale.payment_status == PAYMENT_STATUS_SUCCEEDED
        ):
            return PaymentVerifySnapshot(
                payment_id=payment.id,
                sale_id=sale.id,
                provider_payment_status=payment.status,
                sale_payment_status=sale.payment_status,
                paystack_transaction_status="success",
                display_text=None,
                needs_otp=False,
            )

        configured = self.settings or get_settings()
        secret_key = self._resolve_secret_key_for_payment(
            payment=payment,
            settings=configured,
        )
        ref = str(payment.provider_reference).strip()
        verified: PaystackVerifyResult
        if _payment_is_momo_number_charge(payment):
            try:
                verified = self._client(configured).get_charge_transaction(
                    secret_key=secret_key,
                    reference=ref,
                )
            except PaystackClientError:
                verified = self._client(configured).verify_transaction(
                    secret_key=secret_key,
                    reference=ref,
                )
        else:
            verified = self._client(configured).verify_transaction(
                secret_key=secret_key,
                reference=ref,
            )
        paystack_status = self._apply_paystack_verify_to_sale_payment(
            user_id=user_id,
            merchant=merchant,
            payment=payment,
            sale=sale,
            verified=verified,
        )

        self.db.commit()
        self.db.refresh(payment)
        self.db.refresh(sale)
        return PaymentVerifySnapshot(
            payment_id=payment.id,
            sale_id=sale.id,
            provider_payment_status=payment.status,
            sale_payment_status=sale.payment_status,
            paystack_transaction_status=paystack_status,
            display_text=_paystack_display_text_from_raw(verified.raw_payload),
            needs_otp=paystack_status == "send_otp",
        )

    def initiate_receivable_momo_charge(
        self,
        *,
        user_id: UUID,
        receivable_id: UUID,
        phone: str,
        provider: str,
        amount: Decimal | None = None,
    ) -> ReceivableMomoChargeSnapshot:
        """Push a Paystack MoMo charge to the debtor's handset for a receivable."""
        try:
            merchant, store = get_merchant_and_store(user_id=user_id, db=self.db)
        except StoreContextError as exc:
            raise PaymentInitiationContextError(str(exc)) from exc

        receivable = self.db.scalar(
            select(Receivable)
            .options(selectinload(Receivable.customer))
            .where(
                Receivable.id == receivable_id,
                Receivable.store_id == store.id,
            )
        )
        if receivable is None:
            msg = "Receivable not found."
            raise PaymentInitiationTargetNotFoundError(msg)
        self._validate_receivable_state(receivable=receivable)
        self._ensure_no_pending_receivable_payment(receivable=receivable)

        connection = self._load_connected_paystack_connection(merchant_id=merchant.id)

        configured = self.settings or get_settings()
        secret_key = self._resolve_secret_key_for_connection(
            connection=connection,
            merchant_id=merchant.id,
            settings=configured,
        )
        reference = self._build_reference(
            merchant_id=merchant.id, receivable_id=receivable.id
        )
        outstanding = self._money(receivable.outstanding_amount)
        if amount is not None:
            charge_amount = self._money(amount)
            if charge_amount <= Decimal("0.00") or charge_amount > outstanding:
                msg = f"Amount must be between 0.01 and {outstanding}."
                raise PaymentInitiationStateError(msg)
        else:
            charge_amount = outstanding
        amount = charge_amount
        normalized_phone = _normalize_ghana_momo_phone(phone)
        paystack_provider = _paystack_gh_momo_provider_code(provider)

        result = self._client(configured).charge_mobile_money(
            secret_key=secret_key,
            email=_customer_email(receivable.customer),
            amount_kobo=int((amount * 100).to_integral_value(rounding=ROUND_HALF_UP)),
            reference=reference,
            currency=merchant.currency_code or DEFAULT_CURRENCY,
            phone=normalized_phone,
            provider=paystack_provider,
            metadata={
                "receivable_id": str(receivable.id),
                "customer_id": str(receivable.customer_id),
                "merchant_id": str(merchant.id),
                "store_id": str(store.id),
                "invoice_number": receivable.invoice_number,
                "payment_method_label": PAYMENT_METHOD_MOBILE_MONEY,
                "payment_flow": "momo_number_charge",
                "momo_provider": provider,
            },
        )

        if isinstance(result.raw_payload, dict):
            raw_for_store: dict[str, Any] = {**result.raw_payload}
            inner = raw_for_store.get("data")
            if isinstance(inner, dict):
                inner_copy = {**inner}
                meta = inner_copy.get("metadata")
                if not isinstance(meta, dict):
                    meta = {}
                else:
                    meta = {**meta}
                meta.setdefault("payment_flow", "momo_number_charge")
                inner_copy["metadata"] = meta
                raw_for_store["data"] = inner_copy
        else:
            raw_for_store = result.raw_payload

        payment = Payment(
            merchant_id=merchant.id,
            receivable_id=receivable.id,
            provider=PAYMENT_PROVIDER_PAYSTACK,
            provider_reference=result.reference,
            internal_reference=reference,
            provider_mode=connection.mode,
            amount=amount,
            currency=merchant.currency_code or DEFAULT_CURRENCY,
            status=PROVIDER_PAYMENT_PENDING,
            initiated_at=datetime.now(tz=UTC),
            raw_provider_payload=raw_for_store,
        )
        self.db.add(payment)
        receivable.payment_provider_reference = result.reference
        self.db.add(receivable)
        self.db.flush()

        log_audit(
            db=self.db,
            actor_user_id=user_id,
            business_id=merchant.id,
            action="payment.momo_charge_initiated",
            entity_type="payment",
            entity_id=payment.id,
            meta={
                "provider": payment.provider,
                "provider_reference": payment.provider_reference,
                "receivable_id": str(receivable.id),
                "amount": str(payment.amount),
                "currency": payment.currency,
                "momo_provider": provider,
            },
        )

        paystack_charge_status = result.status.strip().lower()
        needs_otp = paystack_charge_status == "send_otp"

        if paystack_charge_status == "success":
            verified = self._client(configured).verify_transaction(
                secret_key=secret_key,
                reference=str(payment.provider_reference).strip(),
            )
            self._apply_paystack_verify_to_receivable_payment(
                user_id=user_id,
                merchant=merchant,
                payment=payment,
                receivable=receivable,
                verified=verified,
            )

        self.db.commit()
        self.db.refresh(payment)
        self.db.refresh(receivable)
        return ReceivableMomoChargeSnapshot(
            payment_id=payment.id,
            provider=payment.provider,
            provider_reference=payment.provider_reference or result.reference,
            amount=payment.amount,
            currency=payment.currency,
            status=payment.status,
            receivable_id=receivable.id,
            display_text=result.display_text,
            needs_otp=needs_otp,
        )

    def submit_receivable_momo_otp(
        self,
        *,
        user_id: UUID,
        payment_id: UUID,
        otp: str,
    ) -> ReceivablePaymentVerifySnapshot:
        """Submit OTP/voucher after Paystack returns ``send_otp`` on a receivable charge."""
        try:
            merchant, store = get_merchant_and_store(user_id=user_id, db=self.db)
        except StoreContextError as exc:
            raise PaymentInitiationContextError(str(exc)) from exc

        locked = self._load_receivable_payment_with_lock(
            store_id=store.id,
            payment_id=payment_id,
        )
        if locked is None:
            msg = "Payment not found."
            raise PaymentInitiationTargetNotFoundError(msg)
        payment, receivable = locked

        if payment.provider_reference is None or not str(payment.provider_reference).strip():
            msg = "Payment has no provider reference."
            raise PaymentInitiationStateError(msg)

        # Same idempotency rule as `verify_receivable_payment`: keying off
        # `receivable_payment_id` prevents a partial payment from being
        # double-debited if OTP submit is retried after a successful charge.
        if (
            payment.status == PROVIDER_PAYMENT_SUCCEEDED
            and payment.receivable_payment_id is not None
        ):
            return ReceivablePaymentVerifySnapshot(
                payment_id=payment.id,
                receivable_id=receivable.id,
                provider_payment_status=payment.status,
                receivable_status=receivable.status,
                outstanding_amount=self._money(receivable.outstanding_amount),
                paystack_transaction_status="success",
                display_text=None,
                needs_otp=False,
            )

        if payment.status == PROVIDER_PAYMENT_FAILED:
            msg = "Payment is no longer pending."
            raise PaymentInitiationStateError(msg)

        configured = self.settings or get_settings()
        secret_key = self._resolve_secret_key_for_payment(
            payment=payment,
            settings=configured,
        )
        charge_out = self._client(configured).submit_charge_otp(
            secret_key=secret_key,
            reference=str(payment.provider_reference).strip(),
            otp=otp,
        )

        new_ref = str(charge_out.reference).strip()
        if new_ref:
            payment.provider_reference = new_ref

        prev_payload: dict[str, Any] = (
            payment.raw_provider_payload
            if isinstance(payment.raw_provider_payload, dict)
            else {}
        )
        payment.raw_provider_payload = {**prev_payload, "submit_otp_charge": charge_out.raw_payload}
        self.db.add(payment)
        self.db.add(receivable)
        self.db.flush()

        charge_status = charge_out.status.strip().lower()
        paystack_status: str
        response_display = charge_out.display_text or _paystack_display_text_from_raw(
            charge_out.raw_payload
        )
        response_needs_otp = charge_status == "send_otp"

        if charge_status == "success":
            verified = self._client(configured).verify_transaction(
                secret_key=secret_key,
                reference=str(payment.provider_reference).strip(),
            )
            paystack_status = self._apply_paystack_verify_to_receivable_payment(
                user_id=user_id,
                merchant=merchant,
                payment=payment,
                receivable=receivable,
                verified=verified,
            )
            response_needs_otp = paystack_status == "send_otp"
            response_display = response_display or _paystack_display_text_from_raw(
                verified.raw_payload
            )
        elif charge_status in {"failed", "abandoned", "reversed"}:
            payment.status = PROVIDER_PAYMENT_FAILED
            self.db.add(payment)
            self.db.flush()
            log_audit(
                db=self.db,
                actor_user_id=user_id,
                business_id=merchant.id,
                action="payment.failed",
                entity_type="payment",
                entity_id=payment.id,
                meta={
                    "provider_reference": payment.provider_reference,
                    "receivable_id": str(receivable.id),
                    "paystack_status": charge_status,
                    "source": "submit_otp",
                },
            )
            paystack_status = charge_status
            response_needs_otp = False
        else:
            paystack_status = charge_status

        self.db.commit()
        self.db.refresh(payment)
        self.db.refresh(receivable)
        return ReceivablePaymentVerifySnapshot(
            payment_id=payment.id,
            receivable_id=receivable.id,
            provider_payment_status=payment.status,
            receivable_status=receivable.status,
            outstanding_amount=self._money(receivable.outstanding_amount),
            paystack_transaction_status=paystack_status,
            display_text=response_display,
            needs_otp=response_needs_otp,
        )

    def verify_receivable_payment(
        self,
        *,
        user_id: UUID,
        payment_id: UUID,
    ) -> ReceivablePaymentVerifySnapshot:
        """Re-query Paystack for a receivable-linked payment (MoMo prompt / webhook delay)."""
        try:
            merchant, store = get_merchant_and_store(user_id=user_id, db=self.db)
        except StoreContextError as exc:
            raise PaymentInitiationContextError(str(exc)) from exc

        locked = self._load_receivable_payment_with_lock(
            store_id=store.id,
            payment_id=payment_id,
        )
        if locked is None:
            msg = "Payment not found."
            raise PaymentInitiationTargetNotFoundError(msg)
        payment, receivable = locked

        if payment.provider_reference is None or not str(payment.provider_reference).strip():
            msg = "Payment has no provider reference."
            raise PaymentInitiationStateError(msg)

        # Settlement-already-applied short-circuit. This MUST key off
        # `payment.receivable_payment_id` (set by `_apply_receivable_settlement`),
        # not `receivable.status == settled`, because a *partial* payment leaves
        # the receivable in `partially_paid` while the payment row is already
        # `succeeded`. Without this guard, re-entering `_apply_paystack_verify_*`
        # would call `_apply_receivable_settlement` a second time and silently
        # reduce `outstanding_amount` again, flipping a real partial payment
        # to `settled` and corrupting the customer's balance.
        if (
            payment.status == PROVIDER_PAYMENT_SUCCEEDED
            and payment.receivable_payment_id is not None
        ):
            return ReceivablePaymentVerifySnapshot(
                payment_id=payment.id,
                receivable_id=receivable.id,
                provider_payment_status=payment.status,
                receivable_status=receivable.status,
                outstanding_amount=self._money(receivable.outstanding_amount),
                paystack_transaction_status="success",
                display_text=None,
                needs_otp=False,
            )

        # Short-circuit before hitting Paystack: a pending payment past the
        # link TTL is treated as expired so the mobile sheet can prompt the
        # merchant to regenerate without burning a network call.
        if self._is_payment_expired(payment):
            self._expire_pending_payment(payment=payment, receivable=receivable)
            self.db.commit()
            self.db.refresh(payment)
            self.db.refresh(receivable)
            return ReceivablePaymentVerifySnapshot(
                payment_id=payment.id,
                receivable_id=receivable.id,
                provider_payment_status=payment.status,
                receivable_status=receivable.status,
                outstanding_amount=self._money(receivable.outstanding_amount),
                paystack_transaction_status="expired",
                display_text=None,
                needs_otp=False,
            )

        configured = self.settings or get_settings()
        secret_key = self._resolve_secret_key_for_payment(
            payment=payment,
            settings=configured,
        )
        ref = str(payment.provider_reference).strip()
        verified: PaystackVerifyResult
        if _payment_is_momo_number_charge(payment):
            try:
                verified = self._client(configured).get_charge_transaction(
                    secret_key=secret_key,
                    reference=ref,
                )
            except PaystackClientError:
                verified = self._client(configured).verify_transaction(
                    secret_key=secret_key,
                    reference=ref,
                )
        else:
            verified = self._client(configured).verify_transaction(
                secret_key=secret_key,
                reference=ref,
            )
        paystack_status = self._apply_paystack_verify_to_receivable_payment(
            user_id=user_id,
            merchant=merchant,
            payment=payment,
            receivable=receivable,
            verified=verified,
        )

        self.db.commit()
        self.db.refresh(payment)
        self.db.refresh(receivable)
        return ReceivablePaymentVerifySnapshot(
            payment_id=payment.id,
            receivable_id=receivable.id,
            provider_payment_status=payment.status,
            receivable_status=receivable.status,
            outstanding_amount=self._money(receivable.outstanding_amount),
            paystack_transaction_status=paystack_status,
            display_text=_paystack_display_text_from_raw(verified.raw_payload),
            needs_otp=paystack_status == "send_otp",
        )

    @staticmethod
    def _verified_metadata_mismatch(
        *,
        verified: PaystackVerifyResult,
        receivable: Receivable,
    ) -> bool:
        """Return True when Paystack's `metadata.receivable_id` does not point
        at the locked receivable we are about to settle.

        Missing metadata is treated as a non-mismatch (legacy initiates may
        not have written it). Only an explicit, non-matching value is treated
        as a mismatch.
        """
        raw = verified.raw_payload
        if not isinstance(raw, dict):
            return False
        data = raw.get("data")
        if not isinstance(data, dict):
            return False
        metadata = data.get("metadata")
        if not isinstance(metadata, dict):
            return False
        raw_receivable_id = metadata.get("receivable_id")
        if raw_receivable_id is None:
            return False
        raw_str = str(raw_receivable_id).strip()
        if not raw_str:
            return False
        return raw_str != str(receivable.id)

    def _apply_paystack_verify_to_receivable_payment(
        self,
        *,
        user_id: UUID | None,
        merchant: Merchant,
        payment: Payment,
        receivable: Receivable,
        verified: PaystackVerifyResult,
        channel: str | None = None,
        extra_payload_key: str = "manual_verify",
        emit_audit: bool = True,
    ) -> str:
        """Apply Paystack verify result to a receivable-linked payment; flush only.

        Shared by manual verify, OTP submit, and webhook paths so the same
        idempotency, metadata-mismatch, cancelled-receivable, and settlement
        rules apply everywhere.

        - ``user_id`` is ``None`` for webhook-driven calls (no actor).
        - ``channel`` overrides the hard-coded mobile-money channel used when
          recording the [ReceivablePayment]; webhook supplies the real
          Paystack channel ("mobile_money", "bank", "card", ...).
        - ``extra_payload_key`` controls which key the verify payload is
          stored under inside ``payment.raw_provider_payload`` (so manual and
          webhook flows don't clobber each other).
        """
        verified_amount = self._kobo_to_money(verified.amount_kobo)
        paystack_status = verified.status.strip().lower()
        action = "payment.verify_pending"
        failure_reason: str | None = None
        effective_channel = channel or PAYMENT_METHOD_MOBILE_MONEY

        # Idempotency: settlement already applied (webhook or prior verify).
        # `receivable_payment_id` is set inside `_apply_receivable_settlement`,
        # so its presence proves we already debited `outstanding_amount` for
        # this payment. Re-running would subtract a second time and silently
        # flip a partial payment to fully `settled`. Defense in depth with the
        # outer short-circuit in `verify_receivable_payment`.
        if (
            payment.status == PROVIDER_PAYMENT_SUCCEEDED
            and payment.receivable_payment_id is not None
        ):
            return paystack_status or "success"

        # Defense-in-depth: if Paystack echoed back the receivable_id metadata
        # we wrote at initiate time, make sure it matches the row we are about
        # to settle. Catches misrouted webhooks or hand-crafted verify calls
        # that point at the wrong reference. Missing metadata is treated as
        # legacy/OK and falls through to the normal status flow.
        metadata_mismatch = self._verified_metadata_mismatch(
            verified=verified,
            receivable=receivable,
        )
        if metadata_mismatch and paystack_status == "success":
            payment.status = PROVIDER_PAYMENT_FAILED
            failure_reason = "metadata_mismatch"
            action = "payment.failed"
            paystack_status = "failed"
        elif paystack_status == "success":
            if verified_amount is not None and verified_amount > Decimal("0.00"):
                if verified_amount != payment.amount:
                    payment.amount = verified_amount
                applied = self._apply_receivable_settlement(
                    payment=payment,
                    receivable=receivable,
                    channel=effective_channel,
                )
                if applied:
                    payment.status = PROVIDER_PAYMENT_SUCCEEDED
                    payment.confirmed_at = _parse_iso_datetime(verified.paid_at) or datetime.now(
                        tz=UTC
                    )
                    action = "payment.succeeded"
                else:
                    # Settlement refused (e.g. receivable cancelled). Mark
                    # the payment failed so it stops appearing as a pending
                    # online attempt; audit was already emitted inside the
                    # settlement helper.
                    payment.status = PROVIDER_PAYMENT_FAILED
                    failure_reason = "receivable_cancelled"
                    action = "payment.failed"
                    paystack_status = "failed"
            else:
                payment.status = PROVIDER_PAYMENT_FAILED
                failure_reason = "invalid_verified_amount"
                action = "payment.failed"
        elif paystack_status in {"failed", "abandoned", "reversed"}:
            payment.status = PROVIDER_PAYMENT_FAILED
            action = "payment.failed"

        prev_payload: dict[str, Any] = (
            payment.raw_provider_payload
            if isinstance(payment.raw_provider_payload, dict)
            else {}
        )
        payment.raw_provider_payload = {**prev_payload, extra_payload_key: verified.raw_payload}
        self.db.add(payment)
        self.db.add(receivable)
        self.db.flush()

        if emit_audit and action != "payment.verify_pending":
            log_audit(
                db=self.db,
                actor_user_id=user_id,
                business_id=merchant.id,
                action=action,
                entity_type="payment",
                entity_id=payment.id,
                meta={
                    "provider_reference": payment.provider_reference,
                    "receivable_id": str(receivable.id),
                    "paystack_status": paystack_status,
                    "verified_amount": str(verified_amount)
                    if verified_amount is not None
                    else None,
                    "outstanding_amount": str(receivable.outstanding_amount),
                    "failure_reason": failure_reason,
                },
            )

        return paystack_status

    def handle_paystack_webhook(
        self,
        *,
        raw_body: bytes,
        signature: str | None,
    ) -> PaymentWebhookSnapshot:
        configured = self.settings or get_settings()
        payload = self._parse_webhook_payload(raw_body=raw_body)
        event = str(payload.get("event") or "").strip().lower()
        data = payload.get("data")
        if not isinstance(data, dict):
            raise PaystackWebhookPayloadError("Webhook payload missing event data.")
        provider_reference = data.get("reference")
        provider_reference = (
            provider_reference.strip()
            if isinstance(provider_reference, str) and provider_reference.strip()
            else None
        )

        payment = self._load_payment_by_reference(
            provider_reference=provider_reference,
            for_update=True,
        )
        secrets = self._resolve_webhook_signature_secrets(
            payment=payment,
            provider_reference=provider_reference,
            settings=configured,
        )
        self._verify_paystack_signature(
            raw_body=raw_body,
            signature=signature,
            secrets=secrets,
        )

        event_key = self._build_webhook_event_key(
            event=event,
            data=data,
            raw_body=raw_body,
        )

        existing_event = self.db.scalar(
            select(PaymentWebhookEvent).where(
                PaymentWebhookEvent.provider == PAYMENT_PROVIDER_PAYSTACK,
                PaymentWebhookEvent.event_key == event_key,
            )
        )
        if existing_event is not None:
            return PaymentWebhookSnapshot(
                status="duplicate",
                payment_id=existing_event.payment_id,
                provider_reference=existing_event.provider_reference,
            )

        webhook_event = PaymentWebhookEvent(
            provider=PAYMENT_PROVIDER_PAYSTACK,
            event_key=event_key,
            provider_reference=provider_reference,
            payload=payload,
            result_status="received",
        )
        self.db.add(webhook_event)
        try:
            self.db.flush()
        except IntegrityError:
            self.db.rollback()
            return PaymentWebhookSnapshot(
                status="duplicate",
                provider_reference=provider_reference,
            )

        if provider_reference is None:
            webhook_event.result_status = "ignored"
            webhook_event.processed_at = datetime.now(tz=UTC)
            self.db.add(webhook_event)
            self.db.commit()
            return PaymentWebhookSnapshot(status="ignored")

        if payment is None:
            webhook_event.result_status = "ignored"
            webhook_event.processed_at = datetime.now(tz=UTC)
            self.db.add(webhook_event)
            self.db.commit()
            return PaymentWebhookSnapshot(status="ignored", provider_reference=provider_reference)

        sale = None
        receivable = None
        target_type = "sale" if payment.sale_id is not None else "receivable"

        if target_type == "sale":
            sale = self.db.scalar(select(Sale).where(Sale.id == payment.sale_id))
            if sale is None:
                webhook_event.payment_id = payment.id
                webhook_event.result_status = "ignored"
                webhook_event.processed_at = datetime.now(tz=UTC)
                self.db.add(webhook_event)
                self.db.commit()
                return PaymentWebhookSnapshot(
                    status="ignored",
                    payment_id=payment.id,
                    provider_reference=provider_reference,
                )
            if (
                payment.status == PROVIDER_PAYMENT_SUCCEEDED
                and sale.payment_status == PAYMENT_STATUS_SUCCEEDED
            ):
                webhook_event.payment_id = payment.id
                webhook_event.result_status = "duplicate"
                webhook_event.processed_at = datetime.now(tz=UTC)
                self.db.add(webhook_event)
                self.db.commit()
                return PaymentWebhookSnapshot(
                    status="duplicate",
                    payment_id=payment.id,
                    provider_reference=provider_reference,
                )
        else:
            receivable = self._load_receivable_for_payment(
                payment=payment,
                provider_reference=provider_reference,
                for_update=True,
            )
            if receivable is None:
                webhook_event.payment_id = payment.id
                webhook_event.result_status = "ignored"
                webhook_event.processed_at = datetime.now(tz=UTC)
                self.db.add(webhook_event)
                self.db.commit()
                return PaymentWebhookSnapshot(
                    status="ignored",
                    payment_id=payment.id,
                    provider_reference=provider_reference,
                )
            if (
                payment.status == PROVIDER_PAYMENT_SUCCEEDED
                and payment.receivable_payment_id is not None
            ):
                webhook_event.payment_id = payment.id
                webhook_event.result_status = "duplicate"
                webhook_event.processed_at = datetime.now(tz=UTC)
                self.db.add(webhook_event)
                self.db.commit()
                return PaymentWebhookSnapshot(
                    status="duplicate",
                    payment_id=payment.id,
                    provider_reference=provider_reference,
                )
        secret_key = self._resolve_secret_key_for_payment(
            payment=payment,
            settings=configured,
        )
        verified = self._client(configured).verify_transaction(
            secret_key=secret_key,
            reference=provider_reference,
        )

        previous_status = payment.status
        verified_amount = self._kobo_to_money(verified.amount_kobo)
        if verified_amount is not None and sale is not None:
            # Receivable case lets the verify helper own the amount update
            # so it stays consistent with the manual verify path. For sales
            # we keep the legacy behaviour (mutate here, no helper call).
            payment.amount = verified_amount
        failure_reason: str | None = None
        expected_amount: Decimal | None = None
        channel = _paystack_channel_label(data.get("channel"))
        if verified.status == "success":
            if sale is not None:
                expected_amount = self._money(sale.total_amount)
                if verified_amount is not None and verified_amount >= expected_amount:
                    payment.status = PROVIDER_PAYMENT_SUCCEEDED
                    payment.confirmed_at = _parse_iso_datetime(verified.paid_at) or datetime.now(
                        tz=UTC
                    )
                    sale.payment_status = PAYMENT_STATUS_SUCCEEDED
                    action = "payment.succeeded"
                else:
                    payment.status = PROVIDER_PAYMENT_FAILED
                    sale.payment_status = PAYMENT_STATUS_FAILED
                    failure_reason = (
                        "underpaid_sale"
                        if verified_amount is not None and verified_amount > Decimal("0.00")
                        else "invalid_verified_amount"
                    )
                    action = "payment.failed"
            else:
                # Receivable path: delegate to the same helper used by the
                # manual verify endpoint so idempotency, metadata-mismatch,
                # cancelled-guard, and link-clearing rules apply identically.
                merchant = self.db.scalar(
                    select(Merchant).where(Merchant.id == payment.merchant_id)
                )
                if merchant is None:
                    payment.status = PROVIDER_PAYMENT_FAILED
                    failure_reason = "merchant_not_found"
                    action = "payment.failed"
                else:
                    paystack_status = self._apply_paystack_verify_to_receivable_payment(
                        user_id=None,
                        merchant=merchant,
                        payment=payment,
                        receivable=receivable,
                        verified=verified,
                        channel=channel,
                        extra_payload_key="verify",
                        emit_audit=False,
                    )
                    if payment.status == PROVIDER_PAYMENT_SUCCEEDED:
                        action = "payment.succeeded"
                    elif paystack_status == "failed":
                        action = "payment.failed"
                        if failure_reason is None:
                            failure_reason = "settlement_refused"
                    else:
                        action = "payment.verify_pending"
        else:
            payment.status = PROVIDER_PAYMENT_FAILED
            if sale is not None:
                sale.payment_status = PAYMENT_STATUS_FAILED
            action = "payment.failed"

        # Preserve any keys the helper may have added (e.g. "verify") so we
        # don't lose them when stamping the webhook payload.
        existing_payload: dict[str, Any] = (
            payment.raw_provider_payload
            if isinstance(payment.raw_provider_payload, dict)
            else {}
        )
        payment.raw_provider_payload = {
            **existing_payload,
            "webhook": payload,
            "verify": verified.raw_payload,
        }
        webhook_event.payment_id = payment.id
        webhook_event.result_status = "processed"
        webhook_event.processed_at = datetime.now(tz=UTC)
        self.db.add(payment)
        if sale is not None:
            self.db.add(sale)
        if receivable is not None:
            self.db.add(receivable)
        self.db.add(webhook_event)
        self.db.flush()

        business_id = (
            self._business_id_for_sale(sale_id=sale.id)
            if sale is not None
            else self._business_id_for_receivable(receivable_id=receivable.id)
        )
        log_audit(
            db=self.db,
            actor_user_id=None,
            business_id=business_id,
            action=action,
            entity_type="payment",
            entity_id=payment.id,
            meta={
                "provider_reference": provider_reference,
                "event": event,
                "previous_status": previous_status,
                "current_status": payment.status,
                "sale_id": str(sale.id) if sale is not None else None,
                "receivable_id": str(receivable.id) if receivable is not None else None,
                "verified_amount": str(verified_amount) if verified_amount is not None else None,
                "expected_amount": str(expected_amount) if expected_amount is not None else None,
                "failure_reason": failure_reason,
            },
        )
        self.db.commit()
        return PaymentWebhookSnapshot(
            status="processed",
            payment_id=payment.id,
            provider_reference=provider_reference,
        )

    def _client(self, settings: Settings) -> PaystackClient:
        if self.paystack_client is not None:
            return self.paystack_client
        return PaystackClient(
            base_url=settings.paystack_api_base_url,
            timeout_seconds=settings.paystack_http_timeout_seconds,
        )

    @staticmethod
    def _validate_receivable_state(*, receivable: Receivable) -> None:
        if receivable.status in _TERMINAL_RECEIVABLE_STATUSES:
            msg = f"Cannot initiate payment for a {receivable.status} debt."
            raise PaymentInitiationStateError(msg)
        if receivable.outstanding_amount <= Decimal("0.00"):
            msg = "Outstanding amount must be greater than 0."
            raise PaymentInitiationStateError(msg)

    @staticmethod
    def _validate_sale_state(*, sale: Sale) -> None:
        if sale.sale_status == SALE_STATUS_VOIDED:
            msg = "Cannot initiate payment for a voided sale."
            raise PaymentInitiationStateError(msg)
        if sale.payment_status in {PAYMENT_STATUS_PENDING_PROVIDER, PAYMENT_STATUS_SUCCEEDED}:
            msg = f"Cannot initiate payment for sale with status {sale.payment_status}."
            raise PaymentInitiationStateError(msg)
        if sale.total_amount <= Decimal("0.00"):
            msg = "Sale amount must be greater than 0."
            raise PaymentInitiationStateError(msg)

    def _load_connected_paystack_connection(
        self,
        *,
        merchant_id: UUID,
    ) -> PaymentProviderConnection:
        connection = self._get_paystack_connection(merchant_id=merchant_id)
        if connection is None or not connection.is_connected:
            msg = "Paystack is not connected for this merchant."
            raise PaystackConnectionMissingError(msg)
        return connection

    def _get_paystack_connection(self, *, merchant_id: UUID) -> PaymentProviderConnection | None:
        return self.db.scalar(
            select(PaymentProviderConnection).where(
                PaymentProviderConnection.merchant_id == merchant_id,
                PaymentProviderConnection.provider == PAYMENT_PROVIDER_PAYSTACK,
            )
        )

    def _resolve_secret_key_for_connection(
        self,
        *,
        connection: PaymentProviderConnection,
        merchant_id: UUID,
        settings: Settings,
    ) -> str:
        secret_key = get_decrypted_secret_for_mode(
            row=connection,
            mode=connection.mode,
            settings=settings,
        )
        if secret_key is not None:
            return secret_key
        return self._resolve_env_fallback_secret(
            mode=connection.mode,
            settings=settings,
            merchant_id=merchant_id,
        )

    def _resolve_secret_key_for_payment(
        self,
        *,
        payment: Payment,
        settings: Settings,
    ) -> str:
        mode = (payment.provider_mode or PAYSTACK_MODE_TEST).strip().lower()
        merchant_id = payment.merchant_id or self._merchant_id_for_payment(payment=payment)
        if merchant_id is None:
            if settings.app_env == "production":
                raise PaystackSecretKeyMissingError(
                    "Merchant-specific Paystack secret is missing for webhook verification."
                )
            return self._resolve_env_fallback_secret(
                mode=mode,
                settings=settings,
                merchant_id=None,
            )
        connection = self._get_paystack_connection(merchant_id=merchant_id)
        if connection is None:
            return self._resolve_env_fallback_secret(
                mode=mode,
                settings=settings,
                merchant_id=merchant_id,
            )
        secret_key = get_decrypted_secret_for_mode(
            row=connection,
            mode=mode,
            settings=settings,
        )
        if secret_key is not None:
            return secret_key
        return self._resolve_env_fallback_secret(
            mode=mode,
            settings=settings,
            merchant_id=merchant_id,
        )

    @staticmethod
    def _env_secret_for_mode(*, mode: str, settings: Settings) -> str | None:
        secret_key = (
            settings.paystack_secret_key_live
            if mode.strip().lower() == PAYSTACK_MODE_LIVE
            else settings.paystack_secret_key_test
        )
        return secret_key.strip() if isinstance(secret_key, str) and secret_key.strip() else None

    def _resolve_env_fallback_secret(
        self,
        *,
        mode: str,
        settings: Settings,
        merchant_id: UUID | None,
    ) -> str:
        if settings.app_env == "production":
            msg = (
                "Merchant-specific Paystack secret is missing for mode "
                f"{mode.strip().lower()}."
            )
            raise PaystackSecretKeyMissingError(msg)
        secret_key = self._env_secret_for_mode(mode=mode, settings=settings)
        if secret_key is None:
            if merchant_id is not None:
                msg = (
                    "Merchant-specific Paystack secret is missing for mode "
                    f"{mode.strip().lower()}."
                )
            else:
                msg = "Paystack secret key is missing for non-production fallback."
            raise PaystackSecretKeyMissingError(msg)
        return secret_key

    @staticmethod
    def _build_reference(*, merchant_id: UUID, receivable_id: UUID) -> str:
        # Format: BTGH_{32-char merchant hex}_{suffix}
        # The merchant_id prefix lets webhook verification resolve the signing key
        # even before the payment record is committed (race-condition safety).
        return f"BTGH_{merchant_id.hex}_{uuid4().hex[:12]}"

    @staticmethod
    def _build_sale_reference(*, merchant_id: UUID, sale_id: UUID) -> str:
        return f"BTGH_{merchant_id.hex}_{uuid4().hex[:12]}"

    @staticmethod
    def _extract_merchant_id_from_reference(reference: str) -> UUID | None:
        """Parse merchant_id from a BTGH_ reference; returns None for old-format refs."""
        if not reference.startswith("BTGH_"):
            return None
        merchant_hex = reference[5:37]  # chars 5-36 are the 32-hex merchant UUID
        if len(merchant_hex) < 32:
            return None
        try:
            return UUID(hex=merchant_hex)
        except ValueError:
            return None

    @staticmethod
    def _money(value: Decimal) -> Decimal:
        return value.quantize(_MONEY_SCALE, rounding=ROUND_HALF_UP)

    def _kobo_to_money(self, amount_kobo: int | None) -> Decimal | None:
        if amount_kobo is None:
            return None
        return self._money(Decimal(amount_kobo) / Decimal("100"))

    @staticmethod
    def _build_webhook_event_key(
        *,
        event: str,
        data: dict[str, Any],
        raw_body: bytes,
    ) -> str:
        normalized_event = event or "unknown"
        data_id = data.get("id")
        if isinstance(data_id, (int, str)) and str(data_id).strip():
            return f"{normalized_event}:{str(data_id).strip()}"[:255]

        reference = data.get("reference")
        status = data.get("status")
        if isinstance(reference, str) and reference.strip():
            status_part = status.strip().lower() if isinstance(status, str) else ""
            return f"{normalized_event}:{reference.strip()}:{status_part}"[:255]

        body_hash = hashlib.sha256(raw_body).hexdigest()
        return f"{normalized_event}:hash:{body_hash}"[:255]

    def _business_id_for_receivable(self, *, receivable_id: UUID) -> UUID | None:
        return self.db.scalar(
            select(Store.merchant_id)
            .select_from(Receivable)
            .join(Store, Store.id == Receivable.store_id)
            .where(Receivable.id == receivable_id)
        )

    def _business_id_for_sale(self, *, sale_id: UUID) -> UUID | None:
        return self.db.scalar(
            select(Store.merchant_id)
            .select_from(Sale)
            .join(Store, Store.id == Sale.store_id)
            .where(Sale.id == sale_id)
        )

    def _apply_receivable_settlement(
        self,
        *,
        payment: Payment,
        receivable: Receivable,
        channel: str,
    ) -> bool:
        """Apply a successful Paystack payment to a receivable.

        Returns ``True`` when settlement was applied (outstanding mutated or
        the receivable was already at zero). Returns ``False`` when the
        caller must treat the payment as failed instead — currently only
        the case for receivables already marked cancelled, where applying
        Paystack money would silently un-cancel the debt.
        """
        # Trust boundary: a cancelled receivable must never be revived by a
        # late Paystack callback. The caller should mark the payment failed
        # with an appropriate reason. Audit is emitted here for visibility
        # since the verify/webhook callers don't know the receivable was
        # cancelled until they see this return value.
        if receivable.status == RECEIVABLE_STATUS_CANCELLED:
            business_id = self._business_id_for_receivable(receivable_id=receivable.id)
            log_audit(
                db=self.db,
                actor_user_id=None,
                business_id=business_id,
                action="payment.ignored_cancelled_receivable",
                entity_type="payment",
                entity_id=payment.id,
                meta={
                    "provider_reference": payment.provider_reference,
                    "receivable_id": str(receivable.id),
                },
            )
            return False

        outstanding = self._money(receivable.outstanding_amount)
        if outstanding <= Decimal("0.00"):
            receivable.status = RECEIVABLE_STATUS_SETTLED
            self._clear_cached_link_if_matches(payment=payment, receivable=receivable)
            return True
        settlement_amount = self._money(min(outstanding, payment.amount))
        if payment.receivable_payment_id is None and settlement_amount > Decimal("0.00"):
            receivable_payment = ReceivablePayment(
                receivable_id=receivable.id,
                amount=settlement_amount,
                payment_method_label=channel,
            )
            self.db.add(receivable_payment)
            self.db.flush()
            payment.receivable_payment_id = receivable_payment.id

        next_outstanding = self._money(outstanding - settlement_amount)
        receivable.outstanding_amount = next_outstanding
        receivable.status = (
            RECEIVABLE_STATUS_SETTLED
            if next_outstanding == Decimal("0.00")
            else RECEIVABLE_STATUS_PARTIALLY_PAID
        )
        # Either a partial or full payment invalidates the cached online
        # context: full settlement closes the debt, partial settlement
        # means the next payment must be a fresh link for the new
        # remaining balance.
        self._clear_cached_link_if_matches(payment=payment, receivable=receivable)
        return True

    @staticmethod
    def _clear_cached_link_if_matches(
        *,
        payment: Payment,
        receivable: Receivable,
    ) -> None:
        """Drop the receivable's cached Paystack link when it belongs to this payment.

        We only clear when the cached reference matches the payment being
        settled — otherwise we might wipe a newer pending attempt the
        merchant just generated for the remaining balance.
        """
        ref = receivable.payment_provider_reference
        if ref is None:
            return
        if str(ref).strip() != str(payment.provider_reference or "").strip():
            return
        receivable.payment_link = None
        receivable.payment_provider_reference = None

    def _ensure_no_pending_receivable_payment(
        self,
        *,
        receivable: Receivable,
    ) -> None:
        """Block initiate if a non-expired pending payment exists for this debt.

        Pending payments older than [RECEIVABLE_PAYMENT_LINK_TTL] are silently
        auto-expired (marked `failed`, audit logged) and the receivable's
        cached `payment_link` / `payment_provider_reference` are cleared so the
        caller can mint a fresh Paystack reference.
        """
        pending = self.db.scalar(
            select(Payment)
            .where(
                Payment.receivable_id == receivable.id,
                Payment.status == PROVIDER_PAYMENT_PENDING,
            )
            .order_by(Payment.initiated_at.desc())
            .limit(1)
        )
        if pending is None:
            return
        if self._is_payment_expired(pending):
            self._expire_pending_payment(payment=pending, receivable=receivable)
            return
        msg = (
            "A payment is already pending for this debt. "
            f"Use the existing payment ({pending.id}) or verify it."
        )
        raise PaymentInitiationStateError(msg)

    @staticmethod
    def _is_payment_expired(payment: Payment) -> bool:
        if payment.status != PROVIDER_PAYMENT_PENDING:
            return False
        initiated = payment.initiated_at
        if initiated.tzinfo is None:
            initiated = initiated.replace(tzinfo=UTC)
        return datetime.now(tz=UTC) - initiated >= RECEIVABLE_PAYMENT_LINK_TTL

    def _expire_pending_payment(
        self,
        *,
        payment: Payment,
        receivable: Receivable | None,
    ) -> None:
        """Mark a stale pending Payment as failed and clear the cached link."""
        now = datetime.now(tz=UTC)
        prev_payload: dict[str, Any] = (
            payment.raw_provider_payload
            if isinstance(payment.raw_provider_payload, dict)
            else {}
        )
        payment.status = PROVIDER_PAYMENT_FAILED
        payment.raw_provider_payload = {
            **prev_payload,
            "expired_at": now.isoformat(),
            "failure_reason": "payment_link_ttl_exceeded",
        }
        self.db.add(payment)

        if receivable is not None:
            ref = receivable.payment_provider_reference
            if ref is not None and ref == payment.provider_reference:
                receivable.payment_link = None
                receivable.payment_provider_reference = None
                self.db.add(receivable)

        self.db.flush()

        business_id: UUID | None = None
        if receivable is not None:
            business_id = self._business_id_for_receivable(receivable_id=receivable.id)
        log_audit(
            db=self.db,
            actor_user_id=None,
            business_id=business_id,
            action="payment.expired",
            entity_type="payment",
            entity_id=payment.id,
            meta={
                "provider_reference": payment.provider_reference,
                "receivable_id": str(receivable.id) if receivable is not None else None,
                "ttl_hours": int(RECEIVABLE_PAYMENT_LINK_TTL.total_seconds() // 3600),
            },
        )

    def _load_receivable_payment_with_lock(
        self,
        *,
        store_id: UUID,
        payment_id: UUID,
    ) -> tuple[Payment, Receivable] | None:
        payment = self.db.scalar(
            select(Payment)
            .join(Receivable, Receivable.id == Payment.receivable_id)
            .where(
                Payment.id == payment_id,
                Receivable.store_id == store_id,
                Payment.receivable_id.isnot(None),
            )
            .with_for_update()
        )
        if payment is None or payment.receivable_id is None:
            return None
        # Receivable.store is lazy="joined" (stores -> merchants -> users), so a
        # plain FOR UPDATE on the full join fails on PostgreSQL; see
        # sales_service._load_balances (with_for_update(of=...)) for the same pattern.
        receivable = self.db.scalar(
            select(Receivable)
            .options(selectinload(Receivable.customer))
            .where(Receivable.id == payment.receivable_id)
            .with_for_update(of=Receivable)
        )
        if receivable is None:
            return None
        return payment, receivable

    def _resolve_webhook_signature_secrets(
        self,
        *,
        payment: Payment | None,
        provider_reference: str | None,
        settings: Settings,
    ) -> list[str]:
        # Fast path: payment record already links us to the merchant.
        if payment is not None:
            return [self._resolve_secret_key_for_payment(payment=payment, settings=settings)]

        # Reference-based path: extract merchant_id from the BTGH_ reference prefix.
        # This works even when the payment isn't persisted yet (timing edge case) or for
        # webhook events fired by Paystack before we committed the payment row.
        if provider_reference is not None:
            merchant_id = self._extract_merchant_id_from_reference(provider_reference)
            if merchant_id is not None:
                connection = self._get_paystack_connection(merchant_id=merchant_id)
                if connection is not None:
                    secret_key = get_decrypted_secret_for_mode(
                        row=connection,
                        mode=connection.mode,
                        settings=settings,
                    )
                    if secret_key is not None:
                        return [secret_key]

        # Non-production fallback to env keys (lets dev test without merchant credentials).
        if settings.app_env != "production":
            fallback = [
                secret
                for secret in (
                    self._env_secret_for_mode(mode=PAYSTACK_MODE_TEST, settings=settings),
                    self._env_secret_for_mode(mode=PAYSTACK_MODE_LIVE, settings=settings),
                )
                if secret is not None
            ]
            if fallback:
                return fallback

        detail = (
            "Cannot resolve merchant secret for Paystack webhook verification."
            if provider_reference is None
            else f"Cannot resolve merchant secret for reference {provider_reference}."
        )
        raise PaystackWebhookSignatureError(detail)

    def _merchant_id_for_payment(self, *, payment: Payment) -> UUID | None:
        if payment.sale_id is not None:
            return self.db.scalar(
                select(Store.merchant_id)
                .select_from(Sale)
                .join(Store, Store.id == Sale.store_id)
                .where(Sale.id == payment.sale_id)
            )
        if payment.receivable_id is not None:
            return self.db.scalar(
                select(Store.merchant_id)
                .select_from(Receivable)
                .join(Store, Store.id == Receivable.store_id)
                .where(Receivable.id == payment.receivable_id)
            )
        if payment.provider_reference is not None:
            return self.db.scalar(
                select(Store.merchant_id)
                .select_from(Receivable)
                .join(Store, Store.id == Receivable.store_id)
                .where(Receivable.payment_provider_reference == payment.provider_reference)
            )
        return None

    def _load_receivable_for_payment(
        self,
        *,
        payment: Payment,
        provider_reference: str,
        for_update: bool = False,
    ) -> Receivable | None:
        if payment.receivable_id is not None:
            stmt = (
                select(Receivable)
                .options(selectinload(Receivable.customer))
                .where(Receivable.id == payment.receivable_id)
            )
            if for_update:
                stmt = stmt.with_for_update(of=Receivable)
            receivable = self.db.scalar(stmt)
            if receivable is not None:
                return receivable
        stmt = (
            select(Receivable)
            .options(selectinload(Receivable.customer))
            .where(Receivable.payment_provider_reference == provider_reference)
        )
        if for_update:
            stmt = stmt.with_for_update(of=Receivable)
        return self.db.scalar(stmt)

    def _load_payment_by_reference(
        self,
        *,
        provider_reference: str | None,
        for_update: bool = False,
    ) -> Payment | None:
        if provider_reference is None:
            return None
        stmt = select(Payment).where(
            Payment.provider == PAYMENT_PROVIDER_PAYSTACK,
            Payment.provider_reference == provider_reference,
        )
        if for_update:
            stmt = stmt.with_for_update()
        return self.db.scalar(stmt)

    @staticmethod
    def _parse_webhook_payload(*, raw_body: bytes) -> dict[str, Any]:
        try:
            payload = json.loads(raw_body.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise PaystackWebhookPayloadError("Invalid Paystack webhook payload.") from exc
        if not isinstance(payload, dict):
            raise PaystackWebhookPayloadError("Invalid Paystack webhook payload.")
        return payload

    @staticmethod
    def _verify_paystack_signature(
        *,
        raw_body: bytes,
        signature: str | None,
        secrets: list[str],
    ) -> None:
        normalized = (signature or "").strip().lower()
        if not normalized:
            raise PaystackWebhookSignatureError("Missing Paystack signature.")
        if not secrets:
            raise PaystackWebhookSignatureError("No Paystack secret key configured.")
        for secret in secrets:
            digest = hmac.new(
                secret.encode("utf-8"),
                raw_body,
                hashlib.sha512,
            ).hexdigest()
            if hmac.compare_digest(digest, normalized):
                return
        raise PaystackWebhookSignatureError("Invalid Paystack signature.")


def _customer_email(customer: Customer) -> str:
    if customer.email is not None:
        candidate = customer.email.strip()
        if candidate and "@" in candidate:
            return candidate
    phone = customer.phone_number or ""
    digits = re.sub(r"\D", "", phone)
    if digits:
        return f"{digits}@pay.biztrackgh.com"
    return f"customer-{customer.id.hex[:12]}@pay.biztrackgh.com"


def _sale_contact_email(*, sale: Sale) -> str:
    if sale.customer is not None:
        return _customer_email(sale.customer)
    return f"sale-{sale.id.hex[:12]}@pay.biztrackgh.com"


_PAYSTACK_CHANNEL_MAP: dict[str, str] = {
    "mobile_money": PAYMENT_METHOD_MOBILE_MONEY,
    "bank_transfer": PAYMENT_METHOD_BANK_TRANSFER,
    "bank": PAYMENT_METHOD_BANK_TRANSFER,
}


def _paystack_channel_label(channel: str | None) -> str:
    """Map a Paystack channel string to our internal payment_method_label constant."""
    if channel and isinstance(channel, str):
        normalized = channel.strip().lower()
        if normalized in _PAYSTACK_CHANNEL_MAP:
            return _PAYSTACK_CHANNEL_MAP[normalized]
    return PAYMENT_METHOD_MOBILE_MONEY


def _parse_iso_datetime(value: str | None) -> datetime | None:
    if value is None:
        return None
    candidate = value.strip()
    if not candidate:
        return None
    if candidate.endswith("Z"):
        candidate = f"{candidate[:-1]}+00:00"
    try:
        parsed = datetime.fromisoformat(candidate)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def _normalize_ghana_momo_phone(phone: str) -> str:
    """Digits-only local 0XXXXXXXXX for Paystack Ghana mobile money."""
    digits = re.sub(r"\D", "", phone.strip())
    if digits.startswith("233") and len(digits) >= 12:
        local = digits[3:]
        if local.startswith("0"):
            return local[:10]
        return f"0{local[:9]}"
    if digits.startswith("0") and len(digits) >= 10:
        return digits[:10]
    if len(digits) >= 9 and not digits.startswith("0"):
        return f"0{digits[-9:]}"
    return digits


def _paystack_gh_momo_provider_code(provider: str) -> str:
    """Map API provider codes to Paystack's Ghana mobile_money.provider values."""
    key = provider.strip().lower()
    mapping = {
        "mtn": "mtn",
        "vod": "vod",
        "atl": "tgo",
    }
    if key not in mapping:
        msg = f"Unsupported MoMo provider: {provider!r}."
        raise PaymentInitiationStateError(msg)
    return mapping[key]


__all__ = [
    "PaymentGatewayError",
    "PaymentInitiationContextError",
    "PaymentInitiationSnapshot",
    "PaymentInitiationStateError",
    "PaymentInitiationTargetNotFoundError",
    "PaymentService",
    "PaymentVerifySnapshot",
    "ReceivableMomoChargeSnapshot",
    "ReceivablePaymentVerifySnapshot",
    "SaleMomoChargeSnapshot",
    "SalePaymentInitiationSnapshot",
    "PaymentWebhookSnapshot",
    "PaystackClientError",
    "PaystackWebhookPayloadError",
    "PaystackWebhookSignatureError",
    "PaystackConnectionMissingError",
    "PaystackSecretKeyMissingError",
]
