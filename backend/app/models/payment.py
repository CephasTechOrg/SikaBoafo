"""Paystack-backed payments (digital rail).

``confirmed_at`` / ``status`` must only be set from verified webhook handling on
the server — never trust the mobile app as final authority (architecture.md §9.2).
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy import DateTime, ForeignKey, Numeric, String, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.constants import (
    DEFAULT_CURRENCY,
    PAYMENT_PROVIDER_PAYSTACK,
    PROVIDER_PAYMENT_PENDING,
)
from app.db.base import Base
from app.models.mixins import UUIDPrimaryKeyMixin

_JSONB_OR_JSON = JSONB().with_variant(sa.JSON(), "sqlite")


class Payment(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "payments"

    merchant_id: Mapped[UUID | None] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("merchants.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    sale_id: Mapped[UUID | None] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("sales.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    receivable_id: Mapped[UUID | None] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("receivables.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    receivable_payment_id: Mapped[UUID | None] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("receivable_payments.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    provider: Mapped[str] = mapped_column(
        String(32), default=PAYMENT_PROVIDER_PAYSTACK, nullable=False
    )
    provider_reference: Mapped[str | None] = mapped_column(
        String(255), nullable=True, unique=True
    )
    internal_reference: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    provider_mode: Mapped[str | None] = mapped_column(String(16), nullable=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(8), default=DEFAULT_CURRENCY, nullable=False)
    status: Mapped[str] = mapped_column(
        String(32), default=PROVIDER_PAYMENT_PENDING, nullable=False
    )
    # Paystack initiation time; services should set explicitly. DB default supports tests/seeds.
    initiated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    raw_provider_payload: Mapped[dict[str, Any] | None] = mapped_column(
        _JSONB_OR_JSON, nullable=True
    )
