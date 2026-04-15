"""Server-side record of applied sync operations (idempotency audit).

The unique constraint on (device_id, local_operation_id) prevents double-applying
the same client operation after retries — see architecture.md §8.
"""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.mixins import UUIDPrimaryKeyMixin


class SyncOperation(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "sync_operations"
    __table_args__ = (
        UniqueConstraint(
            "device_id",
            "local_operation_id",
            name="uq_sync_device_local_op",
        ),
    )

    device_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    local_operation_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    entity_type: Mapped[str] = mapped_column(String(64), nullable=False)
    entity_id: Mapped[UUID] = mapped_column(PGUUID(as_uuid=True), nullable=False, index=True)
    action_type: Mapped[str] = mapped_column(String(32), nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False)
    processed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
