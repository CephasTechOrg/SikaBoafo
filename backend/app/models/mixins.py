"""Reusable column groups — keeps sync/idempotency rules consistent (`architecture.md` §8)."""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, declarative_mixin, mapped_column


@declarative_mixin
class UUIDPrimaryKeyMixin:
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )


@declarative_mixin
class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )


@declarative_mixin
class SyncableWriteMixin:
    """Offline-originated writes: idempotent apply via (source_device_id, local_operation_id)."""

    source_device_id: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)
    local_operation_id: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)
