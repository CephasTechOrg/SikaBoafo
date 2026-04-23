"""User accounts (phone OTP + PIN — see `docs/auth/pin-and-otp-flow.md`)."""

from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING
from uuid import UUID

from sqlalchemy import Boolean, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.constants import USER_ROLE_MERCHANT_OWNER
from app.db.base import Base
from app.models.mixins import TimestampMixin, UUIDPrimaryKeyMixin

if TYPE_CHECKING:
    from app.models.merchant import Merchant


class User(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "users"
    __table_args__ = (UniqueConstraint("phone_number", name="uq_users_phone_number"),)

    phone_number: Mapped[str] = mapped_column(String(32), index=True, nullable=False)
    pin_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    role: Mapped[str] = mapped_column(
        String(32), default=USER_ROLE_MERCHANT_OWNER, nullable=False
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # Profile (M1 additions)
    full_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    last_login_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Staff linkage (M2): set when this user is a staff member, NULL for owners
    merchant_id: Mapped[UUID | None] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    merchants: Mapped[list[Merchant]] = relationship(
        "Merchant",
        back_populates="owner",
        foreign_keys="[Merchant.owner_user_id]",
        lazy="selectin",
    )
