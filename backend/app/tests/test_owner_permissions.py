"""Owner/staff permission matrix for business-sensitive routes."""

from __future__ import annotations

from collections.abc import Callable, Generator
from decimal import Decimal
from uuid import UUID, uuid4

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user, get_db
from app.core.constants import (
    USER_ROLE_CASHIER,
    USER_ROLE_MANAGER,
    USER_ROLE_MERCHANT_OWNER,
    USER_ROLE_STOCK_KEEPER,
)
from app.main import app
from app.models.audit_log import AuditLog
from app.models.customer import Customer
from app.models.inventory import InventoryBalance, InventoryMovement
from app.models.item import Item, ItemVariant
from app.models.merchant import Merchant
from app.models.receivable import Receivable, ReceivablePayment
from app.models.sale import Sale, SaleItem
from app.models.store import Store
from app.models.sync_operation import SyncOperation
from app.models.user import User


def _build_permission_test_stack() -> tuple[
    TestClient,
    sessionmaker[Session],
    User,
    User,
    UUID,
    Callable[[User], None],
]:
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
        ItemVariant.__table__,
        InventoryBalance.__table__,
        InventoryMovement.__table__,
        Sale.__table__,
        SaleItem.__table__,
        Receivable.__table__,
        ReceivablePayment.__table__,
        SyncOperation.__table__,
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
    owner_id = uuid4()
    staff_id = uuid4()
    merchant_id = uuid4()
    owner = User(phone_number="233244123456", role=USER_ROLE_MERCHANT_OWNER)
    owner.id = owner_id
    owner.is_active = True
    staff = User(
        phone_number="233244123457",
        role=USER_ROLE_CASHIER,
    )
    staff.id = staff_id
    staff.is_active = True
    merchant = Merchant(
        owner_user_id=owner_id,
        business_name="Ama Ventures",
        business_type="Provision Shop",
    )
    merchant.id = merchant_id
    staff.merchant_id = merchant_id
    store = Store(
        merchant_id=merchant.id,
        name="Main Store",
        location="Madina",
        timezone="Africa/Accra",
        is_default=True,
    )
    store.id = uuid4()
    store_id = store.id

    with session_local() as db:
        db.add_all([owner, staff, merchant, store])
        db.commit()

    current_owner = User(phone_number="233244123456", role=USER_ROLE_MERCHANT_OWNER)
    current_owner.id = owner_id
    current_owner.is_active = True
    current_staff = User(
        phone_number="233244123457",
        role=USER_ROLE_CASHIER,
        merchant_id=merchant_id,
    )
    current_staff.id = staff_id
    current_staff.is_active = True
    current_user = {
        "id": current_owner.id,
        "role_override": current_owner.role,
    }

    def _override_get_db() -> Generator[Session, None, None]:
        with session_local() as db:
            yield db

    def _override_get_current_user() -> User:
        with session_local() as db:
            user = db.get(User, current_user["id"])
            assert user is not None
            db.expunge(user)
        user.role = current_user["role_override"]
        return user

    def _set_current_user(user: User) -> None:
        current_user["id"] = user.id
        current_user["role_override"] = user.role

    app.dependency_overrides[get_db] = _override_get_db
    app.dependency_overrides[get_current_user] = _override_get_current_user
    return TestClient(app), session_local, current_owner, current_staff, store_id, _set_current_user


def _seed_item(
    session_local: sessionmaker[Session],
    *,
    store_id: UUID,
    quantity: int = 12,
    is_active: bool = True,
) -> UUID:
    with session_local() as db:
        item = Item(
            store_id=store_id,
            name=f"Bagged Rice {uuid4().hex[:6]}",
            default_price=Decimal("35.00"),
            sku=f"RICE-{uuid4().hex[:8]}",
            category="Groceries",
            low_stock_threshold=2,
            is_active=is_active,
        )
        item.id = uuid4()
        db.add(item)
        db.flush()
        if is_active:
            db.add(InventoryBalance(item_id=item.id, quantity_on_hand=quantity))
        db.commit()
        return item.id


def _create_sale(client: TestClient, *, item_id: UUID) -> str:
    response = client.post(
        "/api/v1/sales",
        json={
            "payment_method_label": "cash",
            "lines": [
                {
                    "item_id": str(item_id),
                    "quantity": 1,
                    "unit_price": "35.00",
                }
            ],
        },
    )
    assert response.status_code == 201
    return response.json()["sale_id"]


