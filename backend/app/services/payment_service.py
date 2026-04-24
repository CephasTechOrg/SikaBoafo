"""Payments service (M4 Step 2: initiation flow)."""

from __future__ import annotations

import hashlib
import hmac
import json
import re
from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import ROUND_HALF_UP, Decimal
from typing import Any
from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload

from app.core.config import Settings, get_settings
from app.core.constants import (
    DEFAULT_CURRENCY,
    PAYMENT_METHOD_MOBILE_MONEY,
    PAYMENT_STATUS_FAILED,
    PAYMENT_STATUS_PENDING_PROVIDER,
    PAYMENT_STATUS_SUCCEEDED,
    PAYMENT_PROVIDER_PAYSTACK,
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
)
from app.models.customer import Customer
from app.models.payment import Payment
from app.models.payment_provider_connection import PaymentProviderConnection
from app.models.payment_webhook_event import PaymentWebhookEvent
from app.models.receivable import Receivable, ReceivablePayment
from app.models.sale import Sale
from app.models.store import Store
from app.services.audit_service import log_audit
from app.services.store_context import StoreContextError, get_merchant_and_store

_MONEY_SCALE = Decimal("0.01")
_TERMINAL_RECEIVABLE_STATUSES = {RECEIVABLE_STATUS_SETTLED, RECEIVABLE_STATUS_CANCELLED}


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

        connection = self._load_connected_paystack_connection(merchant_id=merchant.id)

        configured = self.settings or get_settings()
        secret_key = self._resolve_secret_key(mode=connection.mode, settings=configured)
        reference = self._build_reference(receivable_id=receivable.id)
        amount = self._money(receivable.outstanding_amount)
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
            provider=PAYMENT_PROVIDER_PAYSTACK,
            provider_reference=result.reference,
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
            select(Sale).where(
                Sale.id == sale_id,
                Sale.store_id == store.id,
            )
        )
        if sale is None:
            msg = "Sale not found."
            raise PaymentInitiationTargetNotFoundError(msg)
        self._validate_sale_state(sale=sale)

        connection = self._load_connected_paystack_connection(merchant_id=merchant.id)

        configured = self.settings or get_settings()
        secret_key = self._resolve_secret_key(mode=connection.mode, settings=configured)
        reference = self._build_sale_reference(sale_id=sale.id)
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
            sale_id=sale.id,
            provider=PAYMENT_PROVIDER_PAYSTACK,
            provider_reference=result.reference,
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

    def handle_paystack_webhook(
        self,
        *,
        raw_body: bytes,
        signature: str | None,
    ) -> PaymentWebhookSnapshot:
        configured = self.settings or get_settings()
        payload = self._parse_webhook_payload(raw_body=raw_body)
        self._verify_paystack_signature(
            raw_body=raw_body,
            signature=signature,
            settings=configured,
        )

        event = str(payload.get("event") or "").strip().lower()
        data = payload.get("data")
        if not isinstance(data, dict):
            raise PaystackWebhookPayloadError("Webhook payload missing event data.")

        event_key = self._build_webhook_event_key(
            event=event,
            data=data,
            raw_body=raw_body,
        )
        provider_reference = data.get("reference")
        provider_reference = (
            provider_reference.strip()
            if isinstance(provider_reference, str) and provider_reference.strip()
            else None
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

        payment = self.db.scalar(
            select(Payment).where(
                Payment.provider == PAYMENT_PROVIDER_PAYSTACK,
                Payment.provider_reference == provider_reference,
            )
        )
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
            mode = self._resolve_mode_for_sale(sale_id=sale.id)
        else:
            receivable = self.db.scalar(
                select(Receivable)
                .options(selectinload(Receivable.customer))
                .where(Receivable.payment_provider_reference == provider_reference)
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
            mode = self._resolve_mode_for_receivable(receivable_id=receivable.id)

        secret_key = self._resolve_secret_key(mode=mode, settings=configured)
        verified = self._client(configured).verify_transaction(
            secret_key=secret_key,
            reference=provider_reference,
        )

        previous_status = payment.status
        if verified.status == "success":
            payment.status = PROVIDER_PAYMENT_SUCCEEDED
            payment.confirmed_at = _parse_iso_datetime(verified.paid_at) or datetime.now(
                tz=UTC
            )
            if sale is not None:
                sale.payment_status = PAYMENT_STATUS_SUCCEEDED
            else:
                self._apply_receivable_settlement(
                    payment=payment,
                    receivable=receivable,
                )
            action = "payment.succeeded"
        else:
            payment.status = PROVIDER_PAYMENT_FAILED
            if sale is not None:
                sale.payment_status = PAYMENT_STATUS_FAILED
            action = "payment.failed"

        payment.raw_provider_payload = {
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
        connection = self.db.scalar(
            select(PaymentProviderConnection).where(
                PaymentProviderConnection.merchant_id == merchant_id,
                PaymentProviderConnection.provider == PAYMENT_PROVIDER_PAYSTACK,
            )
        )
        if connection is None or not connection.is_connected:
            msg = "Paystack is not connected for this merchant."
            raise PaystackConnectionMissingError(msg)
        return connection

    @staticmethod
    def _resolve_secret_key(*, mode: str, settings: Settings) -> str:
        normalized_mode = mode.strip().lower()
        secret_key = (
            settings.paystack_secret_key_live
            if normalized_mode == PAYSTACK_MODE_LIVE
            else settings.paystack_secret_key_test
        )
        if secret_key is None or not secret_key.strip():
            mode_name = (
                PAYSTACK_MODE_LIVE
                if normalized_mode == PAYSTACK_MODE_LIVE
                else PAYSTACK_MODE_TEST
            )
            msg = (
                "Paystack secret key is missing for mode "
                f"{mode_name}."
            )
            raise PaystackSecretKeyMissingError(msg)
        return secret_key.strip()

    @staticmethod
    def _build_reference(*, receivable_id: UUID) -> str:
        return f"btx_{receivable_id.hex}_{uuid4().hex[:10]}"

    @staticmethod
    def _build_sale_reference(*, sale_id: UUID) -> str:
        return f"btx_sale_{sale_id.hex}_{uuid4().hex[:10]}"

    @staticmethod
    def _money(value: Decimal) -> Decimal:
        return value.quantize(_MONEY_SCALE, rounding=ROUND_HALF_UP)

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

    def _resolve_mode_for_receivable(self, *, receivable_id: UUID) -> str:
        merchant_id = self.db.scalar(
            select(Store.merchant_id)
            .select_from(Receivable)
            .join(Store, Store.id == Receivable.store_id)
            .where(Receivable.id == receivable_id)
        )
        if merchant_id is None:
            return PAYSTACK_MODE_TEST
        connection = self.db.scalar(
            select(PaymentProviderConnection).where(
                PaymentProviderConnection.merchant_id == merchant_id,
                PaymentProviderConnection.provider == PAYMENT_PROVIDER_PAYSTACK,
            )
        )
        if connection is None:
            return PAYSTACK_MODE_TEST
        return connection.mode

    def _resolve_mode_for_sale(self, *, sale_id: UUID) -> str:
        merchant_id = self.db.scalar(
            select(Store.merchant_id)
            .select_from(Sale)
            .join(Store, Store.id == Sale.store_id)
            .where(Sale.id == sale_id)
        )
        if merchant_id is None:
            return PAYSTACK_MODE_TEST
        connection = self.db.scalar(
            select(PaymentProviderConnection).where(
                PaymentProviderConnection.merchant_id == merchant_id,
                PaymentProviderConnection.provider == PAYMENT_PROVIDER_PAYSTACK,
            )
        )
        if connection is None:
            return PAYSTACK_MODE_TEST
        return connection.mode

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

    def _apply_receivable_settlement(self, *, payment: Payment, receivable: Receivable) -> None:
        outstanding = self._money(receivable.outstanding_amount)
        if outstanding <= Decimal("0.00"):
            receivable.status = RECEIVABLE_STATUS_SETTLED
            return
        settlement_amount = self._money(min(outstanding, payment.amount))
        if payment.receivable_payment_id is None and settlement_amount > Decimal("0.00"):
            receivable_payment = ReceivablePayment(
                receivable_id=receivable.id,
                amount=settlement_amount,
                payment_method_label=PAYMENT_METHOD_MOBILE_MONEY,
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
        settings: Settings,
    ) -> None:
        normalized = (signature or "").strip().lower()
        if not normalized:
            raise PaystackWebhookSignatureError("Missing Paystack signature.")
        secrets = [
            v.strip()
            for v in (
                settings.paystack_secret_key_test,
                settings.paystack_secret_key_live,
            )
            if isinstance(v, str) and v.strip()
        ]
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
        return f"{digits}@biztrackgh.local"
    return f"customer-{customer.id.hex[:12]}@biztrackgh.local"


def _sale_contact_email(*, sale: Sale) -> str:
    if sale.customer is not None:
        return _customer_email(sale.customer)
    return f"sale-{sale.id.hex[:12]}@biztrackgh.local"


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


__all__ = [
    "PaymentGatewayError",
    "PaymentInitiationContextError",
    "PaymentInitiationSnapshot",
    "PaymentInitiationStateError",
    "PaymentInitiationTargetNotFoundError",
    "PaymentService",
    "SalePaymentInitiationSnapshot",
    "PaymentWebhookSnapshot",
    "PaystackClientError",
    "PaystackWebhookPayloadError",
    "PaystackWebhookSignatureError",
    "PaystackConnectionMissingError",
    "PaystackSecretKeyMissingError",
]
