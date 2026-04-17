"""Expenses API and sync tests."""

from __future__ import annotations

from collections.abc import Generator
from decimal import Decimal
from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user, get_db
from app.main import app
from app.models.expense import Expense
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
        Expense.__table__,
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


def test_create_expense_and_list_history() -> None:
    client, _, _ = _build_sqlite_test_stack()
    try:
        create_resp = client.post(
            "/api/v1/expenses",
            json={
                "category": "utilities",
                "amount": "150.00",
                "note": "Electricity bill",
            },
        )
        assert create_resp.status_code == 201
        created = create_resp.json()
        assert created["category"] == "utilities"
        assert Decimal(created["amount"]) == Decimal("150.00")
        assert created["note"] == "Electricity bill"

        list_resp = client.get("/api/v1/expenses")
        assert list_resp.status_code == 200
        rows = list_resp.json()
        assert len(rows) == 1
        assert rows[0]["expense_id"] == created["expense_id"]
    finally:
        app.dependency_overrides.clear()


def test_sync_apply_expense_create_is_idempotent() -> None:
    client, session_local, _ = _build_sqlite_test_stack()
    expense_id = str(uuid4())
    payload = {
        "device_id": "device-accra-expense-001",
        "operations": [
            {
                "local_operation_id": "expense-create-op-001",
                "entity_type": "expense",
                "action_type": "create",
                "payload": {
                    "expense_id": expense_id,
                    "category": "transport",
                    "amount": "35.50",
                    "note": "Delivery to Madina",
                },
            }
        ],
    }
    try:
        first = client.post("/api/v1/sync/apply", json=payload)
        assert first.status_code == 200
        assert first.json()["results"][0]["status"] == "applied"
        assert first.json()["results"][0]["entity_id"] == expense_id

        second = client.post("/api/v1/sync/apply", json=payload)
        assert second.status_code == 200
        assert second.json()["results"][0]["status"] == "duplicate"

        with session_local() as db:
            count = db.scalar(select(func.count()).select_from(Expense))
            assert count == 1
            sync_count = db.scalar(select(func.count()).select_from(SyncOperation))
            assert sync_count == 1
    finally:
        app.dependency_overrides.clear()
