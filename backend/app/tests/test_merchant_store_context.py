"""Store-context resolution tests for owners and staff users."""

from __future__ import annotations

from uuid import uuid4

from sqlalchemy.sql import Select

from app.core.constants import USER_ROLE_CASHIER
from app.models.merchant import Merchant
from app.models.store import Store
from app.models.user import User
from app.services.store_context import get_merchant_and_store


class _FakeDb:
    def __init__(self) -> None:
        self.users_by_id: dict[object, User] = {}
        self.merchants_by_owner: dict[object, Merchant] = {}
        self.merchants_by_id: dict[object, Merchant] = {}
        self.stores_by_merchant: dict[object, Store] = {}

    def scalar(self, statement: object):
        if not isinstance(statement, Select):
            return None
        params = statement.compile().params
        table = statement.column_descriptions[0]["entity"].__tablename__
        if table == "users":
            user_id = next((value for key, value in params.items() if key.startswith("id_")), None)
            return self.users_by_id.get(user_id)
        if table == "merchants":
            owner_user_id = next(
                (value for key, value in params.items() if key.startswith("owner_user_id_")),
                None,
            )
            if owner_user_id is not None:
                return self.merchants_by_owner.get(owner_user_id)
            merchant_id = next((value for key, value in params.items() if key.startswith("id_")), None)
            return self.merchants_by_id.get(merchant_id)
        if table == "stores":
            merchant_id = next(
                (value for key, value in params.items() if key.startswith("merchant_id_")),
                None,
            )
            return self.stores_by_merchant.get(merchant_id)
        return None


def test_owner_resolves_owner_merchant_and_default_store() -> None:
    db = _FakeDb()
    user = User(phone_number="233244123456")
    user.id = uuid4()
    user.is_active = True
    db.users_by_id[user.id] = user

    merchant = Merchant(
        owner_user_id=user.id,
        business_name="Ama Ventures",
        business_type="Provision Shop",
    )
    merchant.id = uuid4()
    store = Store(
        merchant_id=merchant.id,
        name="Main Store",
        location="Madina",
        timezone="Africa/Accra",
        is_default=True,
    )
    store.id = uuid4()
    db.merchants_by_owner[user.id] = merchant
    db.merchants_by_id[merchant.id] = merchant
    db.stores_by_merchant[merchant.id] = store

    resolved_merchant, resolved_store = get_merchant_and_store(user_id=user.id, db=db)

    assert resolved_merchant.id == merchant.id
    assert resolved_store.id == store.id


def test_staff_prefers_assigned_merchant_over_legacy_owner_merchant() -> None:
    db = _FakeDb()
    user = User(phone_number="233244123456", role=USER_ROLE_CASHIER)
    user.id = uuid4()
    user.is_active = True
    user.merchant_id = uuid4()
    db.users_by_id[user.id] = user

    legacy_owner_merchant = Merchant(
        owner_user_id=user.id,
        business_name="Legacy Owner Merchant",
        business_type="Retail",
    )
    legacy_owner_merchant.id = uuid4()
    assigned_merchant = Merchant(
        owner_user_id=uuid4(),
        business_name="Assigned Merchant",
        business_type="Retail",
    )
    assigned_merchant.id = user.merchant_id

    assigned_store = Store(
        merchant_id=assigned_merchant.id,
        name="Assigned Store",
        location="Madina",
        timezone="Africa/Accra",
        is_default=True,
    )
    assigned_store.id = uuid4()

    db.merchants_by_owner[user.id] = legacy_owner_merchant
    db.merchants_by_id[legacy_owner_merchant.id] = legacy_owner_merchant
    db.merchants_by_id[assigned_merchant.id] = assigned_merchant
    db.stores_by_merchant[assigned_merchant.id] = assigned_store

    resolved_merchant, resolved_store = get_merchant_and_store(user_id=user.id, db=db)

    assert resolved_merchant.id == assigned_merchant.id
    assert resolved_merchant.business_name == "Assigned Merchant"
    assert resolved_store.id == assigned_store.id
