"""Payment settings API tests (M4 Step 1)."""

from __future__ import annotations

from collections.abc import Generator
from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user, get_db
from app.core.constants import USER_ROLE_MERCHANT_OWNER
from app.main import app
from app.models.item import Item
from app.models.merchant import Merchant
from app.models.payment_provider_connection import PaymentProviderConnection
from app.models.store import Store
from app.models.user import User


def _build_sqlite_test_stack() -> tuple[TestClient, sessionmaker[Session], User]:
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    for table in (
        User.__table__,
        Merchant.__table__,
        Store.__table__,
        Item.__table__,
        PaymentProviderConnection.__table__,
    ):
        table.create(bind=engine)

    session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    user_id = uuid4()
    user_phone = "233244123456"
    user = User(phone_number=user_phone)
    user.id = user_id
    user.is_active = True
    merchant = Merchant(
        owner_user_id=user.id,
        business_name="Ama Ventures",
        business_type="Provision Shop",
    )
    merchant.id = uuid4()
    with session_local() as db:
        db.add(user)
        db.add(merchant)
        db.commit()

    current_user = User(phone_number=user_phone)
    current_user.id = user_id
    current_user.is_active = True
    current_user.role = USER_ROLE_MERCHANT_OWNER

    def _override_get_db() -> Generator[Session, None, None]:
        with session_local() as db:
            yield db

    def _override_get_current_user() -> User:
        return current_user

    app.dependency_overrides[get_db] = _override_get_db
    app.dependency_overrides[get_current_user] = _override_get_current_user
    return TestClient(app), session_local, current_user


def test_get_paystack_connection_defaults_to_disconnected() -> None:
    client, _, _ = _build_sqlite_test_stack()
    try:
        response = client.get("/api/v1/payments/paystack/connection")
        assert response.status_code == 200
        body = response.json()
        assert body["provider"] == "paystack"
        assert body["is_connected"] is False
        assert body["mode"] == "test"
        assert body["public_key_masked"] is None
    finally:
        app.dependency_overrides.clear()


def test_upsert_paystack_connection_and_fetch() -> None:
    client, _, _ = _build_sqlite_test_stack()
    try:
        upsert = client.put(
            "/api/v1/payments/paystack/connection",
            json={
                "public_key": "pk_test_abcdefgh12345678",
                "mode": "test",
                "account_label": "Main Paystack Account",
            },
        )
        assert upsert.status_code == 200
        upsert_body = upsert.json()
        assert upsert_body["is_connected"] is True
        assert upsert_body["mode"] == "test"
        assert upsert_body["account_label"] == "Main Paystack Account"
        assert upsert_body["public_key_masked"].startswith("pk_tes")
        assert upsert_body["public_key_masked"].endswith("5678")

        fetched = client.get("/api/v1/payments/paystack/connection")
        assert fetched.status_code == 200
        fetched_body = fetched.json()
        assert fetched_body["is_connected"] is True
        assert fetched_body["account_label"] == "Main Paystack Account"
    finally:
        app.dependency_overrides.clear()


def test_disconnect_paystack_connection_is_idempotent() -> None:
    client, _, _ = _build_sqlite_test_stack()
    try:
        first_disconnect = client.delete("/api/v1/payments/paystack/connection")
        assert first_disconnect.status_code == 200
        assert first_disconnect.json()["is_connected"] is False

        client.put(
            "/api/v1/payments/paystack/connection",
            json={
                "public_key": "pk_test_abcdefgh12345678",
                "mode": "live",
                "account_label": "Live Account",
            },
        )
        second_disconnect = client.delete("/api/v1/payments/paystack/connection")
        assert second_disconnect.status_code == 200
        assert second_disconnect.json()["is_connected"] is False
    finally:
        app.dependency_overrides.clear()
