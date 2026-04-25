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
    PAYMENT_METHOD_BANK_TRANSFER,
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
from app.services.payment_settings_service import get_decrypted_secret_for_mode
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
        secret_key = self._resolve_secret_key_for_connection(
            connection=connection,
            merchant_id=merchant.id,
            settings=configured,
        )
        reference = self._build_reference(merchant_id=merchant.id, receivable_id=receivable.id)
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

        payment = self._load_payment_by_reference(provider_reference=provider_reference)
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
        if verified_amount is not None:
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
                if verified_amount is not None and verified_amount > Decimal("0.00"):
                    payment.status = PROVIDER_PAYMENT_SUCCEEDED
                    payment.confirmed_at = _parse_iso_datetime(verified.paid_at) or datetime.now(
                        tz=UTC
                    )
                    self._apply_receivable_settlement(
                        payment=payment,
                        receivable=receivable,
                        channel=channel,
                    )
                    action = "payment.succeeded"
                else:
                    payment.status = PROVIDER_PAYMENT_FAILED
                    failure_reason = "invalid_verified_amount"
                    action = "payment.failed"
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
    ) -> None:
        outstanding = self._money(receivable.outstanding_amount)
        if outstanding <= Decimal("0.00"):
            receivable.status = RECEIVABLE_STATUS_SETTLED
            return
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
    ) -> Receivable | None:
        if payment.receivable_id is not None:
            receivable = self.db.scalar(
                select(Receivable)
                .options(selectinload(Receivable.customer))
                .where(Receivable.id == payment.receivable_id)
            )
            if receivable is not None:
                return receivable
        return self.db.scalar(
            select(Receivable)
            .options(selectinload(Receivable.customer))
            .where(Receivable.payment_provider_reference == provider_reference)
        )

    def _load_payment_by_reference(self, *, provider_reference: str | None) -> Payment | None:
        if provider_reference is None:
            return None
        return self.db.scalar(
            select(Payment).where(
                Payment.provider == PAYMENT_PROVIDER_PAYSTACK,
                Payment.provider_reference == provider_reference,
            )
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
