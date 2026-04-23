"""Merchant (business) aggregate root."""

from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import TimestampMixin, UUIDPrimaryKeyMixin

if TYPE_CHECKING:
    from app.models.store import Store
    from app.models.user import User


class Merchant(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "merchants"

    business_name: Mapped[str] = mapped_column(String(255), nullable=False)
    business_type: Mapped[str | None] = mapped_column(String(128), nullable=True)
    owner_user_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Contact & location (M1 additions)
    phone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    whatsapp_number: Mapped[str | None] = mapped_column(String(32), nullable=True)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    address: Mapped[str | None] = mapped_column(String(500), nullable=True)
    city: Mapped[str | None] = mapped_column(String(128), nullable=True)
    region: Mapped[str | None] = mapped_column(String(128), nullable=True)
    country: Mapped[str] = mapped_column(String(8), nullable=False, default="GH")
    currency_code: Mapped[str] = mapped_column(String(8), nullable=False, default="GHS")

    owner: Mapped[User] = relationship(
        "User",
        back_populates="merchants",
        foreign_keys="[Merchant.owner_user_id]",
        lazy="joined",
    )
    stores: Mapped[list[Store]] = relationship(
        "Store",
        back_populates="merchant",
        lazy="selectin",
    )
