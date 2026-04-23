"""Dashboard/report summary tests."""

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
from app.models.customer import Customer
from app.models.expense import Expense
from app.models.inventory import InventoryBalance
from app.models.item import Item
from app.models.merchant import Merchant
from app.models.receivable import Receivable, ReceivablePayment
from app.models.sale import Sale, SaleItem
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
        InventoryBalance.__table__,
        Customer.__table__,
        Sale.__table__,
        SaleItem.__table__,
        Expense.__table__,
        Receivable.__table__,
        ReceivablePayment.__table__,
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
        timezone="America/New_York",
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


def test_reports_summary_respects_store_timezone_window() -> None:
    client, session_local, current_user = _build_sqlite_test_stack()
    as_of_utc = datetime(2026, 4, 16, 12, 0, 0, tzinfo=UTC)
    # America/New_York midnight boundary for this day is 2026-04-16T04:00:00Z.
    include_at = datetime(2026, 4, 16, 5, 0, 0, tzinfo=UTC)
    exclude_at = datetime(2026, 4, 16, 3, 30, 0, tzinfo=UTC)
    try:
        with session_local() as db:
            merchant = db.query(Merchant).filter(Merchant.owner_user_id == current_user.id).one()
            store = db.query(Store).filter(
                Store.merchant_id == merchant.id,
                Store.is_default.is_(True),
            ).one()

            customer = Customer(
                store_id=store.id,
                name="Kofi Mensah",
                phone_number="0244001122",
            )
            customer.id = uuid4()
            db.add(customer)

            item_a = Item(
                store_id=store.id,
                name="Milk",
                default_price=Decimal("10.00"),
                low_stock_threshold=5,
                is_active=True,
            )
            item_a.id = uuid4()
            item_a.created_at = include_at
            item_b = Item(
                store_id=store.id,
                name="Bread",
                default_price=Decimal("8.00"),
                low_stock_threshold=2,
                is_active=True,
            )
            item_b.id = uuid4()
            item_b.created_at = include_at
            item_c = Item(
                store_id=store.id,
                name="Soap",
                default_price=Decimal("6.00"),
                low_stock_threshold=5,
                is_active=False,
            )
            item_c.id = uuid4()
            item_c.created_at = include_at
            db.add(item_a)
            db.add(item_b)
            db.add(item_c)
            db.flush()
            db.add(InventoryBalance(item_id=item_a.id, quantity_on_hand=3))
            db.add(InventoryBalance(item_id=item_b.id, quantity_on_hand=2))
            db.add(InventoryBalance(item_id=item_c.id, quantity_on_hand=1))

            sale_in = Sale(
                store_id=store.id,
                total_amount=Decimal("100.00"),
                payment_method_label="cash",
                payment_status="recorded",
            )
            sale_in.id = uuid4()
            sale_in.created_at = include_at
            sale_out = Sale(
                store_id=store.id,
                total_amount=Decimal("50.00"),
                payment_method_label="cash",
                payment_status="recorded",
            )
            sale_out.id = uuid4()
            sale_out.created_at = exclude_at
            db.add(sale_in)
            db.add(sale_out)

            expense_in = Expense(
                store_id=store.id,
                category="utilities",
                amount=Decimal("25.00"),
                note="Power bill",
            )
            expense_in.id = uuid4()
            expense_in.created_at = include_at
            expense_out = Expense(
                store_id=store.id,
                category="transport",
                amount=Decimal("10.00"),
                note="Delivery",
            )
            expense_out.id = uuid4()
            expense_out.created_at = exclude_at
            db.add(expense_in)
            db.add(expense_out)

            receivable_open = Receivable(
                store_id=store.id,
                customer_id=customer.id,
                original_amount=Decimal("40.00"),
                outstanding_amount=Decimal("40.00"),
                status="open",
            )
            receivable_open.id = uuid4()
            receivable_open.created_at = include_at
            receivable_settled = Receivable(
                store_id=store.id,
                customer_id=customer.id,
                original_amount=Decimal("30.00"),
                outstanding_amount=Decimal("0.00"),
                status="settled",
            )
            receivable_settled.id = uuid4()
            receivable_settled.created_at = include_at
            db.add(receivable_open)
            db.add(receivable_settled)

            db.commit()

        response = client.get(
            "/api/v1/reports/summary",
            params={"as_of_utc": as_of_utc.isoformat()},
        )
        assert response.status_code == 200
        body = response.json()
        assert Decimal(str(body["today_sales_total"])) == Decimal("100.00")
        assert Decimal(str(body["today_expenses_total"])) == Decimal("25.00")
        assert Decimal(str(body["today_estimated_profit"])) == Decimal("75.00")
        assert Decimal(str(body["debt_outstanding_total"])) == Decimal("40.00")
        assert body["low_stock_count"] == 2
        assert body["timezone"] == "America/New_York"
        assert body["period_start_utc"] == "2026-04-16T04:00:00Z"
        assert body["period_end_utc"] == "2026-04-17T04:00:00Z"
    finally:
        app.dependency_overrides.clear()


