"""Sales API and sync tests."""

from __future__ import annotations

from collections.abc import Generator
from decimal import Decimal
from uuid import UUID, uuid4

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user, get_db
from app.main import app
from app.models.customer import Customer
from app.models.inventory import InventoryBalance, InventoryMovement
from app.models.item import Item
from app.models.merchant import Merchant
from app.models.sale import Sale, SaleItem
from app.models.store import Store
from app.models.sync_operation import SyncOperation
from app.models.user import User


def _build_sqlite_test_stack() -> tuple[TestClient, sessionmaker[Session], User, str]:
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    for table in (
        User.__table__,
        Merchant.__table__,
        Store.__table__,
        Customer.__table__,
        Item.__table__,
        InventoryBalance.__table__,
        InventoryMovement.__table__,
        Sale.__table__,
        SaleItem.__table__,
        SyncOperation.__table__,
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
    store_id = str(store.id)
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
    return TestClient(app), session_local, current_user, store_id


def _seed_item(session_local: sessionmaker[Session], *, store_id) -> str:
    with session_local() as db:
        item = Item(
            store_id=store_id,
            name="Bagged Rice",
            default_price=Decimal("35.00"),
            sku="RICE-001",
            category="Groceries",
            low_stock_threshold=2,
            is_active=True,
        )
        item.id = uuid4()
        db.add(item)
        db.flush()
        db.add(InventoryBalance(item_id=item.id, quantity_on_hand=12))
        db.commit()
        return str(item.id)


def test_create_sale_success_and_listing() -> None:
    client, session_local, _, store_id = _build_sqlite_test_stack()
    item_id = _seed_item(session_local, store_id=UUID(store_id))
    try:
        resp = client.post(
            "/api/v1/sales",
            json={
                "payment_method_label": "cash",
                "lines": [
                    {
                        "item_id": item_id,
                        "quantity": 3,
                        "unit_price": "35.00",
                    }
                ],
            },
        )
        assert resp.status_code == 201
        body = resp.json()
        assert Decimal(body["total_amount"]) == Decimal("105.00")
        assert body["payment_method_label"] == "cash"
        assert body["sale_status"] == "recorded"
        assert len(body["lines"]) == 1

        list_resp = client.get("/api/v1/sales")
        assert list_resp.status_code == 200
        sales = list_resp.json()
        assert len(sales) == 1
        assert Decimal(sales[0]["total_amount"]) == Decimal("105.00")
        assert sales[0]["sale_status"] == "recorded"

        with session_local() as db:
            balance = db.scalar(
                select(InventoryBalance).where(
                    InventoryBalance.item_id == UUID(body["lines"][0]["item_id"])
                )
            )
            assert balance is not None
            assert balance.quantity_on_hand == 9
            movement_count = db.scalar(select(func.count()).select_from(InventoryMovement))
            assert movement_count == 1
    finally:
        app.dependency_overrides.clear()


def test_update_sale_adjusts_inventory_and_total() -> None:
    client, session_local, _, store_id = _build_sqlite_test_stack()
    item_id = _seed_item(session_local, store_id=UUID(store_id))
    try:
        created = client.post(
            "/api/v1/sales",
            json={
                "payment_method_label": "cash",
                "lines": [
                    {
                        "item_id": item_id,
                        "quantity": 2,
                        "unit_price": "35.00",
                    }
                ],
            },
        )
        assert created.status_code == 201
        sale_id = created.json()["sale_id"]

        updated = client.patch(
            f"/api/v1/sales/{sale_id}",
            json={
                "payment_method_label": "mobile_money",
                "lines": [
                    {
                        "item_id": item_id,
                        "quantity": 4,
                    }
                ],
            },
        )
        assert updated.status_code == 200
        body = updated.json()
        assert body["payment_method_label"] == "mobile_money"
        assert Decimal(body["total_amount"]) == Decimal("140.00")
        assert body["sale_status"] == "recorded"
        assert body["lines"][0]["quantity"] == 4

        with session_local() as db:
            balance = db.scalar(
                select(InventoryBalance).where(InventoryBalance.item_id == UUID(item_id))
            )
            assert balance is not None
            assert balance.quantity_on_hand == 8
    finally:
        app.dependency_overrides.clear()


def test_void_sale_restores_inventory_and_hides_from_default_list() -> None:
    client, session_local, _, store_id = _build_sqlite_test_stack()
    item_id = _seed_item(session_local, store_id=UUID(store_id))
    try:
        created = client.post(
            "/api/v1/sales",
            json={
                "payment_method_label": "cash",
                "lines": [
                    {
                        "item_id": item_id,
                        "quantity": 3,
                        "unit_price": "35.00",
                    }
                ],
            },
        )
        assert created.status_code == 201
        sale_id = created.json()["sale_id"]

        voided = client.post(
            f"/api/v1/sales/{sale_id}/void",
            json={"reason": "incorrect quantity"},
        )
        assert voided.status_code == 200
        voided_body = voided.json()
        assert voided_body["sale_status"] == "voided"
        assert voided_body["void_reason"] == "incorrect quantity"

        default_list = client.get("/api/v1/sales")
        assert default_list.status_code == 200
        assert default_list.json() == []

        full_list = client.get("/api/v1/sales", params={"include_voided": True})
        assert full_list.status_code == 200
        sales = full_list.json()
        assert len(sales) == 1
        assert sales[0]["sale_status"] == "voided"

        with session_local() as db:
            balance = db.scalar(
                select(InventoryBalance).where(InventoryBalance.item_id == UUID(item_id))
            )
            assert balance is not None
            assert balance.quantity_on_hand == 12
    finally:
        app.dependency_overrides.clear()


def test_create_sale_rejects_insufficient_stock() -> None:
    client, session_local, _, store_id = _build_sqlite_test_stack()
    item_id = _seed_item(session_local, store_id=UUID(store_id))
    try:
        resp = client.post(
            "/api/v1/sales",
            json={
                "payment_method_label": "cash",
                "lines": [
                    {
                        "item_id": item_id,
                        "quantity": 999,
                        "unit_price": "35.00",
                    }
                ],
            },
        )
        assert resp.status_code == 422
        assert "Insufficient stock" in resp.json()["detail"]
    finally:
        app.dependency_overrides.clear()


def test_sync_apply_sale_create_is_idempotent() -> None:
    client, session_local, _, store_id = _build_sqlite_test_stack()
    item_id = _seed_item(session_local, store_id=UUID(store_id))
    sale_id = str(uuid4())
    payload = {
        "device_id": "device-accra-sale-01",
        "operations": [
            {
                "local_operation_id": "sale-create-op-001",
                "entity_type": "sale",
                "action_type": "create",
                "payload": {
                    "sale_id": sale_id,
                    "payment_method_label": "cash",
                    "lines": [
                        {
                            "item_id": item_id,
                            "quantity": 2,
                            "unit_price": "35.00",
                        }
                    ],
                },
            }
        ],
    }
    try:
        first = client.post("/api/v1/sync/apply", json=payload)
        assert first.status_code == 200
        assert first.json()["results"][0]["status"] == "applied"
        assert first.json()["results"][0]["entity_id"] == sale_id

        second = client.post("/api/v1/sync/apply", json=payload)
        assert second.status_code == 200
        assert second.json()["results"][0]["status"] == "duplicate"

        with session_local() as db:
            sales_count = db.scalar(select(func.count()).select_from(Sale))
            assert sales_count == 1
            balance = db.scalar(
                select(InventoryBalance).where(InventoryBalance.item_id == UUID(item_id))
            )
            assert balance is not None
            assert balance.quantity_on_hand == 10
    finally:
        app.dependency_overrides.clear()


def test_sync_apply_sale_returns_conflict_when_stock_is_stale() -> None:
    client, session_local, _, store_id = _build_sqlite_test_stack()
    item_id = _seed_item(session_local, store_id=UUID(store_id))
    payload = {
        "device_id": "device-accra-sale-02",
        "operations": [
            {
                "local_operation_id": "sale-create-op-conflict",
                "entity_type": "sale",
                "action_type": "create",
                "payload": {
                    "sale_id": str(uuid4()),
                    "payment_method_label": "cash",
                    "lines": [
                        {
                            "item_id": item_id,
                            "quantity": 50,
                            "unit_price": "35.00",
                        }
                    ],
                },
            }
        ],
    }
    try:
        resp = client.post("/api/v1/sync/apply", json=payload)
        assert resp.status_code == 200
        result = resp.json()["results"][0]
        assert result["status"] == "conflict"
        assert "Insufficient stock" in result["detail"]

        with session_local() as db:
            sales_count = db.scalar(select(func.count()).select_from(Sale))
            sync_count = db.scalar(select(func.count()).select_from(SyncOperation))
            balance = db.scalar(
                select(InventoryBalance).where(InventoryBalance.item_id == UUID(item_id))
            )
            assert sales_count == 0
            assert sync_count == 0
            assert balance is not None
            assert balance.quantity_on_hand == 12
    finally:
        app.dependency_overrides.clear()


def test_sync_apply_sale_update_and_void_apply_inventory_consistently() -> None:
    client, session_local, _, store_id = _build_sqlite_test_stack()
    item_id = _seed_item(session_local, store_id=UUID(store_id))
    sale_id = str(uuid4())
    create_payload = {
        "device_id": "device-accra-sale-03",
        "operations": [
            {
                "local_operation_id": "sale-create-op-003",
                "entity_type": "sale",
                "action_type": "create",
                "payload": {
                    "sale_id": sale_id,
                    "payment_method_label": "cash",
                    "lines": [
                        {
                            "item_id": item_id,
                            "quantity": 2,
                            "unit_price": "35.00",
                        }
                    ],
                },
            }
        ],
    }
    update_payload = {
        "device_id": "device-accra-sale-03",
        "operations": [
            {
                "local_operation_id": "sale-update-op-003",
                "entity_type": "sale",
                "action_type": "update",
                "payload": {
                    "sale_id": sale_id,
                    "payment_method_label": "mobile_money",
                    "lines": [
                        {
                            "item_id": item_id,
                            "quantity": 4,
                        }
                    ],
                },
            }
        ],
    }
    void_payload = {
        "device_id": "device-accra-sale-03",
        "operations": [
            {
                "local_operation_id": "sale-void-op-003",
                "entity_type": "sale",
                "action_type": "void",
                "payload": {
                    "sale_id": sale_id,
                    "reason": "customer cancellation",
                },
            }
        ],
    }
    try:
        create_result = client.post("/api/v1/sync/apply", json=create_payload)
        assert create_result.status_code == 200
        assert create_result.json()["results"][0]["status"] == "applied"

        update_result = client.post("/api/v1/sync/apply", json=update_payload)
        assert update_result.status_code == 200
        assert update_result.json()["results"][0]["status"] == "applied"

        void_result = client.post("/api/v1/sync/apply", json=void_payload)
        assert void_result.status_code == 200
        assert void_result.json()["results"][0]["status"] == "applied"

        with session_local() as db:
            sale = db.scalar(select(Sale).where(Sale.id == UUID(sale_id)))
            assert sale is not None
            assert sale.sale_status == "voided"
            assert sale.payment_method_label == "mobile_money"
            balance = db.scalar(
                select(InventoryBalance).where(InventoryBalance.item_id == UUID(item_id))
            )
            assert balance is not None
            assert balance.quantity_on_hand == 12
            assert db.scalar(select(func.count()).select_from(SyncOperation)) == 3
    finally:
        app.dependency_overrides.clear()
