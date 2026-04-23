"""Edge-case tests for /api/v1/reports/insights."""

from __future__ import annotations

from collections.abc import Generator
from datetime import UTC, datetime
from decimal import Decimal
from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user, get_db
from app.main import app
from app.models.audit_log import AuditLog
from app.models.expense import Expense
from app.models.inventory import InventoryBalance
from app.models.item import Item
from app.models.merchant import Merchant
from app.models.sale import Sale, SaleItem
from app.models.store import Store
from app.models.user import User


def _make_stack(
    timezone: str = "Africa/Accra",
) -> tuple[TestClient, sessionmaker[Session], User]:
    """Africa/Accra is UTC+0 — period boundaries fall on exact UTC midnights."""
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
        Sale.__table__,
        SaleItem.__table__,
        Expense.__table__,
        AuditLog.__table__,
    ):
        table.create(bind=engine)

    sl = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    user_id = uuid4()
    user = User(phone_number="233244999001")
    user.id = user_id
    user.is_active = True
    merchant = Merchant(
        owner_user_id=user_id,
        business_name="Insights Test Shop",
        business_type="Retail",
    )
    merchant.id = uuid4()
    store = Store(
        merchant_id=merchant.id,
        name="Accra Store",
        location="Accra",
        timezone=timezone,
        is_default=True,
    )
    store.id = uuid4()
    with sl() as db:
        db.add(user)
        db.add(merchant)
        db.add(store)
        db.commit()

    current_user = User(phone_number="233244999001")
    current_user.id = user_id
    current_user.is_active = True

    def _override_db() -> Generator[Session, None, None]:
        with sl() as db:
            yield db

    app.dependency_overrides[get_db] = _override_db
    app.dependency_overrides[get_current_user] = lambda: current_user
    return TestClient(app), sl, current_user


def _seed_item(
    sl: sessionmaker[Session],
    *,
    store_id,
    name: str = "Item",
    price: str = "10.00",
    qty: int = 100,
) -> object:
    with sl() as db:
        item = Item(
            store_id=store_id,
            name=name,
            default_price=Decimal(price),
            is_active=True,
        )
        item.id = uuid4()
        db.add(item)
        db.flush()
        db.add(InventoryBalance(item_id=item.id, quantity_on_hand=qty))
        db.commit()
        return item.id


def _get_store(sl: sessionmaker[Session], user_id) -> object:
    with sl() as db:
        m = db.query(Merchant).filter(Merchant.owner_user_id == user_id).one()
        return db.query(Store).filter(Store.merchant_id == m.id).one()


