"""Rate limiting for `/sync/apply` keyed on the authenticated user id."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.models.sync_apply_throttle import SyncApplyThrottle


class SyncApplyRateLimitedError(Exception):
    """Too many `/sync/apply` requests for this user in the current window."""


@dataclass(slots=True)
class SyncApplyGuard:
    db: Session
    settings: Settings

    def assert_can_apply(self, *, user_id: UUID) -> None:
        """Raise if this user has exceeded sync applies in the rolling window."""
        if self._remaining(user_id=user_id) <= 0:
            msg = "Too many sync requests. Please slow down and try again shortly."
            raise SyncApplyRateLimitedError(msg)

    def record_apply(self, *, user_id: UUID) -> None:
        """Count a sync apply request against the current window."""
        now = datetime.now(tz=UTC)
        window = timedelta(minutes=self.settings.sync_apply_window_minutes)
        row = self._get_row(user_id=user_id)
        if row is None:
            self.db.add(
                SyncApplyThrottle(
                    user_id=user_id,
                    window_started_at=now,
                    request_count=1,
                )
            )
            self.db.flush()
            return
        if self._as_utc(row.window_started_at) + window <= now:
            row.window_started_at = now
            row.request_count = 1
        else:
            row.request_count += 1
        self.db.add(row)

    def _remaining(self, *, user_id: UUID) -> int:
        row = self._get_row(user_id=user_id)
        if row is None:
            return self.settings.sync_apply_max_per_window
        now = datetime.now(tz=UTC)
        window = timedelta(minutes=self.settings.sync_apply_window_minutes)
        if self._as_utc(row.window_started_at) + window <= now:
            return self.settings.sync_apply_max_per_window
        return max(0, self.settings.sync_apply_max_per_window - row.request_count)

    def _get_row(self, *, user_id: UUID) -> SyncApplyThrottle | None:
        return self.db.scalar(
            select(SyncApplyThrottle).where(SyncApplyThrottle.user_id == user_id)
        )

    @staticmethod
    def _as_utc(value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value.astimezone(UTC)


__all__ = ["SyncApplyGuard", "SyncApplyRateLimitedError"]
