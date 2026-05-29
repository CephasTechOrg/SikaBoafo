"""Rate limiting for `/auth/otp/request` keyed on normalized phone number."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.models.otp_send_throttle import OtpSendThrottle


class OtpSendRateLimitedError(Exception):
    """Too many OTP SMS requests for this phone number in the current window."""


@dataclass(slots=True)
class OtpSendGuard:
    db: Session
    settings: Settings

    def assert_can_send(self, *, phone_number: str) -> None:
        """Raise if this phone has exceeded OTP sends in the rolling window."""
        if self._remaining_sends(phone_number=phone_number) <= 0:
            msg = "Too many verification code requests. Please try again later."
            raise OtpSendRateLimitedError(msg)

    def record_send(self, *, phone_number: str) -> None:
        """Count a successful OTP send after SMS/mock path succeeds."""
        now = datetime.now(tz=UTC)
        window = timedelta(minutes=self.settings.auth_otp_send_window_minutes)
        row = self._get_row(phone_number=phone_number)
        if row is None:
            self.db.add(
                OtpSendThrottle(
                    phone_number=phone_number,
                    window_started_at=now,
                    send_count=1,
                )
            )
            self.db.flush()
            return
        if self._as_utc(row.window_started_at) + window <= now:
            row.window_started_at = now
            row.send_count = 1
        else:
            row.send_count += 1
        self.db.add(row)

    def _remaining_sends(self, *, phone_number: str) -> int:
        row = self._get_row(phone_number=phone_number)
        if row is None:
            return self.settings.auth_otp_send_max_per_window
        now = datetime.now(tz=UTC)
        window = timedelta(minutes=self.settings.auth_otp_send_window_minutes)
        if self._as_utc(row.window_started_at) + window <= now:
            return self.settings.auth_otp_send_max_per_window
        return max(0, self.settings.auth_otp_send_max_per_window - row.send_count)

    def _get_row(self, *, phone_number: str) -> OtpSendThrottle | None:
        return self.db.scalar(
            select(OtpSendThrottle).where(OtpSendThrottle.phone_number == phone_number)
        )

    @staticmethod
    def _as_utc(value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value.astimezone(UTC)


__all__ = ["OtpSendGuard", "OtpSendRateLimitedError"]
