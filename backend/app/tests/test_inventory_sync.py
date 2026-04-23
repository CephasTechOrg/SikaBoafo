"""Inventory API and sync apply tests."""

from __future__ import annotations

from collections.abc import Generator
from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user, get_db
from app.main import app
from app.models.audit_log import AuditLog
from app.models.inventory import InventoryBalance, InventoryMovement
from app.models.item import Item
from app.models.merchant import Merchant
from app.models.store import Store
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
        InventoryBalance.__table__,
        InventoryMovement.__table__,
        SyncOperation.__table__,
        AuditLog.__table__,
    ):
        table.create(bind=engine)

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


def test_inventory_item_create_list_stock_and_adjust() -> None:
    client, _, _ = _build_sqlite_test_stack()
    try:
        create_resp = client.post(
            "/api/v1/items",
            json={
                "name": "Milk Tin",
                "default_price": "18.50",
                "sku": "MILK-001",
                "category": "Dairy",
                "low_stock_threshold": 4,
            },
        )
        assert create_resp.status_code == 201
        created = create_resp.json()
        assert created["name"] == "Milk Tin"
        assert created["quantity_on_hand"] == 0
        item_id = created["item_id"]

        list_resp = client.get("/api/v1/items")
        assert list_resp.status_code == 200
        items = list_resp.json()
        assert len(items) == 1
        assert items[0]["item_id"] == item_id

        stock_in_resp = client.post(
            f"/api/v1/items/{item_id}/stock-in",
            json={"quantity": 12, "reason": "Opening stock"},
        )
        assert stock_in_resp.status_code == 200
        stock_in_body = stock_in_resp.json()
        assert stock_in_body["movement_type"] == "stock_in"
        assert stock_in_body["item"]["quantity_on_hand"] == 12

        adjust_resp = client.post(
            f"/api/v1/items/{item_id}/adjust",
            json={"quantity_delta": -3, "reason": "Physical count"},
        )
        assert adjust_resp.status_code == 200
        adjust_body = adjust_resp.json()
        assert adjust_body["movement_type"] == "adjustment"
        assert adjust_body["item"]["quantity_on_hand"] == 9

        negative_resp = client.post(
            f"/api/v1/items/{item_id}/adjust",
            json={"quantity_delta": -99, "reason": "Invalid test"},
        )
        assert negative_resp.status_code == 422
    finally:
        app.dependency_overrides.clear()


def test_inventory_item_archive_requires_zero_stock_and_can_restore() -> None:
    client, _, _ = _build_sqlite_test_stack()
    try:
        create_resp = client.post(
            "/api/v1/items",
            json={
                "name": "Cooking Oil",
                "default_price": "25.00",
            },
        )
        assert create_resp.status_code == 201
        item_id = create_resp.json()["item_id"]

        stock_in_resp = client.post(
            f"/api/v1/items/{item_id}/stock-in",
            json={"quantity": 5, "reason": "Opening stock"},
        )
        assert stock_in_resp.status_code == 200

        archive_resp = client.patch(
            f"/api/v1/items/{item_id}",
            json={"is_active": False},
        )
        assert archive_resp.status_code == 422
        assert archive_resp.json()["detail"] == "Adjust stock to 0 before archiving this item."

        adjust_resp = client.post(
            f"/api/v1/items/{item_id}/adjust",
            json={"quantity_delta": -5, "reason": "Stock cleared"},
        )
        assert adjust_resp.status_code == 200
        assert adjust_resp.json()["item"]["quantity_on_hand"] == 0

        archive_resp = client.patch(
            f"/api/v1/items/{item_id}",
            json={"is_active": False},
        )
        assert archive_resp.status_code == 200
        assert archive_resp.json()["is_active"] is False

        restore_resp = client.patch(
            f"/api/v1/items/{item_id}",
            json={"is_active": True},
        )
        assert restore_resp.status_code == 200
        assert restore_resp.json()["is_active"] is True
    finally:
        app.dependency_overrides.clear()


def test_sync_apply_is_idempotent_for_inventory_operations() -> None:
    client, session_local, _ = _build_sqlite_test_stack()
    item_id = str(uuid4())
    payload = {
        "device_id": "device-accra-001",
        "operations": [
            {
                "local_operation_id": "op-create-001",
                "entity_type": "item",
                "action_type": "create",
                "payload": {
                    "item_id": item_id,
                    "name": "Bagged Rice",
                    "default_price": "35.00",
                },
            },
            {
                "local_operation_id": "op-stock-in-002",
                "entity_type": "inventory",
                "action_type": "stock_in",
                "payload": {
                    "item_id": item_id,
                    "quantity": 20,
                    "reason": "New supply",
                },
            },
            {
                "local_operation_id": "op-adjust-003",
                "entity_type": "inventory",
                "action_type": "adjust",
                "payload": {
                    "item_id": item_id,
                    "quantity_delta": -2,
                    "reason": "Count correction",
                },
            },
        ],
    }
    try:
        first_apply = client.post("/api/v1/sync/apply", json=payload)
        assert first_apply.status_code == 200
        first_results = first_apply.json()["results"]
        assert [r["status"] for r in first_results] == ["applied", "applied", "applied"]
        assert first_results[0]["entity_id"] == item_id

        second_apply = client.post("/api/v1/sync/apply", json=payload)
        assert second_apply.status_code == 200
        second_results = second_apply.json()["results"]
        assert [r["status"] for r in second_results] == ["duplicate", "duplicate", "duplicate"]

        items_resp = client.get("/api/v1/items")
        assert items_resp.status_code == 200
        items = items_resp.json()
        assert len(items) == 1
        assert items[0]["item_id"] == item_id
        assert items[0]["quantity_on_hand"] == 18

        with session_local() as db:
            sync_rows = db.scalar(select(func.count()).select_from(SyncOperation))
            assert sync_rows == 3
    finally:
        app.dependency_overrides.clear()


def test_sync_apply_rejects_unknown_operation() -> None:
    client, session_local, _ = _build_sqlite_test_stack()
    try:
        resp = client.post(
            "/api/v1/sync/apply",
            json={
                "device_id": "device-accra-001",
                "operations": [
                    {
                        "local_operation_id": "bad-op-001",
                        "entity_type": "payments",
                        "action_type": "capture",
                        "payload": {"foo": "bar"},
                    }
                ],
            },
        )
        assert resp.status_code == 200
        result = resp.json()["results"][0]
        assert result["status"] == "rejected"
        assert result["entity_id"] is None

        with session_local() as db:
            sync_rows = db.scalar(select(func.count()).select_from(SyncOperation))
            assert sync_rows == 0
    finally:
        app.dependency_overrides.clear()
