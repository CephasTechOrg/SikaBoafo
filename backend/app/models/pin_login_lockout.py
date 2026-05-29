"""Per-phone PIN login attempt tracking (brute-force protection)."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.mixins import TimestampMixin, UUIDPrimaryKeyMixin


class PinLoginLockout(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "pin_login_lockouts"
    __table_args__ = (UniqueConstraint("phone_number", name="uq_pin_login_lockouts_phone"),)

    phone_number: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    failed_attempt_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
    )
    locked_until: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
