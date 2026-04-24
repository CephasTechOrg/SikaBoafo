"""Locally managed OTP challenges delivered via SMS provider."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.mixins import TimestampMixin, UUIDPrimaryKeyMixin


class OtpCode(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "otp_codes"

    phone_number: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    code_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    attempt_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    delivery_provider: Mapped[str | None] = mapped_column(String(32), nullable=True)
    delivery_reference: Mapped[str | None] = mapped_column(String(255), nullable=True)
