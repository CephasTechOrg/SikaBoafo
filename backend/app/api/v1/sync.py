"""Offline sync apply endpoint."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.core.config import Settings, get_settings
from app.models.user import User
from app.schemas.sync import SyncApplyIn, SyncApplyOperationOut, SyncApplyOut
from app.services.sync_apply_guard import SyncApplyGuard, SyncApplyRateLimitedError
from app.services.sync_service import SyncService

router = APIRouter(prefix="/sync", tags=["sync"])


@router.post("/apply", response_model=SyncApplyOut)
def apply_sync_operations(
    payload: SyncApplyIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> SyncApplyOut:
    guard = SyncApplyGuard(db=db, settings=settings)
    try:
        guard.assert_can_apply(user_id=current_user.id)
    except SyncApplyRateLimitedError as exc:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=str(exc),
        ) from exc
    guard.record_apply(user_id=current_user.id)
    # Persist the throttle count up front so per-operation rollbacks inside the
    # sync service cannot discard it.
    db.commit()

    service = SyncService(db=db)
    results = service.apply_operations(
        user_id=current_user.id,
        device_id=payload.device_id,
        operations=payload.operations,
    )
    return SyncApplyOut(
        results=[
            SyncApplyOperationOut(
                local_operation_id=r.local_operation_id,
                entity_type=r.entity_type,
                action_type=r.action_type,
                status=r.status,
                entity_id=r.entity_id,
                detail=r.detail,
                server_version=r.server_version,
            )
            for r in results
        ]
    )
