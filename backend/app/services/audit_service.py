"""Audit trail writer — call from inside an open DB transaction before commit."""

from __future__ import annotations

from typing import Any
from uuid import UUID

from sqlalchemy.orm import Session

from app.models.audit_log import AuditLog


def log_audit(
    *,
    db: Session,
    action: str,
    entity_type: str,
    actor_user_id: UUID | None = None,
    business_id: UUID | None = None,
    entity_id: UUID | None = None,
    meta: dict[str, Any] | None = None,
    ip_address: str | None = None,
    user_agent: str | None = None,
) -> None:
    """Append an audit row inside the caller's transaction. Does not commit."""
    db.add(
        AuditLog(
            actor_user_id=actor_user_id,
            business_id=business_id,
            action=action,
            entity_type=entity_type,
            entity_id=entity_id,
            meta=meta,
            ip_address=ip_address,
            user_agent=user_agent,
        )
    )
