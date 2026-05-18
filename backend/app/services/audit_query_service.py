"""Read-side service for owner activity logs."""

from __future__ import annotations

import base64
from dataclasses import dataclass
from datetime import datetime
from uuid import UUID

from sqlalchemy import Select, and_, desc, or_, select
from sqlalchemy.orm import Session

from app.models.audit_log import AuditLog
from app.models.user import User


@dataclass(frozen=True)
class AuditLogRow:
    audit_log: AuditLog
    actor_label: str | None


@dataclass(frozen=True)
class AuditLogPage:
    rows: list[AuditLogRow]
    next_cursor: str | None


class InvalidAuditCursorError(Exception):
    """Raised when an audit pagination cursor cannot be decoded."""


def _encode_cursor(created_at: datetime, audit_log_id: UUID) -> str:
    raw = f"{created_at.isoformat()}|{audit_log_id}"
    return base64.urlsafe_b64encode(raw.encode("utf-8")).decode("ascii")


def _decode_cursor(cursor: str) -> tuple[datetime, UUID]:
    try:
        raw = base64.urlsafe_b64decode(cursor.encode("ascii")).decode("utf-8")
        created_at_raw, audit_log_id_raw = raw.split("|", maxsplit=1)
        return datetime.fromisoformat(created_at_raw), UUID(audit_log_id_raw)
    except (ValueError, UnicodeDecodeError) as exc:
        raise InvalidAuditCursorError("Invalid audit log cursor.") from exc


def _actor_label(user: User | None) -> str | None:
    if user is None:
        return None
    if user.full_name:
        return user.full_name
    phone = user.phone_number
    if not phone:
        return None
    return f"...{phone[-4:]}" if len(phone) > 4 else phone


class AuditQueryService:
    def __init__(self, *, db: Session) -> None:
        self.db = db

    def list_logs(
        self,
        *,
        business_id: UUID,
        limit: int,
        action: str | None = None,
        from_at: datetime | None = None,
        to_at: datetime | None = None,
        cursor: str | None = None,
    ) -> AuditLogPage:
        stmt: Select[tuple[AuditLog, User | None]] = (
            select(AuditLog, User)
            .outerjoin(User, User.id == AuditLog.actor_user_id)
            .where(AuditLog.business_id == business_id)
        )
        if action:
            stmt = stmt.where(AuditLog.action == action)
        if from_at is not None:
            stmt = stmt.where(AuditLog.created_at >= from_at)
        if to_at is not None:
            stmt = stmt.where(AuditLog.created_at <= to_at)
        if cursor:
            cursor_created_at, cursor_id = _decode_cursor(cursor)
            stmt = stmt.where(
                or_(
                    AuditLog.created_at < cursor_created_at,
                    and_(
                        AuditLog.created_at == cursor_created_at,
                        AuditLog.id < cursor_id,
                    ),
                )
            )

        rows = self.db.execute(
            stmt.order_by(desc(AuditLog.created_at), desc(AuditLog.id)).limit(limit + 1)
        ).all()
        next_cursor = None
        if len(rows) > limit:
            rows = rows[:limit]
            last_log = rows[-1][0]
            next_cursor = _encode_cursor(last_log.created_at, last_log.id)

        return AuditLogPage(
            rows=[
                AuditLogRow(audit_log=audit_log, actor_label=_actor_label(user))
                for audit_log, user in rows
            ],
            next_cursor=next_cursor,
        )
