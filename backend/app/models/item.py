"""Catalog items per store."""

from __future__ import annotations

from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, Numeric, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import SyncableWriteMixin, TimestampMixin, UUIDPrimaryKeyMixin

if TYPE_CHECKING:
    from app.models.store import Store


class Item(UUIDPrimaryKeyMixin, TimestampMixin, SyncableWriteMixin, Base):
    __tablename__ = "items"

    store_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("stores.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    sku: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)
    category: Mapped[str | None] = mapped_column(String(128), nullable=True)
    default_price: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    cost_price: Mapped[Decimal | None] = mapped_column(Numeric(18, 2), nullable=True)
    unit: Mapped[str | None] = mapped_column(String(32), nullable=True)
    low_stock_threshold: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1, server_default="1")
    image_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    store: Mapped[Store] = relationship("Store", back_populates="items", lazy="joined")
    variants: Mapped[list[ItemVariant]] = relationship(
        "ItemVariant",
        back_populates="item",
        lazy="selectin",
        cascade="all, delete-orphan",
        order_by="ItemVariant.sort_order",
    )


class ItemVariant(UUIDPrimaryKeyMixin, Base):
    """A size/variant option for a parent Item (e.g. Small, Medium, Large)."""

    __tablename__ = "item_variants"

    item_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("items.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    label: Mapped[str] = mapped_column(String(64), nullable=False)
    price_override: Mapped[Decimal | None] = mapped_column(Numeric(18, 2), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    item: Mapped[Item] = relationship("Item", back_populates="variants")
