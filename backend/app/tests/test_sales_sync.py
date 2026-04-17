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
        assert len(body["lines"]) == 1

        list_resp = client.get("/api/v1/sales")
        assert list_resp.status_code == 200
        sales = list_resp.json()
        assert len(sales) == 1
        assert Decimal(sales[0]["total_amount"]) == Decimal("105.00")

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