def _create_receivable(client: TestClient) -> str:
    customer_response = client.post(
        "/api/v1/receivables/customers",
        json={"name": f"Ama Customer {uuid4().hex[:6]}", "phone_number": "233200000001"},
    )
    assert customer_response.status_code == 201
    response = client.post(
        "/api/v1/receivables",
        json={
            "customer_id": customer_response.json()["customer_id"],
            "original_amount": "120.00",
        },
    )
    assert response.status_code == 201
    return response.json()["receivable_id"]


def test_staff_can_read_merchant_context_but_cannot_edit_profile_or_store() -> None:
    client, _, owner, staff, _, set_current_user = _build_permission_test_stack()
    try:
        set_current_user(owner)
        owner_context = client.get("/api/v1/merchants/me/context")
        assert owner_context.status_code == 200
        assert owner_context.json()["merchant"]["business_name"] == "Ama Ventures"

        owner_profile_update = client.patch(
            "/api/v1/merchants/me",
            json={"business_name": "Ama Ventures Plus", "business_type": "Retail"},
        )
        assert owner_profile_update.status_code == 200

        owner_store_update = client.patch(
            "/api/v1/stores/default",
            json={"name": "Main Store Updated", "location": "Madina", "timezone": "Africa/Accra"},
        )
        assert owner_store_update.status_code == 200

        set_current_user(staff)
        staff_context = client.get("/api/v1/merchants/me/context")
        assert staff_context.status_code == 200
        assert staff_context.json()["merchant"]["business_name"] == "Ama Ventures Plus"

        staff_profile_update = client.patch(
            "/api/v1/merchants/me",
            json={"business_name": "Staff Edit", "business_type": "Retail"},
        )
        assert staff_profile_update.status_code == 403

        staff_store_update = client.patch(
            "/api/v1/stores/default",
            json={"name": "Staff Store", "location": "Madina", "timezone": "Africa/Accra"},
        )
        assert staff_store_update.status_code == 403
    finally:
        app.dependency_overrides.clear()


def test_owner_only_destructive_routes_keep_owner_access_and_block_staff() -> None:
    client, session_local, owner, staff, store_id, set_current_user = _build_permission_test_stack()
    try:
        set_current_user(owner)
        owner_sale_item_id = _seed_item(session_local, store_id=store_id)
        owner_sale_id = _create_sale(client, item_id=owner_sale_item_id)
        owner_void_response = client.post(
            f"/api/v1/sales/{owner_sale_id}/void",
            json={"reason": "incorrect quantity"},
        )
        assert owner_void_response.status_code == 200

        staff_sale_item_id = _seed_item(session_local, store_id=store_id)
        staff_sale_id = _create_sale(client, item_id=staff_sale_item_id)
        set_current_user(staff)
        staff_void_response = client.post(
            f"/api/v1/sales/{staff_sale_id}/void",
            json={"reason": "staff attempt"},
        )
        assert staff_void_response.status_code == 403

        set_current_user(owner)
        owner_receivable_id = _create_receivable(client)
        owner_cancel_response = client.post(f"/api/v1/receivables/{owner_receivable_id}/cancel")
        assert owner_cancel_response.status_code == 200

        staff_receivable_id = _create_receivable(client)
        set_current_user(staff)
        staff_cancel_response = client.post(f"/api/v1/receivables/{staff_receivable_id}/cancel")
        assert staff_cancel_response.status_code == 403

        set_current_user(owner)
        owner_delete_item_id = _seed_item(session_local, store_id=store_id, is_active=False)
        owner_delete_response = client.delete(f"/api/v1/items/{owner_delete_item_id}")
        assert owner_delete_response.status_code == 204

        staff_delete_item_id = _seed_item(session_local, store_id=store_id, is_active=False)
        set_current_user(staff)
        staff_delete_response = client.delete(f"/api/v1/items/{staff_delete_item_id}")
        assert staff_delete_response.status_code == 403
    finally:
        app.dependency_overrides.clear()


def test_delete_account_is_owner_only() -> None:
    client, _, owner, staff, _, set_current_user = _build_permission_test_stack()
    try:
        set_current_user(staff)
        staff_response = client.delete("/api/v1/auth/account")
        assert staff_response.status_code == 403

        set_current_user(owner)
        owner_response = client.delete("/api/v1/auth/account")
        assert owner_response.status_code == 200
    finally:
        app.dependency_overrides.clear()


