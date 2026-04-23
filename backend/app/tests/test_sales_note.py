"""Tests for the optional note field on sales (migration 004 + schema + service)."""

from __future__ import annotations

from collections.abc import Generator
from decimal import Decimal
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user, get_db
from app.main import app
from app.models.audit_log import AuditLog
from app.models.customer import Customer
from app.models.inventory import InventoryBalance, InventoryMovement
from app.models.item import Item
from app.models.merchant import Merchant
from app.models.sale import Sale, SaleItem
from app.models.store import Store
from app.models.sync_operation import SyncOperation
from app.models.user import User
from app.schemas.sale import SyncSaleCreateIn


def _make_stack() -> tuple[TestClient, sessionmaker[Session], UUID, UUID]:
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
        AuditLog.__table__,
    ):
        table.create(bind=engine)

    sl = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    user_id = uuid4()
    user = User(phone_number="233244000001")
    user.id = user_id
    user.is_active = True
    merchant = Merchant(owner_user_id=user_id, business_name="Test Shop", business_type="Retail")
    merchant.id = uuid4()
    store = Store(
        merchant_id=merchant.id,
        name="Test Store",
        location="Accra",
        timezone="Africa/Accra",
        is_default=True,
    )
    store.id = uuid4()
    store_id = store.id  # capture before session expires the object on commit
    with sl() as db:
        db.add(user)
        db.add(merchant)
        db.add(store)
        db.commit()

    current_user = User(phone_number="233244000001")
    current_user.id = user_id
    current_user.is_active = True

    def _override_db() -> Generator[Session, None, None]:
        with sl() as db:
            yield db

    app.dependency_overrides[get_db] = _override_db
    app.dependency_overrides[get_current_user] = lambda: current_user
    return TestClient(app), sl, user_id, store_id


def _seed_item(sl: sessionmaker[Session], *, store_id: UUID, qty: int = 10) -> UUID:
    with sl() as db:
        item = Item(
            store_id=store_id,
            name="Test Item",
            default_price=Decimal("10.00"),
            is_active=True,
        )
        item.id = uuid4()
        db.add(item)
        db.flush()
        db.add(InventoryBalance(item_id=item.id, quantity_on_hand=qty))
        db.commit()
        return item.id


def test_sale_synced_with_note_persists_note() -> None:
    client, sl, _, store_id = _make_stack()
    item_id = _seed_item(sl, store_id=store_id)
    try:
        resp = client.post(
            "/api/v1/sync/apply",
            json={
                "device_id": "test-device-note-001",
                "operations": [
                    {
                        "entity_type": "sale",
                        "action_type": "create",
                        "local_operation_id": "op-note-001-sale",
                        "payload": {
                            "sale_id": str(uuid4()),
                            "payment_method_label": "cash",
                            "note": "Customer wants receipt",
                            "lines": [
                                {"item_id": str(item_id), "quantity": 1, "unit_price": "10.00"}
                            ],
                        },
                    }
                ]
            },
        )
        assert resp.status_code == 200
        results = resp.json()["results"]
        assert results[0]["status"] in ("applied", "duplicate")

        sales_resp = client.get("/api/v1/sales")
        assert sales_resp.status_code == 200
        sale = sales_resp.json()[0]
        assert sale["note"] == "Customer wants receipt"
    finally:
        app.dependency_overrides.clear()


def test_sale_synced_without_note_has_null_note() -> None:
    client, sl, _, store_id = _make_stack()
    item_id = _seed_item(sl, store_id=store_id)
    try:
        resp = client.post(
            "/api/v1/sync/apply",
            json={
                "device_id": "test-device-nonote-001",
                "operations": [
                    {
                        "entity_type": "sale",
                        "action_type": "create",
                        "local_operation_id": "op-nonote-001-sale",
                        "payload": {
                            "sale_id": str(uuid4()),
                            "payment_method_label": "cash",
                            "lines": [
                                {"item_id": str(item_id), "quantity": 1, "unit_price": "10.00"}
                            ],
                        },
                    }
                ]
            },
        )
        assert resp.status_code == 200
        results = resp.json()["results"]
        assert results[0]["status"] in ("applied", "duplicate")

        sales_resp = client.get("/api/v1/sales")
        assert sales_resp.status_code == 200
        sale = sales_resp.json()[0]
        assert sale["note"] is None
    finally:
        app.dependency_overrides.clear()


def test_sync_sale_create_in_accepts_optional_note() -> None:
    item_id = uuid4()
    payload_with_note = SyncSaleCreateIn(
        payment_method_label="cash",
        note="Test note",
        lines=[{"item_id": item_id, "quantity": 2, "unit_price": "5.00"}],
    )
    assert payload_with_note.note == "Test note"

    payload_without_note = SyncSaleCreateIn(
        payment_method_label="cash",
        lines=[{"item_id": item_id, "quantity": 2, "unit_price": "5.00"}],
    )
    assert payload_without_note.note is None

    with pytest.raises(ValidationError):
        SyncSaleCreateIn(
            payment_method_label="cash",
            note="x" * 501,
            lines=[{"item_id": item_id, "quantity": 1, "unit_price": "5.00"}],
        )
