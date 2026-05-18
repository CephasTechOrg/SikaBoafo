"""Store profile routes."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_merchant_owner
from app.models.user import User
from app.schemas.merchant import StoreProfileOut, StoreUpdateIn
from app.services.store_context import StoreContextError, get_merchant_and_store

router = APIRouter(prefix="/stores", tags=["stores"])


@router.patch("/default", response_model=StoreProfileOut)
def update_default_store(
    payload: StoreUpdateIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_merchant_owner)],
) -> StoreProfileOut:
    try:
        _, store = get_merchant_and_store(user_id=current_user.id, db=db)
    except StoreContextError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    store.name = payload.name.strip()
    store.location = payload.location.strip() if payload.location else None
    store.timezone = payload.timezone.strip()
    db.commit()
    db.refresh(store)
    return StoreProfileOut(
        store_id=store.id,
        name=store.name,
        location=store.location,
        timezone=store.timezone,
        is_default=store.is_default,
    )
