"""User accounts (phone OTP — auth logic comes in `todo.md` §6)."""

from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import Boolean, String, UniqueConstraint
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
    role: Mapped[str] = mapped_column(
        String(32), default=USER_ROLE_MERCHANT_OWNER, nullable=False
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    merchants: Mapped[list[Merchant]] = relationship(
        "Merchant",
        back_populates="owner",
        lazy="selectin",
    )
