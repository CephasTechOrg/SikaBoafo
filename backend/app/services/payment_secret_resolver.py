"""Paystack secret / connection resolution for the payments service.

Extracted from ``payment_service.py`` (PAY-01) to keep the orchestration class
focused on payment *flows* rather than the credential-resolution plumbing. The
methods live in a mixin so they keep operating on the same ``PaymentService``
instance (``self.db`` / ``self.settings`` / ``self.paystack_client``) with no
behavioural change.

Resolution order for a Paystack secret key:
1. The merchant's stored, encrypted secret for the requested mode.
2. A non-production environment fallback (``PAYSTACK_SECRET_KEY_*``).
Production never falls back to env secrets — a missing merchant secret raises
``PaystackSecretKeyMissingError`` instead.
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Protocol
from uuid import UUID

from sqlalchemy import select

from app.core.config import Settings
from app.core.constants import (
    PAYMENT_PROVIDER_PAYSTACK,
    PAYSTACK_MODE_LIVE,
    PAYSTACK_MODE_TEST,
)
from app.integrations.paystack.client import PaystackClient
from app.models.payment import Payment
from app.models.payment_provider_connection import PaymentProviderConnection
from app.services.payment_errors import (
    PaystackConnectionMissingError,
    PaystackSecretKeyMissingError,
)
from app.services.payment_settings_service import get_decrypted_secret_for_mode

if TYPE_CHECKING:
    from sqlalchemy.orm import Session


class _SupportsMerchantLookup(Protocol):
    """Attributes/methods the mixin relies on from the host service."""

    db: Session
    paystack_client: PaystackClient | None
    settings: Settings | None

    def _merchant_id_for_payment(self, *, payment: Payment) -> UUID | None: ...


class PaymentSecretResolverMixin:
    """Paystack connection + secret resolution helpers.

    Mixed into ``PaymentService``; all methods operate on ``self`` and assume
    the host exposes ``db`` and a ``_merchant_id_for_payment`` lookup.
    """

    def _client(self: _SupportsMerchantLookup, settings: Settings) -> PaystackClient:
        if self.paystack_client is not None:
            return self.paystack_client
        return PaystackClient(
            base_url=settings.paystack_api_base_url,
            timeout_seconds=settings.paystack_http_timeout_seconds,
        )

    def _load_connected_paystack_connection(
        self: _SupportsMerchantLookup,
        *,
        merchant_id: UUID,
    ) -> PaymentProviderConnection:
        connection = self._get_paystack_connection(merchant_id=merchant_id)
        if connection is None or not connection.is_connected:
            msg = "Paystack is not connected for this merchant."
            raise PaystackConnectionMissingError(msg)
        return connection

    def _get_paystack_connection(
        self: _SupportsMerchantLookup, *, merchant_id: UUID
    ) -> PaymentProviderConnection | None:
        return self.db.scalar(
            select(PaymentProviderConnection).where(
                PaymentProviderConnection.merchant_id == merchant_id,
                PaymentProviderConnection.provider == PAYMENT_PROVIDER_PAYSTACK,
            )
        )

    def _resolve_secret_key_for_connection(
        self: _SupportsMerchantLookup,
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
        self: _SupportsMerchantLookup,
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
        self: _SupportsMerchantLookup,
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
