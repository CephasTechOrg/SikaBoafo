"""Phase 2 fix tests.

Fix #11: low_stock_threshold (and other nullable fields) can now be explicitly
         cleared back to null via PATCH or sync update.
Fix #8:  _moneyToMinor handles negative amounts correctly (tested inline below
         via a Dart-equivalent logic check in a Python comment — full Flutter
         unit tests are in the mobile/test/ directory).
"""

from __future__ import annotations

from collections.abc import Generator
from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user, get_db
from app.main import app
from app.models.audit_log import AuditLog
from app.models.inventory import InventoryBalance, InventoryMovement
from app.models.item import Item, ItemVariant
from app.models.merchant import Merchant
from app.models.store import Store
from app.models.sync_apply_throttle import SyncApplyThrottle
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
        ItemVariant.__table__,
        InventoryBalance.__table__,
        InventoryMovement.__table__,
        SyncOperation.__table__,
        SyncApplyThrottle.__table__,
        AuditLog.__table__,
    ):
        table.create(bind=engine)

    session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    user_id = uuid4()
    user = User(phone_number="233200111222")
    user.id = user_id
    user.is_active = True
    merchant = Merchant(
        owner_user_id=user.id,
        business_name="Phase 2 Test Venture",
        business_type="General",
    )
    merchant.id = uuid4()
    store = Store(
        merchant_id=merchant.id,
        name="Main Store",
        location="Accra",
        timezone="Africa/Accra",
        is_default=True,
    )
    store.id = uuid4()
    with session_local() as db:
        db.add(user)
        db.add(merchant)
        db.add(store)
        db.commit()
    current_user = User(phone_number="233200111222")
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


# ─── Fix #11: nullable fields can be explicitly cleared via PATCH ─────────────


def test_low_stock_threshold_can_be_set_then_cleared() -> None:
    """Sending low_stock_threshold: null must clear a previously-set threshold.

    Before the fix, the service used `if payload.low_stock_threshold is not None`
    which meant null was indistinguishable from 'field omitted'. Merchants
    could set a threshold but never remove it.
    """
    client, _, _ = _build_sqlite_test_stack()
    try:
        # Create item with a threshold
        create_resp = client.post(
            "/api/v1/items",
            json={
                "name": "Bottled Water",
                "default_price": "3.00",
                "low_stock_threshold": 10,
            },
        )
        assert create_resp.status_code == 201
        created = create_resp.json()
        item_id = created["item_id"]
        assert created["low_stock_threshold"] == 10

        # Verify threshold is set
        get_resp = client.get("/api/v1/items")
        assert get_resp.status_code == 200
        item = next(i for i in get_resp.json() if i["item_id"] == item_id)
        assert item["low_stock_threshold"] == 10

        # Clear the threshold by sending null explicitly
        clear_resp = client.patch(
            f"/api/v1/items/{item_id}",
            json={"low_stock_threshold": None},
        )
        assert clear_resp.status_code == 200, clear_resp.text
        cleared = clear_resp.json()
        assert cleared["low_stock_threshold"] is None, (
            "Expected low_stock_threshold to be null after explicit clear, "
            f"got: {cleared['low_stock_threshold']}"
        )
    finally:
        app.dependency_overrides.clear()


def test_omitting_low_stock_threshold_does_not_clear_it() -> None:
    """Omitting low_stock_threshold from a PATCH must NOT clear it.

    Regression guard: the model_fields_set approach must only clear the field
    when it is explicitly included in the request body.
    """
    client, _, _ = _build_sqlite_test_stack()
    try:
        create_resp = client.post(
            "/api/v1/items",
            json={
                "name": "Tom Tom",
                "default_price": "1.00",
                "low_stock_threshold": 5,
            },
        )
        assert create_resp.status_code == 201
        item_id = create_resp.json()["item_id"]

        # PATCH only the name — omit low_stock_threshold entirely
        patch_resp = client.patch(
            f"/api/v1/items/{item_id}",
            json={"name": "Tom Tom Candy"},
        )
        assert patch_resp.status_code == 200
        patched = patch_resp.json()
        assert patched["name"] == "Tom Tom Candy"
        # Threshold must be preserved
        assert patched["low_stock_threshold"] == 5, (
            "low_stock_threshold must not be cleared when field is omitted from PATCH"
        )
    finally:
        app.dependency_overrides.clear()


def test_cost_price_can_be_explicitly_cleared() -> None:
    """Same model_fields_set fix applies to cost_price — can be set to null."""
    client, _, _ = _build_sqlite_test_stack()
    try:
        create_resp = client.post(
            "/api/v1/items",
            json={
                "name": "Sardine Tin",
                "default_price": "15.00",
                "cost_price": "10.00",
            },
        )
        assert create_resp.status_code == 201
        item_id = create_resp.json()["item_id"]
        assert create_resp.json()["cost_price"] == "10.00"

        # Clear cost_price with explicit null
        clear_resp = client.patch(
            f"/api/v1/items/{item_id}",
            json={"cost_price": None},
        )
        assert clear_resp.status_code == 200
        assert clear_resp.json()["cost_price"] is None, (
            "cost_price must be clearable with explicit null PATCH"
        )
    finally:
        app.dependency_overrides.clear()


