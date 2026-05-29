"""Per-phone OTP SMS request throttling (abuse protection)."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.mixins import TimestampMixin, UUIDPrimaryKeyMixin


class OtpSendThrottle(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "otp_send_throttles"
    __table_args__ = (UniqueConstraint("phone_number", name="uq_otp_send_throttles_phone"),)

    phone_number: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    window_started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    send_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
    )
