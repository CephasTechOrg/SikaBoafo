"""Customer debts (receivables) and repayments.

``outstanding_amount`` must stay in sync with ``ReceivablePayment`` rows; enforce in
a service when recording partial repayments (never only in the client).
"""

from __future__ import annotations

from datetime import date
from decimal import Decimal
from typing import TYPE_CHECKING
from uuid import UUID

from sqlalchemy import Date, ForeignKey, Numeric, String
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.constants import RECEIVABLE_STATUS_OPEN
from app.db.base import Base
from app.models.mixins import SyncableWriteMixin, TimestampMixin, UUIDPrimaryKeyMixin

if TYPE_CHECKING:
    from app.models.customer import Customer
    from app.models.store import Store


class Receivable(UUIDPrimaryKeyMixin, TimestampMixin, SyncableWriteMixin, Base):
    __tablename__ = "receivables"

    store_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("stores.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    customer_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("customers.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    original_amount: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    outstanding_amount: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    due_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    status: Mapped[str] = mapped_column(
        String(32), default=RECEIVABLE_STATUS_OPEN, nullable=False
    )

    store: Mapped[Store] = relationship("Store", lazy="joined")
    customer: Mapped[Customer] = relationship("Customer", lazy="joined")
    payments: Mapped[list[ReceivablePayment]] = relationship(
        "ReceivablePayment",
        back_populates="receivable",
        lazy="selectin",
        cascade="all, delete-orphan",
    )


class ReceivablePayment(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "receivable_payments"

    receivable_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("receivables.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    payment_method_label: Mapped[str] = mapped_column(String(64), nullable=False)

    receivable: Mapped[Receivable] = relationship("Receivable", back_populates="payments")
