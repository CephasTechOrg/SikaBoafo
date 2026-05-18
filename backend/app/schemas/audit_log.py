"""Audit log API schemas."""

from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel


class AuditLogOut(BaseModel):
    audit_log_id: UUID
    actor_user_id: UUID | None
    actor_label: str | None
    action: str
    entity_type: str | None
    entity_id: UUID | None
    meta: dict[str, Any] | None
    created_at: datetime


class AuditLogListOut(BaseModel):
    items: list[AuditLogOut]
    next_cursor: str | None = None
