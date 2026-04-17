"""Merchant profile/context routes."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.models.merchant import Merchant
from app.models.store import Store
from app.models.user import User
from app.schemas.merchant import (
    MerchantContextOut,
    MerchantProfileOut,
    MerchantUpdateIn,
    StoreProfileOut,
)

router = APIRouter(prefix="/merchants", tags=["merchants"])


def _get_owner_merchant(db: Session, user_id) -> Merchant | None:
    return db.scalar(select(Merchant).where(Merchant.owner_user_id == user_id))


@router.get("/me/context", response_model=MerchantContextOut)
def get_my_context(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> MerchantContextOut:
    merchant = _get_owner_merchant(db=db, user_id=current_user.id)
    if merchant is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Merchant profile not found. Complete onboarding first.",
        )

    default_store = db.scalar(
        select(Store).where(Store.merchant_id == merchant.id, Store.is_default.is_(True))
    )
    if default_store is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Default store not found.",
        )

    return MerchantContextOut(
        merchant=MerchantProfileOut(
            merchant_id=merchant.id,
            business_name=merchant.business_name,
            business_type=merchant.business_type,
        ),
        default_store=StoreProfileOut(
            store_id=default_store.id,
            name=default_store.name,
            location=default_store.location,
            timezone=default_store.timezone,
            is_default=default_store.is_default,
        ),
    )


@router.patch("/me", response_model=MerchantProfileOut)
def update_my_merchant(
    payload: MerchantUpdateIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> MerchantProfileOut:
    merchant = _get_owner_merchant(db=db, user_id=current_user.id)
    if merchant is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Merchant profile not found.",
        )
    merchant.business_name = payload.business_name.strip()
    merchant.business_type = payload.business_type.strip() if payload.business_type else None
    db.commit()
    db.refresh(merchant)
    return MerchantProfileOut(
        merchant_id=merchant.id,
        business_name=merchant.business_name,
        business_type=merchant.business_type,
    )