def _as_role(staff: User, role: str | None) -> User:
    """Clone the persisted staff user with a role override for set_current_user."""
    clone = User(phone_number=staff.phone_number, role=role)
    clone.id = staff.id
    clone.is_active = True
    return clone


def test_manager_has_elevated_operational_permissions() -> None:
    client, session_local, owner, staff, store_id, set_current_user = (
        _build_permission_test_stack()
    )
    try:
        manager = _as_role(staff, USER_ROLE_MANAGER)
        set_current_user(manager)

        # Inventory write (stock-in) — denied for cashier, allowed for manager.
        active_item_id = _seed_item(session_local, store_id=store_id)
        stock_in = client.post(
            f"/api/v1/items/{active_item_id}/stock-in",
            json={"quantity": 5, "reason": "manager restock"},
        )
        assert stock_in.status_code == 200

        # Void a sale (owner-or-manager only).
        sale_id = _create_sale(client, item_id=active_item_id)
        void = client.post(
            f"/api/v1/sales/{sale_id}/void",
            json={"reason": "manager void"},
        )
        assert void.status_code == 200

        # Cancel a receivable (owner-or-manager only).
        receivable_id = _create_receivable(client)
        cancel = client.post(f"/api/v1/receivables/{receivable_id}/cancel")
        assert cancel.status_code == 200

        # Delete an (inactive) item (owner-or-manager only).
        delete_item_id = _seed_item(session_local, store_id=store_id, is_active=False)
        deleted = client.delete(f"/api/v1/items/{delete_item_id}")
        assert deleted.status_code == 204
    finally:
        app.dependency_overrides.clear()


def test_cashier_cannot_modify_inventory_but_can_sell() -> None:
    client, session_local, owner, staff, store_id, set_current_user = (
        _build_permission_test_stack()
    )
    try:
        cashier = _as_role(staff, USER_ROLE_CASHIER)
        set_current_user(cashier)

        item_id = _seed_item(session_local, store_id=store_id)

        # Cashier can record sales (daily money movement).
        sale = client.post(
            "/api/v1/sales",
            json={
                "payment_method_label": "cash",
                "lines": [
                    {"item_id": str(item_id), "quantity": 1, "unit_price": "35.00"}
                ],
            },
        )
        assert sale.status_code == 201

        # ...but cannot mutate inventory.
        stock_in = client.post(
            f"/api/v1/items/{item_id}/stock-in",
            json={"quantity": 5, "reason": "cashier restock"},
        )
        assert stock_in.status_code == 403
    finally:
        app.dependency_overrides.clear()


def test_stock_keeper_manages_inventory_but_not_money() -> None:
    client, session_local, owner, staff, store_id, set_current_user = (
        _build_permission_test_stack()
    )
    try:
        stock_keeper = _as_role(staff, USER_ROLE_STOCK_KEEPER)
        set_current_user(stock_keeper)

        item_id = _seed_item(session_local, store_id=store_id)

        # Stock keeper can manage inventory.
        stock_in = client.post(
            f"/api/v1/items/{item_id}/stock-in",
            json={"quantity": 5, "reason": "stock keeper restock"},
        )
        assert stock_in.status_code == 200

        # ...but cannot record sales or create customers/receivables.
        sale = client.post(
            "/api/v1/sales",
            json={
                "payment_method_label": "cash",
                "lines": [
                    {"item_id": str(item_id), "quantity": 1, "unit_price": "35.00"}
                ],
            },
        )
        assert sale.status_code == 403

        customer = client.post(
            "/api/v1/receivables/customers",
            json={"name": "Walk-in", "phone_number": "233200000009"},
        )
        assert customer.status_code == 403
    finally:
        app.dependency_overrides.clear()


def test_legacy_owner_without_role_keeps_full_access() -> None:
    client, session_local, owner, _, store_id, set_current_user = _build_permission_test_stack()
    try:
        owner.role = None
        set_current_user(owner)
        item_id = _seed_item(session_local, store_id=store_id)
        sale_id = _create_sale(client, item_id=item_id)
        response = client.post(
            f"/api/v1/sales/{sale_id}/void",
            json={"reason": "legacy owner"},
        )
        assert response.status_code == 200
    finally:
        app.dependency_overrides.clear()