def test_reports_summary_returns_zero_defaults_when_no_data() -> None:
    client, _, _ = _build_sqlite_test_stack()
    try:
        response = client.get("/api/v1/reports/summary")
        assert response.status_code == 200
        body = response.json()
        assert Decimal(str(body["today_sales_total"])) == Decimal("0.00")
        assert Decimal(str(body["today_expenses_total"])) == Decimal("0.00")
        assert Decimal(str(body["today_estimated_profit"])) == Decimal("0.00")
        assert Decimal(str(body["debt_outstanding_total"])) == Decimal("0.00")
        assert body["low_stock_count"] == 0
    finally:
        app.dependency_overrides.clear()


def test_reports_recent_activity_merges_and_sorts_sources() -> None:
    client, session_local, current_user = _build_sqlite_test_stack()
    try:
        with session_local() as db:
            merchant = db.query(Merchant).filter(Merchant.owner_user_id == current_user.id).one()
            store = db.query(Store).filter(
                Store.merchant_id == merchant.id,
                Store.is_default.is_(True),
            ).one()

            customer = Customer(
                store_id=store.id,
                name="Efua Asante",
                phone_number="0244778899",
            )
            customer.id = uuid4()
            db.add(customer)

            sale = Sale(
                store_id=store.id,
                total_amount=Decimal("40.00"),
                payment_method_label="cash",
                payment_status="recorded",
            )
            sale.id = uuid4()
            sale.created_at = datetime(2026, 4, 16, 10, 0, 0, tzinfo=UTC)

            expense = Expense(
                store_id=store.id,
                category="transport",
                amount=Decimal("12.00"),
                note="Market run",
            )
            expense.id = uuid4()
            expense.created_at = datetime(2026, 4, 16, 11, 0, 0, tzinfo=UTC)

            receivable = Receivable(
                store_id=store.id,
                customer_id=customer.id,
                original_amount=Decimal("30.00"),
                outstanding_amount=Decimal("10.00"),
                status="open",
            )
            receivable.id = uuid4()
            receivable.created_at = datetime(2026, 4, 16, 8, 0, 0, tzinfo=UTC)
            db.add(receivable)
            db.flush()

            repayment = ReceivablePayment(
                receivable_id=receivable.id,
                amount=Decimal("20.00"),
                payment_method_label="mobile_money",
            )
            repayment.id = uuid4()
            repayment.created_at = datetime(2026, 4, 16, 12, 0, 0, tzinfo=UTC)

            db.add(sale)
            db.add(expense)
            db.add(repayment)
            db.commit()

        response = client.get("/api/v1/reports/recent-activity", params={"limit": 5})
        assert response.status_code == 200
        body = response.json()
        assert [row["activity_type"] for row in body] == [
            "repayment",
            "expense",
            "sale",
        ]
        assert body[0]["title"] == "Efua Asante paid"
        assert body[0]["detail"] == "Mobile Money"
        assert Decimal(str(body[0]["amount"])) == Decimal("20.00")
        assert body[1]["detail"] == "Transport | Market run"
        assert body[2]["detail"] == "Cash"
    finally:
        app.dependency_overrides.clear()


