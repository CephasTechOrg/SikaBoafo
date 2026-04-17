"""Sync idempotency + report consistency integration tests."""

from __future__ import annotations

from collections.abc import Generator
from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID, uuid4

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user, get_db
from app.main import app
from app.models.customer import Customer
from app.models.expense import Expense
from app.models.inventory import InventoryBalance, InventoryMovement
from app.models.item import Item
from app.models.merchant import Merchant
from app.models.receivable import Receivable, ReceivablePayment
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
        Item.__table__,
        InventoryBalance.__table__,
        InventoryMovement.__table__,
        Sale.__table__,
        SaleItem.__table__,
        Expense.__table__,
        Customer.__table__,
        Receivable.__table__,
        ReceivablePayment.__table__,
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
        timezone="UTC",
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


def _seed_item(session_local: sessionmaker[Session], *, store_id: str) -> str:
    with session_local() as db:
        item = Item(
            store_id=UUID(store_id),
            name="Bagged Rice",
            default_price=Decimal("10.00"),
            sku="RICE-001",
            category="Groceries",
            low_stock_threshold=2,
            is_active=True,
        )
        item.id = uuid4()
        db.add(item)
        db.flush()
        db.add(InventoryBalance(item_id=item.id, quantity_on_hand=10))
        db.commit()
        return str(item.id)


def test_sync_replay_does_not_inflate_report_totals_or_activity() -> None:
    client, session_local, _, store_id = _build_sqlite_test_stack()
    item_id = _seed_item(session_local, store_id=store_id)

    sale_id = str(uuid4())
    expense_id = str(uuid4())
    payload = {
        "device_id": "device-accra-consistency-01",
        "operations": [
            {
                "local_operation_id": "sale-create-op-consistency-001",
                "entity_type": "sale",
                "action_type": "create",
                "payload": {
                    "sale_id": sale_id,
                    "payment_method_label": "cash",
                    "lines": [
                        {
                            "item_id": item_id,
                            "quantity": 2,
                            "unit_price": "10.00",
                        }
                    ],
                },
            },
            {
                "local_operation_id": "expense-create-op-consistency-002",
                "entity_type": "expense",
                "action_type": "create",
                "payload": {
                    "expense_id": expense_id,
                    "category": "transport",
                    "amount": "5.00",
                    "note": "Delivery",
                },
            },
        ],
    }

    try:
        first = client.post("/api/v1/sync/apply", json=payload)
        assert first.status_code == 200
        assert [row["status"] for row in first.json()["results"]] == ["applied", "applied"]

        replay = client.post("/api/v1/sync/apply", json=payload)
        assert replay.status_code == 200
        assert [row["status"] for row in replay.json()["results"]] == [
            "duplicate",
            "duplicate",
        ]

        with session_local() as db:
            assert db.scalar(select(func.count()).select_from(Sale)) == 1
            assert db.scalar(select(func.count()).select_from(Expense)) == 1
            assert db.scalar(select(func.count()).select_from(SyncOperation)) == 2
            balance = db.scalar(
                select(InventoryBalance).where(InventoryBalance.item_id == UUID(item_id))
            )
            assert balance is not None
            assert balance.quantity_on_hand == 8

        summary = client.get(
            "/api/v1/reports/summary",
            params={"as_of_utc": datetime.now(tz=UTC).isoformat()},
        )
        assert summary.status_code == 200
        summary_body = summary.json()
        assert Decimal(str(summary_body["today_sales_total"])) == Decimal("20.00")
        assert Decimal(str(summary_body["today_expenses_total"])) == Decimal("5.00")
        assert Decimal(str(summary_body["today_estimated_profit"])) == Decimal("15.00")

        activity = client.get("/api/v1/reports/recent-activity", params={"limit": 10})
        assert activity.status_code == 200
        activity_body = activity.json()
        assert len(activity_body) == 2
        assert {row["activity_type"] for row in activity_body} == {"sale", "expense"}
    finally:
        app.dependency_overrides.clear()


def test_voided_sale_is_excluded_from_report_totals_and_activity() -> None:
    client, session_local, _, store_id = _build_sqlite_test_stack()
    item_id = _seed_item(session_local, store_id=store_id)
    sale_id = str(uuid4())
    create_payload = {
        "device_id": "device-accra-consistency-void-01",
        "operations": [
            {
                "local_operation_id": "sale-create-op-void-001",
                "entity_type": "sale",
                "action_type": "create",
                "payload": {
                    "sale_id": sale_id,
                    "payment_method_label": "cash",
                    "lines": [
                        {
                            "item_id": item_id,
                            "quantity": 2,
                            "unit_price": "10.00",
                        }
                    ],
                },
            }
        ],
    }
    void_payload = {
        "device_id": "device-accra-consistency-void-01",
        "operations": [
            {
                "local_operation_id": "sale-void-op-void-002",
                "entity_type": "sale",
                "action_type": "void",
                "payload": {
                    "sale_id": sale_id,
                    "reason": "correction",
                },
            }
        ],
    }

    try:
        create_resp = client.post("/api/v1/sync/apply", json=create_payload)
        assert create_resp.status_code == 200
        assert create_resp.json()["results"][0]["status"] == "applied"

        void_resp = client.post("/api/v1/sync/apply", json=void_payload)
        assert void_resp.status_code == 200
        assert void_resp.json()["results"][0]["status"] == "applied"

        summary = client.get(
            "/api/v1/reports/summary",
            params={"as_of_utc": datetime.now(tz=UTC).isoformat()},
        )
        assert summary.status_code == 200
        body = summary.json()
        assert Decimal(str(body["today_sales_total"])) == Decimal("0.00")
        assert Decimal(str(body["today_estimated_profit"])) == Decimal("0.00")

        activity = client.get("/api/v1/reports/recent-activity", params={"limit": 8})
        assert activity.status_code == 200
        assert activity.json() == []
    finally:
        app.dependency_overrides.clear()
