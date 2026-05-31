"""Offline sync apply + incremental pull endpoints."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.api.v1.items import _to_item_out
from app.api.v1.receivables import _receivable_out
from app.core.config import Settings, get_settings
from app.models.user import User
from app.schemas.receivable import CustomerOut
from app.schemas.sync import SyncApplyIn, SyncApplyOperationOut, SyncApplyOut, SyncPullOut
from app.services.sync_apply_guard import SyncApplyGuard, SyncApplyRateLimitedError
from app.services.sync_pull_service import ReceivableContextMissingError, SyncPullService
from app.services.sync_service import SyncService

router = APIRouter(prefix="/sync", tags=["sync"])


def _parse_include_domains(raw: str | None) -> tuple[bool, bool]:
    if raw is None or not raw.strip():
        return True, True
    tokens = {part.strip().lower() for part in raw.split(",") if part.strip()}
    include_inventory = "inventory" in tokens or "items" in tokens
    include_debts = "debts" in tokens or "receivables" in tokens
    if not include_inventory and not include_debts:
        return True, True
    return include_inventory, include_debts


@router.get("/pull", response_model=SyncPullOut)
def pull_sync_changes(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    since: Annotated[datetime | None, Query()] = None,
    include: Annotated[
        str | None,
        Query(description="Comma-separated domains: inventory,debts"),
    ] = None,
    limit: Annotated[int, Query(ge=1, le=500)] = 500,
) -> SyncPullOut:
    include_inventory, include_debts = _parse_include_domains(include)
    service = SyncPullService(db=db)
    try:
        result = service.pull_for_user(
            user_id=current_user.id,
            since=since,
            include_inventory=include_inventory,
            include_debts=include_debts,
            limit=limit,
        )
    except ReceivableContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return SyncPullOut(
        cursor=result.cursor,
        full_refresh=result.full_refresh,
        inventory=[_to_item_out(item) for item in result.inventory],
        customers=[
            CustomerOut(
                customer_id=c.customer_id,
                name=c.name,
                phone_number=c.phone_number,
                whatsapp_number=c.whatsapp_number,
                email=c.email,
                notes=c.notes,
                total_outstanding=c.total_outstanding,
                created_at=c.created_at,
            )
            for c in result.customers
        ],
        receivables=[_receivable_out(r) for r in result.receivables],
    )


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
