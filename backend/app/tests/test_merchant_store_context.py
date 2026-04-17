"""Merchant/store profile endpoint tests."""

from __future__ import annotations

from collections.abc import Generator
from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy.sql import Select

from app.api.deps import get_current_user, get_db
from app.main import app
from app.models.merchant import Merchant
from app.models.store import Store
from app.models.user import User


class _FakeDb:
    def __init__(self) -> None:
        self.merchant: Merchant | None = None
        self.store: Store | None = None

    def scalar(self, statement: object):
        if not isinstance(statement, Select):
            return None
        table = statement.column_descriptions[0]["entity"].__tablename__
        if table == "merchants":
            return self.merchant
        if table == "stores":
            return self.store
        return None

    def commit(self) -> None:
        return None

    def refresh(self, entity) -> None:
        return None


def _seed(fake_db: _FakeDb, user: User) -> None:
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
    fake_db.merchant = merchant
    fake_db.store = store


def test_get_context_and_update_paths() -> None:
    fake_db = _FakeDb()
    user = User(phone_number="233244123456")
    user.id = uuid4()
    user.is_active = True
    _seed(fake_db, user)

    def _override_get_db() -> Generator[_FakeDb, None, None]:
        yield fake_db

    def _override_get_current_user() -> User:
        return user

    app.dependency_overrides[get_db] = _override_get_db
    app.dependency_overrides[get_current_user] = _override_get_current_user
    client = TestClient(app)
    try:
        context_resp = client.get("/api/v1/merchants/me/context")
        assert context_resp.status_code == 200
        context = context_resp.json()
        assert context["merchant"]["business_name"] == "Ama Ventures"
        assert context["default_store"]["name"] == "Main Store"

        merchant_resp = client.patch(
            "/api/v1/merchants/me",
            json={"business_name": "Ama Retail", "business_type": "General"},
        )
        assert merchant_resp.status_code == 200
        assert merchant_resp.json()["business_name"] == "Ama Retail"

        store_resp = client.patch(
            "/api/v1/stores/default",
            json={
                "name": "Legon Branch",
                "location": "Legon",
                "timezone": "Africa/Accra",
            },
        )
        assert store_resp.status_code == 200
        assert store_resp.json()["name"] == "Legon Branch"
    finally:
        app.dependency_overrides.clear()
