"""Store profile routes."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.models.merchant import Merchant
from app.models.store import Store
from app.models.user import User
from app.schemas.merchant import StoreProfileOut, StoreUpdateIn

router = APIRouter(prefix="/stores", tags=["stores"])


def _get_default_store_for_user(db: Session, user_id) -> Store | None:
    merchant = db.scalar(select(Merchant).where(Merchant.owner_user_id == user_id))
    if merchant is None:
        return None
    return db.scalar(
        select(Store).where(
            Store.merchant_id == merchant.id,
            Store.is_default.is_(True),
        )
    )


@router.patch("/default", response_model=StoreProfileOut)
def update_default_store(
    payload: StoreUpdateIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> StoreProfileOut:
    store = _get_default_store_for_user(db=db, user_id=current_user.id)
    if store is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Default store not found.",
        )
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
