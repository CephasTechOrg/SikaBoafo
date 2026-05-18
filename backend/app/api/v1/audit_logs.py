"""Owner activity log routes."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_merchant_owner
from app.models.user import User
from app.schemas.audit_log import AuditLogListOut, AuditLogOut
from app.services.audit_query_service import AuditQueryService, InvalidAuditCursorError
from app.services.store_context import StoreContextError, get_merchant_and_store

router = APIRouter(prefix="/audit-logs", tags=["audit-logs"])


@router.get("", response_model=AuditLogListOut)
def list_audit_logs(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_merchant_owner)],
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    cursor: Annotated[str | None, Query()] = None,
    action: Annotated[str | None, Query(max_length=128)] = None,
    from_at: Annotated[datetime | None, Query(alias="from")] = None,
    to_at: Annotated[datetime | None, Query(alias="to")] = None,
) -> AuditLogListOut:
    try:
        merchant, _ = get_merchant_and_store(user_id=current_user.id, db=db)
    except StoreContextError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc

    service = AuditQueryService(db=db)
    try:
        page = service.list_logs(
            business_id=merchant.id,
            limit=limit,
            action=action,
            from_at=from_at,
            to_at=to_at,
            cursor=cursor,
        )
    except InvalidAuditCursorError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc

    return AuditLogListOut(
        items=[
            AuditLogOut(
                audit_log_id=row.audit_log.id,
                actor_user_id=row.audit_log.actor_user_id,
                actor_label=row.actor_label,
                action=row.audit_log.action,
                entity_type=row.audit_log.entity_type,
                entity_id=row.audit_log.entity_id,
                meta=row.audit_log.meta,
                created_at=row.audit_log.created_at,
            )
            for row in page.rows
        ],
        next_cursor=page.next_cursor,
    )
