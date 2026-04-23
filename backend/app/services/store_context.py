"""Unified store context resolution — works for owners and staff members."""

from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.merchant import Merchant
from app.models.store import Store
from app.models.user import User


class StoreContextError(Exception):
    """No resolvable store context for the given user."""


def get_merchant_and_store(*, user_id: UUID, db: Session) -> tuple[Merchant, Store]:
    """Return (merchant, default_store) for user_id.

    Owner path: Merchant.owner_user_id == user_id.
    Staff path: user.merchant_id → Merchant.id.
    Raises StoreContextError if neither path resolves.
    """
    # Owner path (most common — check first for performance)
    merchant = db.scalar(select(Merchant).where(Merchant.owner_user_id == user_id))

    if merchant is None:
        # Staff path
        user = db.scalar(select(User).where(User.id == user_id))
        if user is not None and user.merchant_id is not None:
            merchant = db.scalar(select(Merchant).where(Merchant.id == user.merchant_id))

    if merchant is None:
        msg = "Merchant profile not found."
        raise StoreContextError(msg)

    store = db.scalar(
        select(Store).where(
            Store.merchant_id == merchant.id,
            Store.is_default.is_(True),
        )
    )
    if store is None:
        msg = "Default store not found."
        raise StoreContextError(msg)

    return merchant, store
