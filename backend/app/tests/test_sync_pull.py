"""Incremental /sync/pull endpoint tests."""

from __future__ import annotations

from collections.abc import Generator
from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user, get_db
from app.main import app
from app.models.audit_log import AuditLog
from app.models.customer import Customer
from app.models.inventory import InventoryBalance, InventoryMovement
from app.models.item import Item, ItemVariant
from app.models.merchant import Merchant
from app.models.receivable import Receivable, ReceivablePayment
from app.models.store import Store
from app.models.sync_apply_throttle import SyncApplyThrottle
from app.models.sync_operation import SyncOperation
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
        ItemVariant.__table__,
        InventoryBalance.__table__,
        InventoryMovement.__table__,
        Customer.__table__,
        Receivable.__table__,
        ReceivablePayment.__table__,
        SyncOperation.__table__,
        SyncApplyThrottle.__table__,
        AuditLog.__table__,
    ):
        table.create(bind=engine)

    with engine.begin() as conn:
        conn.exec_driver_sql(
            """
CREATE TABLE IF NOT EXISTS receivable_invoice_counters (
  store_id TEXT NOT NULL,
  year INTEGER NOT NULL,
  next_number INTEGER NOT NULL,
  PRIMARY KEY (store_id, year)
)
"""
        )

    session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    user_phone = "233244123456"
    user_id = uuid4()
    user = User(phone_number=user_phone)
    user.id = user_id
    user.is_active = True
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
    with session_local() as db:
        db.add(user)
        db.add(merchant)
        db.add(store)
        db.commit()

    current_user = User(phone_number=user_phone)
    current_user.id = user_id
    current_user.is_active = True

    def _override_get_db() -> Generator[Session, None, None]:
        with session_local() as db:
            yield db

    def _override_get_current_user() -> User:
        return current_user

    app.dependency_overrides[get_db] = _override_get_db
    app.dependency_overrides[get_current_user] = _override_get_current_user
    return TestClient(app), session_local, current_user


def test_sync_pull_full_refresh_when_since_missing() -> None:
    client, _, _ = _build_sqlite_test_stack()
    try:
        create_item = client.post(
            "/api/v1/items",
            json={"name": "Sugar", "default_price": "12.00"},
        )
        assert create_item.status_code == 201

        pull = client.get("/api/v1/sync/pull")
        assert pull.status_code == 200
        body = pull.json()
        assert body["full_refresh"] is True
        assert len(body["inventory"]) == 1
        assert body["cursor"]
    finally:
        app.dependency_overrides.clear()


def test_sync_pull_incremental_returns_stock_change_only() -> None:
    client, session_local, _ = _build_sqlite_test_stack()
    try:
        create_item = client.post(
            "/api/v1/items",
            json={"name": "Rice", "default_price": "40.00"},
        )
        item_id = create_item.json()["item_id"]

        first_pull = client.get("/api/v1/sync/pull")
        cursor = first_pull.json()["cursor"]

        stock_in = client.post(
            f"/api/v1/items/{item_id}/stock-in",
            json={"quantity": 5, "reason": "Delivery"},
        )
        assert stock_in.status_code == 200

        incremental = client.get(
            "/api/v1/sync/pull",
            params={"since": cursor, "include": "inventory"},
        )
        assert incremental.status_code == 200
        body = incremental.json()
        assert body["full_refresh"] is False
        assert len(body["inventory"]) == 1
        assert body["inventory"][0]["quantity_on_hand"] == 5
        assert body["customers"] == []
        assert body["receivables"] == []
    finally:
        app.dependency_overrides.clear()


def test_sync_pull_incremental_returns_receivable_repayment() -> None:
    client, session_local, _ = _build_sqlite_test_stack()
    try:
        customer_resp = client.post(
            "/api/v1/receivables/customers",
            json={"name": "Kofi Mensah", "phone_number": "233200000001"},
        )
        assert customer_resp.status_code == 201
        customer_id = customer_resp.json()["customer_id"]

        receivable_resp = client.post(
            "/api/v1/receivables",
            json={
                "customer_id": customer_id,
                "original_amount": "100.00",
            },
        )
        assert receivable_resp.status_code == 201
        receivable_id = receivable_resp.json()["receivable_id"]

        first_pull = client.get("/api/v1/sync/pull", params={"include": "debts"})
        cursor = first_pull.json()["cursor"]

        repay = client.post(
            f"/api/v1/receivables/{receivable_id}/repayments",
            json={"amount": "40.00", "payment_method_label": "cash"},
        )
        assert repay.status_code == 200

        incremental = client.get(
            "/api/v1/sync/pull",
            params={"since": cursor, "include": "debts"},
        )
        assert incremental.status_code == 200
        body = incremental.json()
        assert body["full_refresh"] is False
        assert len(body["receivables"]) == 1
        assert body["receivables"][0]["outstanding_amount"] == "60.00"
        assert len(body["customers"]) == 1
    finally:
        app.dependency_overrides.clear()
