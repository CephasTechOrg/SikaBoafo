"""Unified store context resolution for merchant owners and staff users."""

from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.constants import USER_ROLE_MERCHANT_OWNER
from app.models.merchant import Merchant
from app.models.store import Store
from app.models.user import User


class StoreContextError(Exception):
    """No resolvable store context for the given user."""


def get_merchant_and_store(*, user_id: UUID, db: Session) -> tuple[Merchant, Store]:
    """Return ``(merchant, default_store)`` for ``user_id``.

    Merchant owners resolve through ``Merchant.owner_user_id``. Staff users resolve
    through ``User.merchant_id`` even if a legacy owner-owned merchant row also
    exists for the same account.
    """

    user = db.scalar(select(User).where(User.id == user_id))
    merchant = None

    if user is not None and user.role not in {None, USER_ROLE_MERCHANT_OWNER}:
        if user.merchant_id is not None:
            merchant = db.scalar(select(Merchant).where(Merchant.id == user.merchant_id))
    else:
        merchant = db.scalar(select(Merchant).where(Merchant.owner_user_id == user_id))
        if merchant is None and user is not None and user.merchant_id is not None:
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
