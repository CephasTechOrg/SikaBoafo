"""Seed a minimal merchant + store + sample item for local development.

Run from ``backend/``::

    PYTHONPATH=. python scripts/seed_dev.py

Uses idempotent upserts: safe to run multiple times. FK order is user → merchant
→ store → item (matches the domain graph).
"""

from __future__ import annotations

import os
import sys
from decimal import Decimal

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.constants import DEFAULT_STORE_TIMEZONE, USER_ROLE_MERCHANT_OWNER
from app.db.session import SessionLocal
from app.models import Item, Merchant, Store, User
from sqlalchemy import select

# Stable dev identity; change if it collides with your local data.
SEED_DEV_PHONE = "+233200000000"


def main() -> None:
    db = SessionLocal()
    try:
        user = db.execute(
            select(User).where(User.phone_number == SEED_DEV_PHONE)
        ).scalar_one_or_none()
        if user is None:
            user = User(
                phone_number=SEED_DEV_PHONE,
                role=USER_ROLE_MERCHANT_OWNER,
                is_active=True,
            )
            db.add(user)
            db.flush()

        merchant = db.execute(
            select(Merchant).where(Merchant.owner_user_id == user.id)
        ).scalar_one_or_none()
        if merchant is None:
            merchant = Merchant(
                business_name="Dev Provision Shop",
                business_type="retail",
                owner_user_id=user.id,
            )
            db.add(merchant)
            db.flush()

        store = db.execute(
            select(Store).where(Store.merchant_id == merchant.id, Store.is_default.is_(True))
        ).scalar_one_or_none()
        if store is None:
            store = Store(
                merchant_id=merchant.id,
                name="Main Store",
                location="Accra (dev)",
                timezone=DEFAULT_STORE_TIMEZONE,
                is_default=True,
            )
            db.add(store)
            db.flush()

        existing_item = db.scalars(select(Item).where(Item.store_id == store.id)).first()
        if existing_item is None:
            db.add(
                Item(
                    store_id=store.id,
                    name="Sample Product",
                    default_price=Decimal("10.00"),
                    low_stock_threshold=5,
                    is_active=True,
                )
            )

        db.commit()
        print("Seed OK: user", user.id, "store", store.id)
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()
