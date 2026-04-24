"""Payment settings service for merchant-owned Paystack credentials."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.constants import (
    PAYMENT_PROVIDER_PAYSTACK,
    PAYSTACK_MODE_LIVE,
    PAYSTACK_MODE_TEST,
)
from app.core.crypto import CryptoConfigError, decrypt_text, encrypt_text
from app.integrations.paystack.client import PaystackClient, PaystackClientError
from app.models.merchant import Merchant
from app.models.payment_provider_connection import PaymentProviderConnection
from app.schemas.payment_settings import PaystackConnectionOut, PaystackConnectionUpdateIn

_MODES = (PAYSTACK_MODE_TEST, PAYSTACK_MODE_LIVE)


class PaymentSettingsContextError(Exception):
    """Caller has no merchant context."""


class PaymentSettingsValidationError(Exception):
    """Input is structurally valid but not sufficient for a usable connection."""


@dataclass(slots=True)
class PaymentSettingsService:
    db: Session
    settings: Settings | None = None
    paystack_client: PaystackClient | None = None

    def get_paystack_connection(self, *, owner_user_id: UUID) -> PaystackConnectionOut:
        merchant = self._get_merchant(owner_user_id=owner_user_id)
        row = self._get_connection_row(merchant_id=merchant.id)
        if row is None:
            return self._default_out()
        row.is_connected = _is_mode_usable(row=row, mode=row.mode)
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        return _to_out(row)

    def upsert_paystack_connection(
        self,
        *,
        owner_user_id: UUID,
        payload: PaystackConnectionUpdateIn,
    ) -> PaystackConnectionOut:
        merchant = self._get_merchant(owner_user_id=owner_user_id)
        row = self._get_connection_row(merchant_id=merchant.id)
        if row is None:
            row = PaymentProviderConnection(
                merchant_id=merchant.id,
                provider=PAYMENT_PROVIDER_PAYSTACK,
            )
            self.db.add(row)

        mode = payload.mode
        if payload.secret_key is None and row.get_secret_key_encrypted(mode=mode) is None:
            msg = "Secret key is required for this mode."
            raise PaymentSettingsValidationError(msg)

        verified_at = row.get_verified_at(mode=mode)
        encrypted_secret = row.get_secret_key_encrypted(mode=mode)
        secret_key_last4 = row.get_secret_key_last4(mode=mode)
        if payload.secret_key is not None:
            configured = self.settings or get_settings()
            self._client(configured).fetch_payment_session_timeout(
                secret_key=payload.secret_key,
            )
            verified_at = datetime.now(tz=UTC)
            encrypted_secret = encrypt_text(
                plaintext=payload.secret_key,
                key=configured.payment_config_encryption_key,
            )
            secret_key_last4 = payload.secret_key[-4:]

        row.mode = mode
        row.account_label = payload.account_label
        if payload.public_key is not None:
            row.set_public_key(mode=mode, value=payload.public_key)
        row.set_secret_key_encrypted(mode=mode, value=encrypted_secret)
        row.set_secret_key_last4(mode=mode, value=secret_key_last4)
        row.set_verified_at(mode=mode, value=verified_at)
        row.is_connected = _is_mode_usable(row=row, mode=row.mode)

        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        return _to_out(row)

    def disconnect_paystack_connection(self, *, owner_user_id: UUID) -> PaystackConnectionOut:
        merchant = self._get_merchant(owner_user_id=owner_user_id)
        row = self._get_connection_row(merchant_id=merchant.id)
        if row is None:
            return self._default_out()

        for mode in _MODES:
            row.clear_mode_credentials(mode=mode)
        row.mode = PAYSTACK_MODE_TEST
        row.account_label = None
        row.is_connected = False
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        return _to_out(row)

    def _client(self, settings: Settings) -> PaystackClient:
        if self.paystack_client is not None:
            return self.paystack_client
        return PaystackClient(
            base_url=settings.paystack_api_base_url,
            timeout_seconds=settings.paystack_http_timeout_seconds,
        )

    def _get_merchant(self, *, owner_user_id: UUID) -> Merchant:
        merchant = self.db.scalar(select(Merchant).where(Merchant.owner_user_id == owner_user_id))
        if merchant is None:
            msg = "Merchant profile not found."
            raise PaymentSettingsContextError(msg)
        return merchant

    def _get_connection_row(self, *, merchant_id: UUID) -> PaymentProviderConnection | None:
        return self.db.scalar(
            select(PaymentProviderConnection).where(
                PaymentProviderConnection.merchant_id == merchant_id,
                PaymentProviderConnection.provider == PAYMENT_PROVIDER_PAYSTACK,
            )
        )

    @staticmethod
    def _default_out() -> PaystackConnectionOut:
        empty = PaystackConnectionOut.ModeCredentialState(
            configured=False,
            verified_at=None,
            public_key_masked=None,
            secret_key_masked=None,
        )
        return PaystackConnectionOut(
            provider=PAYMENT_PROVIDER_PAYSTACK,
            is_connected=False,
            mode=PAYSTACK_MODE_TEST,
            account_label=None,
            test=empty,
            live=empty,
        )


def get_decrypted_secret_for_mode(
    *,
    row: PaymentProviderConnection,
    mode: str,
    settings: Settings,
) -> str | None:
    encrypted = row.get_secret_key_encrypted(mode=mode)
    if encrypted is None:
        return None
    return decrypt_text(
        ciphertext=encrypted,
        key=settings.payment_config_encryption_key,
    )


def _mask_public_key(value: str | None) -> str | None:
    if value is None:
        return None
    normalized = value.strip()
    if not normalized:
        return None
    if len(normalized) <= 10:
        return f"{normalized[:2]}***{normalized[-2:]}"
    return f"{normalized[:6]}...{normalized[-4:]}"


def _mask_secret_suffix(*, mode: str, last4: str | None) -> str | None:
    if last4 is None or not last4.strip():
        return None
    prefix = "sk_test" if mode == PAYSTACK_MODE_TEST else "sk_live"
    return f"{prefix}_...{last4.strip()}"


def _is_mode_usable(*, row: PaymentProviderConnection, mode: str) -> bool:
    return bool(
        row.get_secret_key_encrypted(mode=mode) and row.get_verified_at(mode=mode) is not None
    )


def _mode_state(
    row: PaymentProviderConnection,
    *,
    mode: str,
) -> PaystackConnectionOut.ModeCredentialState:
    return PaystackConnectionOut.ModeCredentialState(
        configured=row.get_secret_key_encrypted(mode=mode) is not None,
        verified_at=row.get_verified_at(mode=mode),
        public_key_masked=_mask_public_key(row.get_public_key(mode=mode)),
        secret_key_masked=_mask_secret_suffix(
            mode=mode,
            last4=row.get_secret_key_last4(mode=mode),
        ),
    )


def _to_out(row: PaymentProviderConnection) -> PaystackConnectionOut:
    return PaystackConnectionOut(
        provider=row.provider,
        is_connected=_is_mode_usable(row=row, mode=row.mode),
        mode=row.mode,
        account_label=row.account_label,
        test=_mode_state(row, mode=PAYSTACK_MODE_TEST),
        live=_mode_state(row, mode=PAYSTACK_MODE_LIVE),
    )


__all__ = [
    "PaymentSettingsContextError",
    "PaymentSettingsService",
    "PaymentSettingsValidationError",
    "CryptoConfigError",
    "PaystackClientError",
    "get_decrypted_secret_for_mode",
]