def test_reports_insights_returns_week_month_breakdown_and_top_items() -> None:
    client, session_local, current_user = _build_sqlite_test_stack()
    as_of_utc = datetime(2026, 4, 16, 12, 0, 0, tzinfo=UTC)
    try:
        with session_local() as db:
            merchant = db.query(Merchant).filter(Merchant.owner_user_id == current_user.id).one()
            store = db.query(Store).filter(
                Store.merchant_id == merchant.id,
                Store.is_default.is_(True),
            ).one()

            item_a = Item(
                store_id=store.id,
                name="Rice",
                default_price=Decimal("10.00"),
                low_stock_threshold=2,
                is_active=True,
            )
            item_a.id = uuid4()
            item_b = Item(
                store_id=store.id,
                name="Oil",
                default_price=Decimal("10.00"),
                low_stock_threshold=1,
                is_active=True,
            )
            item_b.id = uuid4()
            db.add(item_a)
            db.add(item_b)
            db.flush()

            sale_week_cash = Sale(
                store_id=store.id,
                total_amount=Decimal("30.00"),
                payment_method_label="cash",
                payment_status="recorded",
            )
            sale_week_cash.id = uuid4()
            sale_week_cash.created_at = datetime(2026, 4, 16, 10, 0, 0, tzinfo=UTC)
            db.add(sale_week_cash)
            db.flush()
            db.add(
                SaleItem(
                    sale_id=sale_week_cash.id,
                    item_id=item_a.id,
                    quantity=2,
                    unit_price=Decimal("10.00"),
                    line_total=Decimal("20.00"),
                )
            )
            db.add(
                SaleItem(
                    sale_id=sale_week_cash.id,
                    item_id=item_b.id,
                    quantity=1,
                    unit_price=Decimal("10.00"),
                    line_total=Decimal("10.00"),
                )
            )

            sale_week_momo = Sale(
                store_id=store.id,
                total_amount=Decimal("15.00"),
                payment_method_label="mobile_money",
                payment_status="recorded",
            )
            sale_week_momo.id = uuid4()
            sale_week_momo.created_at = datetime(2026, 4, 14, 12, 0, 0, tzinfo=UTC)
            db.add(sale_week_momo)
            db.flush()
            db.add(
                SaleItem(
                    sale_id=sale_week_momo.id,
                    item_id=item_a.id,
                    quantity=1,
                    unit_price=Decimal("15.00"),
                    line_total=Decimal("15.00"),
                )
            )

            sale_month_bank = Sale(
                store_id=store.id,
                total_amount=Decimal("50.00"),
                payment_method_label="bank_transfer",
                payment_status="recorded",
            )
            sale_month_bank.id = uuid4()
            sale_month_bank.created_at = datetime(2026, 4, 2, 10, 0, 0, tzinfo=UTC)
            db.add(sale_month_bank)
            db.flush()
            db.add(
                SaleItem(
                    sale_id=sale_month_bank.id,
                    item_id=item_b.id,
                    quantity=5,
                    unit_price=Decimal("10.00"),
                    line_total=Decimal("50.00"),
                )
            )

            sale_outside_month = Sale(
                store_id=store.id,
                total_amount=Decimal("100.00"),
                payment_method_label="cash",
                payment_status="recorded",
            )
            sale_outside_month.id = uuid4()
            sale_outside_month.created_at = datetime(2026, 3, 31, 23, 0, 0, tzinfo=UTC)
            db.add(sale_outside_month)
            db.flush()
            db.add(
                SaleItem(
                    sale_id=sale_outside_month.id,
                    item_id=item_a.id,
                    quantity=10,
                    unit_price=Decimal("10.00"),
                    line_total=Decimal("100.00"),
                )
            )

            expense_week = Expense(
                store_id=store.id,
                category="utilities",
                amount=Decimal("5.00"),
                note="Power",
            )
            expense_week.id = uuid4()
            expense_week.created_at = datetime(2026, 4, 15, 9, 0, 0, tzinfo=UTC)
            expense_month = Expense(
                store_id=store.id,
                category="transport",
                amount=Decimal("7.00"),
                note="Delivery",
            )
            expense_month.id = uuid4()
            expense_month.created_at = datetime(2026, 4, 3, 9, 0, 0, tzinfo=UTC)
            expense_outside_month = Expense(
                store_id=store.id,
                category="rent",
                amount=Decimal("20.00"),
                note="March rent",
            )
            expense_outside_month.id = uuid4()
            expense_outside_month.created_at = datetime(2026, 3, 31, 23, 0, 0, tzinfo=UTC)
            db.add(expense_week)
            db.add(expense_month)
            db.add(expense_outside_month)

            db.commit()

        response = client.get(
            "/api/v1/reports/insights",
            params={"as_of_utc": as_of_utc.isoformat(), "top_n": 3},
        )
        assert response.status_code == 200
        body = response.json()

        assert Decimal(str(body["week"]["sales_total"])) == Decimal("45.00")
        assert Decimal(str(body["week"]["expenses_total"])) == Decimal("5.00")
        assert Decimal(str(body["week"]["estimated_profit"])) == Decimal("40.00")

        assert Decimal(str(body["month"]["sales_total"])) == Decimal("95.00")
        assert Decimal(str(body["month"]["expenses_total"])) == Decimal("12.00")
        assert Decimal(str(body["month"]["estimated_profit"])) == Decimal("83.00")

        assert [row["payment_method_label"] for row in body["monthly_payment_breakdown"]] == [
            "bank_transfer",
            "cash",
            "mobile_money",
        ]
        assert body["monthly_payment_breakdown"][0]["payment_method_display"] == "Bank Transfer"
        assert Decimal(str(body["monthly_payment_breakdown"][0]["total_amount"])) == Decimal(
            "50.00"
        )
        assert body["monthly_payment_breakdown"][0]["sale_count"] == 1

        assert [row["item_name"] for row in body["monthly_top_selling_items"]] == [
            "Oil",
            "Rice",
        ]
        assert body["monthly_top_selling_items"][0]["quantity_sold"] == 6
        assert Decimal(str(body["monthly_top_selling_items"][0]["sales_total"])) == Decimal(
            "60.00"
        )
        assert body["monthly_top_selling_items"][1]["quantity_sold"] == 3
        assert Decimal(str(body["monthly_top_selling_items"][1]["sales_total"])) == Decimal(
            "35.00"
        )
    finally:
        app.dependency_overrides.clear()
