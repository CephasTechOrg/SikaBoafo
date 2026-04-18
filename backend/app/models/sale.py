"""Sales and line items.

Invariant: ``total_amount`` should match the sum of ``SaleItem.line_total`` for the
same sale (enforce in ``SaleService`` when you add it). Inventory deduction belongs
in the same transaction as sale insert/update.

``SyncableWriteMixin``: when this sale was captured offline, ``source_device_id`` +
``local_operation_id`` must be set; the pair is used for idempotent sync apply.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, Integer, Numeric, String
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.constants import PAYMENT_STATUS_RECORDED, SALE_STATUS_RECORDED
from app.db.base import Base
from app.models.mixins import SyncableWriteMixin, TimestampMixin, UUIDPrimaryKeyMixin

if TYPE_CHECKING:
    from app.models.customer import Customer
    from app.models.item import Item
    from app.models.store import Store


class Sale(UUIDPrimaryKeyMixin, TimestampMixin, SyncableWriteMixin, Base):
    __tablename__ = "sales"

    store_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("stores.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    customer_id: Mapped[UUID | None] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("customers.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    total_amount: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    # cash | mobile_money | bank_transfer (MVP labels; architecture payment stage 1).
    payment_method_label: Mapped[str] = mapped_column(String(64), nullable=False)
    payment_status: Mapped[str] = mapped_column(
        String(32), default=PAYMENT_STATUS_RECORDED, nullable=False
    )
    sale_status: Mapped[str] = mapped_column(
        String(32), default=SALE_STATUS_RECORDED, nullable=False
    )
    voided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    void_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    note: Mapped[str | None] = mapped_column(String(500), nullable=True)

    store: Mapped[Store] = relationship("Store", lazy="joined")
    customer: Mapped[Customer | None] = relationship("Customer", lazy="joined")
    lines: Mapped[list[SaleItem]] = relationship(
        "SaleItem",
        back_populates="sale",
        lazy="selectin",
        cascade="all, delete-orphan",
    )


class SaleItem(UUIDPrimaryKeyMixin, Base):
    """One line on a sale; ``item_id`` uses ON DELETE RESTRICT so sold stock history stays valid."""

    __tablename__ = "sale_items"

    sale_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("sales.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    item_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("items.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    unit_price: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    line_total: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)

    sale: Mapped[Sale] = relationship("Sale", back_populates="lines")
    item: Mapped[Item] = relationship("Item", lazy="joined")
