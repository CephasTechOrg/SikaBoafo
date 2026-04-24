"""Payment settings service (M4 Step 1)."""

from __future__ import annotations

from dataclasses import dataclass
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.constants import PAYMENT_PROVIDER_PAYSTACK, PAYSTACK_MODE_TEST
from app.models.merchant import Merchant
from app.models.payment_provider_connection import PaymentProviderConnection
from app.schemas.payment_settings import PaystackConnectionOut, PaystackConnectionUpdateIn


class PaymentSettingsContextError(Exception):
    """Caller has no merchant context."""


@dataclass(slots=True)
class PaymentSettingsService:
    db: Session

    def get_paystack_connection(self, *, owner_user_id: UUID) -> PaystackConnectionOut:
        merchant = self._get_merchant(owner_user_id=owner_user_id)
        row = self._get_connection_row(merchant_id=merchant.id)
        if row is None:
            return self._default_out()
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

        row.mode = payload.mode
        row.account_label = payload.account_label
        row.public_key = payload.public_key
        row.is_connected = True

        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        return _to_out(row)

    def disconnect_paystack_connection(self, *, owner_user_id: UUID) -> PaystackConnectionOut:
        merchant = self._get_merchant(owner_user_id=owner_user_id)
        row = self._get_connection_row(merchant_id=merchant.id)
        if row is None:
            return self._default_out()

        row.is_connected = False
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        return _to_out(row)

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
        return PaystackConnectionOut(
            provider=PAYMENT_PROVIDER_PAYSTACK,
            is_connected=False,
            mode=PAYSTACK_MODE_TEST,
            account_label=None,
            public_key_masked=None,
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


def _to_out(row: PaymentProviderConnection) -> PaystackConnectionOut:
    return PaystackConnectionOut(
        provider=row.provider,
        is_connected=row.is_connected,
        mode=row.mode,
        account_label=row.account_label,
        public_key_masked=_mask_public_key(row.public_key),
    )