def test_insights_period_boundary_excludes_prev_month_sale() -> None:
    """A sale at the exact month-start boundary belongs to the prior month."""
    client, sl, user = _make_stack()
    # Africa/Accra = UTC+0; April 2026 starts at 2026-04-01T00:00:00Z.
    as_of_utc = datetime(2026, 4, 16, 12, 0, 0, tzinfo=UTC)
    try:
        store = _get_store(sl, user.id)
        item_id = _seed_item(sl, store_id=store.id)

        with sl() as db:
            # One second before April 1 midnight — must be excluded from month.
            prev_month_sale = Sale(
                store_id=store.id,
                total_amount=Decimal("99.00"),
                payment_method_label="cash",
                payment_status="recorded",
            )
            prev_month_sale.id = uuid4()
            prev_month_sale.created_at = datetime(2026, 3, 31, 23, 59, 59, tzinfo=UTC)
            db.add(prev_month_sale)
            db.commit()

        resp = client.get(
            "/api/v1/reports/insights",
            params={"as_of_utc": as_of_utc.isoformat()},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert Decimal(str(body["month"]["sales_total"])) == Decimal("0.00")
        assert body["monthly_payment_breakdown"] == []
        assert body["monthly_top_selling_items"] == []
    finally:
        app.dependency_overrides.clear()


def test_insights_payment_breakdown_all_three_methods() -> None:
    """Breakdown covers cash, mobile_money, and bank_transfer with correct totals."""
    client, sl, user = _make_stack()
    as_of_utc = datetime(2026, 4, 16, 12, 0, 0, tzinfo=UTC)
    try:
        store = _get_store(sl, user.id)
        item_id = _seed_item(sl, store_id=store.id)

        with sl() as db:
            for method, amount in [
                ("cash", "20.00"),
                ("mobile_money", "35.00"),
                ("bank_transfer", "50.00"),
            ]:
                sale = Sale(
                    store_id=store.id,
                    total_amount=Decimal(amount),
                    payment_method_label=method,
                    payment_status="recorded",
                )
                sale.id = uuid4()
                sale.created_at = datetime(2026, 4, 10, 10, 0, 0, tzinfo=UTC)
                db.add(sale)
                db.flush()
                db.add(
                    SaleItem(
                        sale_id=sale.id,
                        item_id=item_id,
                        quantity=1,
                        unit_price=Decimal(amount),
                        line_total=Decimal(amount),
                    )
                )
            db.commit()

        resp = client.get(
            "/api/v1/reports/insights",
            params={"as_of_utc": as_of_utc.isoformat()},
        )
        assert resp.status_code == 200
        breakdown = {
            row["payment_method_label"]: row
            for row in resp.json()["monthly_payment_breakdown"]
        }
        assert set(breakdown) == {"cash", "mobile_money", "bank_transfer"}
        assert Decimal(str(breakdown["cash"]["total_amount"])) == Decimal("20.00")
        assert Decimal(str(breakdown["mobile_money"]["total_amount"])) == Decimal("35.00")
        assert Decimal(str(breakdown["bank_transfer"]["total_amount"])) == Decimal("50.00")
        assert breakdown["cash"]["sale_count"] == 1
        assert breakdown["mobile_money"]["payment_method_display"] == "Mobile Money"
        assert breakdown["bank_transfer"]["payment_method_display"] == "Bank Transfer"
    finally:
        app.dependency_overrides.clear()


def test_insights_top_items_ordering_by_quantity_desc() -> None:
    """Item with higher quantity_sold appears before item with lower quantity_sold."""
    client, sl, user = _make_stack()
    as_of_utc = datetime(2026, 4, 16, 12, 0, 0, tzinfo=UTC)
    try:
        store = _get_store(sl, user.id)
        slow_id = _seed_item(sl, store_id=store.id, name="Slow Mover")
        fast_id = _seed_item(sl, store_id=store.id, name="Fast Mover")

        with sl() as db:
            sale = Sale(
                store_id=store.id,
                total_amount=Decimal("60.00"),
                payment_method_label="cash",
                payment_status="recorded",
            )
            sale.id = uuid4()
            sale.created_at = datetime(2026, 4, 10, 10, 0, 0, tzinfo=UTC)
            db.add(sale)
            db.flush()
            # Fast Mover: qty 5, Slow Mover: qty 1 — Fast must rank first.
            db.add(
                SaleItem(
                    sale_id=sale.id,
                    item_id=fast_id,
                    quantity=5,
                    unit_price=Decimal("10.00"),
                    line_total=Decimal("50.00"),
                )
            )
            db.add(
                SaleItem(
                    sale_id=sale.id,
                    item_id=slow_id,
                    quantity=1,
                    unit_price=Decimal("10.00"),
                    line_total=Decimal("10.00"),
                )
            )
            db.commit()

        resp = client.get(
            "/api/v1/reports/insights",
            params={"as_of_utc": as_of_utc.isoformat()},
        )
        assert resp.status_code == 200
        top = resp.json()["monthly_top_selling_items"]
        assert top[0]["item_name"] == "Fast Mover"
        assert top[0]["quantity_sold"] == 5
        assert top[1]["item_name"] == "Slow Mover"
        assert top[1]["quantity_sold"] == 1
    finally:
        app.dependency_overrides.clear()


def test_insights_top_n_param_limits_result() -> None:
    """top_n=2 returns at most 2 items even when more are available."""
    client, sl, user = _make_stack()
    as_of_utc = datetime(2026, 4, 16, 12, 0, 0, tzinfo=UTC)
    try:
        store = _get_store(sl, user.id)
        item_ids = [
            _seed_item(sl, store_id=store.id, name=f"Item {i}") for i in range(4)
        ]

        with sl() as db:
            sale = Sale(
                store_id=store.id,
                total_amount=Decimal("40.00"),
                payment_method_label="cash",
                payment_status="recorded",
            )
            sale.id = uuid4()
            sale.created_at = datetime(2026, 4, 10, 10, 0, 0, tzinfo=UTC)
            db.add(sale)
            db.flush()
            for iid in item_ids:
                db.add(
                    SaleItem(
                        sale_id=sale.id,
                        item_id=iid,
                        quantity=1,
                        unit_price=Decimal("10.00"),
                        line_total=Decimal("10.00"),
                    )
                )
            db.commit()

        resp = client.get(
            "/api/v1/reports/insights",
            params={"as_of_utc": as_of_utc.isoformat(), "top_n": 2},
        )
        assert resp.status_code == 200
        assert len(resp.json()["monthly_top_selling_items"]) == 2
    finally:
        app.dependency_overrides.clear()


def test_insights_empty_store_returns_zeros() -> None:
    """A store with no sales or expenses returns all-zero totals and empty lists."""
    client, _, _ = _make_stack()
    as_of_utc = datetime(2026, 4, 16, 12, 0, 0, tzinfo=UTC)
    try:
        resp = client.get(
            "/api/v1/reports/insights",
            params={"as_of_utc": as_of_utc.isoformat()},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert Decimal(str(body["week"]["sales_total"])) == Decimal("0.00")
        assert Decimal(str(body["week"]["expenses_total"])) == Decimal("0.00")
        assert Decimal(str(body["week"]["estimated_profit"])) == Decimal("0.00")
        assert Decimal(str(body["month"]["sales_total"])) == Decimal("0.00")
        assert Decimal(str(body["month"]["expenses_total"])) == Decimal("0.00")
        assert Decimal(str(body["month"]["estimated_profit"])) == Decimal("0.00")
        assert body["monthly_payment_breakdown"] == []
        assert body["monthly_top_selling_items"] == []
    finally:
        app.dependency_overrides.clear()