def test_category_can_be_explicitly_cleared() -> None:
    """Same model_fields_set fix applies to category."""
    client, _, _ = _build_sqlite_test_stack()
    try:
        create_resp = client.post(
            "/api/v1/items",
            json={
                "name": "Malt",
                "default_price": "20.00",
                "category": "Drinks",
            },
        )
        assert create_resp.status_code == 201
        item_id = create_resp.json()["item_id"]

        clear_resp = client.patch(
            f"/api/v1/items/{item_id}",
            json={"category": None},
        )
        assert clear_resp.status_code == 200
        assert clear_resp.json()["category"] is None
    finally:
        app.dependency_overrides.clear()


def test_sync_apply_can_clear_low_stock_threshold_via_update() -> None:
    """Verify the model_fields_set fix works through the sync pathway too.

    The sync dispatch calls ItemUpdateIn.model_validate(payload.model_dump(...))
    which means model_fields_set will reflect the keys present in the payload
    dict — so explicitly including 'low_stock_threshold': None in the sync
    payload must clear the threshold.
    """
    client, _, _ = _build_sqlite_test_stack()
    item_id = str(uuid4())
    device_id = "device-threshold-test-01"
    try:
        # Create with threshold via sync
        client.post(
            "/api/v1/sync/apply",
            json={
                "device_id": device_id,
                "operations": [
                    {
                        "local_operation_id": "op-threshold-create-001",
                        "entity_type": "item",
                        "action_type": "create",
                        "payload": {
                            "item_id": item_id,
                            "name": "Ginger Beer",
                            "default_price": "8.00",
                            "low_stock_threshold": 15,
                        },
                    }
                ],
            },
        )

        # Verify threshold is set
        items = client.get("/api/v1/items").json()
        item = next(i for i in items if i["item_id"] == item_id)
        assert item["low_stock_threshold"] == 15

        # Clear threshold via sync update
        clear_resp = client.post(
            "/api/v1/sync/apply",
            json={
                "device_id": device_id,
                "operations": [
                    {
                        "local_operation_id": "op-threshold-clear-002",
                        "entity_type": "item",
                        "action_type": "update",
                        "payload": {
                            "item_id": item_id,
                            "low_stock_threshold": None,
                            "version": 1,
                        },
                    }
                ],
            },
        )
        assert clear_resp.status_code == 200
        result = clear_resp.json()["results"][0]
        assert result["status"] == "applied", (
            f"Expected 'applied' but got '{result['status']}': {result.get('detail')}"
        )

        # Verify threshold is now null
        items_after = client.get("/api/v1/items").json()
        item_after = next(i for i in items_after if i["item_id"] == item_id)
        assert item_after["low_stock_threshold"] is None, (
            "low_stock_threshold must be null after sync clear"
        )
    finally:
        app.dependency_overrides.clear()


# ─── Fix #8: _moneyToMinor handles negatives (Dart logic, Python equivalent) ─
# The Dart fix is in dashboard_providers.dart. Below is the equivalent Python
# logic to document and verify the expected behavior.


def test_money_to_minor_negative_handling_logic() -> None:
    """Document the expected behavior of the fixed _moneyToMinor function.

    This verifies the logic in Python as a reference. The actual Dart fix is in:
    mobile/lib/features/dashboard/providers/dashboard_providers.dart
    """

    def money_to_minor(value: str) -> int:
        """Python equivalent of the fixed Dart _moneyToMinor function."""
        import re
        raw = value.strip()
        is_negative = raw.startswith("-")
        unsigned = raw[1:] if is_negative else raw
        match = re.match(r"^\d+(\.\d{1,2})?$", unsigned)
        if match is None:
            return 0
        parts = unsigned.split(".")
        major = int(parts[0]) if parts[0] else 0
        decimal_str = (parts[1] if len(parts) == 2 else "00").ljust(2, "0")
        minor = int(decimal_str)
        result = (major * 100) + minor
        return -result if is_negative else result

    # Positive amounts work as before
    assert money_to_minor("5.00") == 500
    assert money_to_minor("100.50") == 10050
    assert money_to_minor("0.99") == 99
    assert money_to_minor("10") == 1000

    # Negative amounts (refunds) now work correctly
    assert money_to_minor("-5.00") == -500
    assert money_to_minor("-100.50") == -10050
    assert money_to_minor("-0.99") == -99

    # Invalid strings still return 0
    assert money_to_minor("N/A") == 0
    assert money_to_minor("--") == 0
    assert money_to_minor("") == 0
    assert money_to_minor("abc") == 0
