"""Payment webhook event idempotency log (M4 Step 3 hardening)."""

from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.constants import PAYMENT_PROVIDER_PAYSTACK
from app.db.base import Base
from app.models.mixins import TimestampMixin, UUIDPrimaryKeyMixin

_JSONB_OR_JSON = JSONB().with_variant(sa.JSON(), "sqlite")


class PaymentWebhookEvent(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "payment_webhook_events"
    __table_args__ = (
        UniqueConstraint(
            "provider",
            "event_key",
            name="uq_payment_webhook_events_provider_event_key",
        ),
    )

    provider: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default=PAYMENT_PROVIDER_PAYSTACK,
        index=True,
    )
    event_key: Mapped[str] = mapped_column(String(255), nullable=False)
    provider_reference: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    payment_id: Mapped[UUID | None] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("payments.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    result_status: Mapped[str] = mapped_column(String(32), nullable=False, default="processed")
    payload: Mapped[dict[str, Any] | None] = mapped_column(_JSONB_OR_JSON, nullable=True)
    processed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

