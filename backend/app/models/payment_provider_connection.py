"""Merchant payment-provider connection settings."""

from __future__ import annotations

from typing import TYPE_CHECKING
from uuid import UUID

from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, UniqueConstraint
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
    test_public_key: Mapped[str | None] = mapped_column(String(255), nullable=True)
    live_public_key: Mapped[str | None] = mapped_column(String(255), nullable=True)
    test_secret_key_encrypted: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    live_secret_key_encrypted: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    test_secret_key_last4: Mapped[str | None] = mapped_column(String(4), nullable=True)
    live_secret_key_last4: Mapped[str | None] = mapped_column(String(4), nullable=True)
    test_verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    live_verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    is_connected: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    def get_public_key(self, *, mode: str) -> str | None:
        return self.test_public_key if mode == "test" else self.live_public_key

    def set_public_key(self, *, mode: str, value: str | None) -> None:
        if mode == "test":
            self.test_public_key = value
        else:
            self.live_public_key = value

    def get_secret_key_encrypted(self, *, mode: str) -> str | None:
        return self.test_secret_key_encrypted if mode == "test" else self.live_secret_key_encrypted

    def set_secret_key_encrypted(self, *, mode: str, value: str | None) -> None:
        if mode == "test":
            self.test_secret_key_encrypted = value
        else:
            self.live_secret_key_encrypted = value

    def get_secret_key_last4(self, *, mode: str) -> str | None:
        return self.test_secret_key_last4 if mode == "test" else self.live_secret_key_last4

    def set_secret_key_last4(self, *, mode: str, value: str | None) -> None:
        if mode == "test":
            self.test_secret_key_last4 = value
        else:
            self.live_secret_key_last4 = value

    def get_verified_at(self, *, mode: str) -> datetime | None:
        return self.test_verified_at if mode == "test" else self.live_verified_at

    def set_verified_at(self, *, mode: str, value: datetime | None) -> None:
        if mode == "test":
            self.test_verified_at = value
        else:
            self.live_verified_at = value

    def clear_mode_credentials(self, *, mode: str) -> None:
        self.set_public_key(mode=mode, value=None)
        self.set_secret_key_encrypted(mode=mode, value=None)
        self.set_secret_key_last4(mode=mode, value=None)
        self.set_verified_at(mode=mode, value=None)
