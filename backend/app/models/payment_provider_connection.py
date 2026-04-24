"""Merchant payment-provider connection settings (M4 Step 1)."""

from __future__ import annotations

from typing import TYPE_CHECKING
from uuid import UUID

from sqlalchemy import Boolean, ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.constants import PAYMENT_PROVIDER_PAYSTACK, PAYSTACK_MODE_TEST
from app.db.base import Base
from app.models.mixins import TimestampMixin, UUIDPrimaryKeyMixin

if TYPE_CHECKING:
    from app.models.merchant import Merchant


class PaymentProviderConnection(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "payment_provider_connections"
    __table_args__ = (
        UniqueConstraint(
            "merchant_id",
            "provider",
            name="uq_payment_provider_connections_merchant_provider",
        ),
    )

    merchant_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    provider: Mapped[str] = mapped_column(
        String(32),
        default=PAYMENT_PROVIDER_PAYSTACK,
        nullable=False,
        index=True,
    )
    mode: Mapped[str] = mapped_column(String(16), default=PAYSTACK_MODE_TEST, nullable=False)
    account_label: Mapped[str | None] = mapped_column(String(120), nullable=True)
    public_key: Mapped[str | None] = mapped_column(String(255), nullable=True)
    is_connected: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

