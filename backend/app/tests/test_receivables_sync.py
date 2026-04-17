"""Receivables/debt API and sync tests."""

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
from app.models.item import Item
from app.models.merchant import Merchant
from app.models.receivable import Receivable, ReceivablePayment
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


def test_create_customer_create_debt_and_list() -> None:
    client, _, _ = _build_sqlite_test_stack()
    try:
        customer_resp = client.post(
            "/api/v1/receivables/customers",
            json={
                "name": "Kofi Mensah",
                "phone_number": "0244123456",
            },
        )
        assert customer_resp.status_code == 201
        customer = customer_resp.json()

        debt_resp = client.post(
            "/api/v1/receivables",
            json={
                "customer_id": customer["customer_id"],
                "original_amount": "120.00",
                "due_date": "2026-05-30",
            },
        )
        assert debt_resp.status_code == 201
        debt = debt_resp.json()
        assert Decimal(debt["original_amount"]) == Decimal("120.00")
        assert Decimal(debt["outstanding_amount"]) == Decimal("120.00")
        assert debt["status"] == "open"

        list_resp = client.get("/api/v1/receivables")
        assert list_resp.status_code == 200
        rows = list_resp.json()
        assert len(rows) == 1
        assert rows[0]["customer_name"] == "Kofi Mensah"
        assert rows[0]["receivable_id"] == debt["receivable_id"]
    finally:
        app.dependency_overrides.clear()


def test_record_partial_and_full_repayment() -> None:
    client, session_local, _ = _build_sqlite_test_stack()
    try:
        customer_resp = client.post(
            "/api/v1/receivables/customers",
            json={"name": "Abena", "phone_number": "0244000000"},
        )
        customer_id = customer_resp.json()["customer_id"]

        debt_resp = client.post(
            "/api/v1/receivables",
            json={"customer_id": customer_id, "original_amount": "90.00"},
        )
        receivable_id = debt_resp.json()["receivable_id"]

        first_repayment = client.post(
            f"/api/v1/receivables/{receivable_id}/repayments",
            json={"amount": "30.00", "payment_method_label": "cash"},
        )
        assert first_repayment.status_code == 200

        second_repayment = client.post(
            f"/api/v1/receivables/{receivable_id}/repayments",
            json={"amount": "60.00", "payment_method_label": "mobile_money"},
        )
        assert second_repayment.status_code == 200

        overpay = client.post(
            f"/api/v1/receivables/{receivable_id}/repayments",
            json={"amount": "1.00", "payment_method_label": "cash"},
        )
        assert overpay.status_code == 422

        with session_local() as db:
            receivable = db.scalar(select(Receivable).where(Receivable.id == UUID(receivable_id)))
            assert receivable is not None
            assert receivable.outstanding_amount == Decimal("0.00")
            assert receivable.status == "settled"
            payment_count = db.scalar(select(func.count()).select_from(ReceivablePayment))
            assert payment_count == 2
    finally:
        app.dependency_overrides.clear()


def test_sync_apply_receivable_flow_is_idempotent() -> None:
    client, session_local, _ = _build_sqlite_test_stack()
    customer_id = str(uuid4())
    receivable_id = str(uuid4())
    payment_id = str(uuid4())
    payload = {
        "device_id": "device-accra-debt-001",
        "operations": [
            {
                "local_operation_id": "customer-create-op-001",
                "entity_type": "customer",
                "action_type": "create",
                "payload": {
                    "customer_id": customer_id,
                    "name": "Yaw Boateng",
                    "phone_number": "0244555566",
                },
            },
            {
                "local_operation_id": "receivable-create-op-002",
                "entity_type": "receivable",
                "action_type": "create",
                "payload": {
                    "receivable_id": receivable_id,
                    "customer_id": customer_id,
                    "original_amount": "50.00",
                },
            },
            {
                "local_operation_id": "receivable-payment-op-003",
                "entity_type": "receivable_payment",
                "action_type": "create",
                "payload": {
                    "payment_id": payment_id,
                    "receivable_id": receivable_id,
                    "amount": "20.00",
                    "payment_method_label": "cash",
                },
            },
        ],
    }
    try:
        first = client.post("/api/v1/sync/apply", json=payload)
        assert first.status_code == 200
        assert [r["status"] for r in first.json()["results"]] == ["applied", "applied", "applied"]

        second = client.post("/api/v1/sync/apply", json=payload)
        assert second.status_code == 200
        assert [r["status"] for r in second.json()["results"]] == [
            "duplicate",
            "duplicate",
            "duplicate",
        ]

        with session_local() as db:
            customer_count = db.scalar(select(func.count()).select_from(Customer))
            receivable_count = db.scalar(select(func.count()).select_from(Receivable))
            repayment_count = db.scalar(select(func.count()).select_from(ReceivablePayment))
            sync_count = db.scalar(select(func.count()).select_from(SyncOperation))
            assert customer_count == 1
            assert receivable_count == 1
            assert repayment_count == 1
            assert sync_count == 3
            receivable = db.scalar(select(Receivable).where(Receivable.id == UUID(receivable_id)))
            assert receivable is not None
            assert receivable.outstanding_amount == Decimal("30.00")
            assert receivable.status == "open"
    finally:
        app.dependency_overrides.clear()


def test_sync_apply_repayment_returns_conflict_when_server_balance_changed() -> None:
    client, session_local, current_user = _build_sqlite_test_stack()
    receivable_id: str | None = None
    try:
        with session_local() as db:
            merchant = db.query(Merchant).filter(Merchant.owner_user_id == current_user.id).one()
            store = db.query(Store).filter(
                Store.merchant_id == merchant.id,
                Store.is_default.is_(True),
            ).one()

            customer = Customer(
                store_id=store.id,
                name="Adwoa",
                phone_number="0244888999",
            )
            customer.id = uuid4()
            db.add(customer)
            db.flush()

            receivable = Receivable(
                store_id=store.id,
                customer_id=customer.id,
                original_amount=Decimal("30.00"),
                outstanding_amount=Decimal("5.00"),
                status="open",
            )
            receivable.id = uuid4()
            db.add(receivable)
            db.commit()
            receivable_id = str(receivable.id)

        payload = {
            "device_id": "device-accra-debt-002",
            "operations": [
                {
                    "local_operation_id": "receivable-payment-op-conflict",
                    "entity_type": "receivable_payment",
                    "action_type": "create",
                    "payload": {
                        "payment_id": str(uuid4()),
                        "receivable_id": receivable_id,
                        "amount": "10.00",
                        "payment_method_label": "cash",
                    },
                }
            ],
        }

        resp = client.post("/api/v1/sync/apply", json=payload)
        assert resp.status_code == 200
        result = resp.json()["results"][0]
        assert result["status"] == "conflict"
        assert "exceeds outstanding balance" in result["detail"]

        with session_local() as db:
            payment_count = db.scalar(select(func.count()).select_from(ReceivablePayment))
            sync_count = db.scalar(select(func.count()).select_from(SyncOperation))
            refreshed = db.scalar(select(Receivable).where(Receivable.id == UUID(receivable_id)))
            assert payment_count == 0
            assert sync_count == 0
            assert refreshed is not None
            assert refreshed.outstanding_amount == Decimal("5.00")
    finally:
        app.dependency_overrides.clear()
