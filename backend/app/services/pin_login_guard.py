"""Rate limiting for `/auth/pin/login` keyed on normalized phone number."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.models.pin_login_lockout import PinLoginLockout


class PinLoginLockedError(Exception):
    """Too many failed PIN attempts for this phone number."""


@dataclass(slots=True)
class PinLoginGuard:
    db: Session
    settings: Settings

    def assert_can_attempt(self, *, phone_number: str) -> None:
        row = self._get_row(phone_number=phone_number)
        if row is None or row.locked_until is None:
            return
        locked_until = self._as_utc(row.locked_until)
        if locked_until <= datetime.now(tz=UTC):
            row.locked_until = None
            self.db.add(row)
            return
        msg = "Too many PIN attempts. Try again later or use Forgot PIN."
        raise PinLoginLockedError(msg)

    def record_failure(self, *, phone_number: str) -> None:
        row = self._get_or_create(phone_number=phone_number)
        row.failed_attempt_count += 1
        if row.failed_attempt_count >= self.settings.auth_pin_max_attempts:
            row.locked_until = datetime.now(tz=UTC) + timedelta(
                minutes=self.settings.auth_pin_lockout_minutes
            )
            row.failed_attempt_count = 0
        self.db.add(row)

    def clear_failures(self, *, phone_number: str) -> None:
        row = self._get_row(phone_number=phone_number)
        if row is None:
            return
        self.db.delete(row)

    def _get_row(self, *, phone_number: str) -> PinLoginLockout | None:
        return self.db.scalar(
            select(PinLoginLockout).where(PinLoginLockout.phone_number == phone_number)
        )

    def _get_or_create(self, *, phone_number: str) -> PinLoginLockout:
        row = self._get_row(phone_number=phone_number)
        if row is not None:
            return row
        row = PinLoginLockout(phone_number=phone_number, failed_attempt_count=0)
        self.db.add(row)
        self.db.flush()
        return row

    @staticmethod
    def _as_utc(value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value.astimezone(UTC)


__all__ = ["PinLoginGuard", "PinLoginLockedError"]
