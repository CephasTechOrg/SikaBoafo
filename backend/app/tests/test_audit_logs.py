"""Audit log list API tests."""

from __future__ import annotations

from collections.abc import Callable, Generator
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user, get_db
from app.core.constants import USER_ROLE_CASHIER, USER_ROLE_MERCHANT_OWNER
from app.main import app
from app.models.audit_log import AuditLog
from app.models.item import Item, ItemVariant
from app.models.merchant import Merchant
from app.models.store import Store
from app.models.user import User


def _build_audit_test_stack() -> tuple[
    TestClient,
    sessionmaker[Session],
    User,
    User,
    UUID,
    UUID,
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
        Item.__table__,
        ItemVariant.__table__,
        AuditLog.__table__,
    ):
        table.create(bind=engine)

    session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    owner_id = uuid4()
    staff_id = uuid4()
    merchant_id = uuid4()
    other_merchant_id = uuid4()
    store_id = uuid4()
    owner = User(phone_number="233244123456", role=USER_ROLE_MERCHANT_OWNER)
    owner.id = owner_id
    owner.is_active = True
    owner.full_name = "Ama Owner"
    staff = User(
        phone_number="233244123457",
        role=USER_ROLE_CASHIER,
        merchant_id=merchant_id,
    )
    staff.id = staff_id
    staff.is_active = True
    merchant = Merchant(
        owner_user_id=owner_id,
        business_name="Ama Ventures",
        business_type="Provision Shop",
    )
    merchant.id = merchant_id
    other_merchant = Merchant(
        owner_user_id=uuid4(),
        business_name="Other Shop",
        business_type="Retail",
    )
    other_merchant.id = other_merchant_id
    store = Store(
        merchant_id=merchant_id,
        name="Main Store",
        location="Madina",
        timezone="Africa/Accra",
        is_default=True,
    )
    store.id = store_id
    with session_local() as db:
        db.add_all([owner, staff, merchant, other_merchant, store])
        db.commit()

    current_user = {
        "id": owner_id,
        "role_override": USER_ROLE_MERCHANT_OWNER,
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
    return (
        TestClient(app),
        session_local,
        current_owner,
        current_staff,
        merchant_id,
        other_merchant_id,
        owner_id,
        _set_current_user,
    )


def _insert_audit_log(
    session_local: sessionmaker[Session],
    *,
    business_id: UUID,
    actor_user_id: UUID | None,
    action: str,
    created_at: datetime,
) -> UUID:
    with session_local() as db:
        row = AuditLog(
            actor_user_id=actor_user_id,
            business_id=business_id,
            action=action,
            entity_type="sale",
            entity_id=uuid4(),
            meta={"label": action},
            created_at=created_at,
        )
        row.id = uuid4()
        db.add(row)
        db.commit()
        return row.id


def test_owner_lists_only_own_business_audit_logs() -> None:
    (
        client,
        session_local,
        _owner,
        _staff,
        merchant_id,
        other_merchant_id,
        owner_id,
        _set_current_user,
    ) = _build_audit_test_stack()
    try:
        now = datetime(2026, 5, 18, 12, tzinfo=UTC)
        own_log_id = _insert_audit_log(
            session_local,
            business_id=merchant_id,
            actor_user_id=owner_id,
            action="sale.voided",
            created_at=now,
        )
        _insert_audit_log(
            session_local,
            business_id=other_merchant_id,
            actor_user_id=None,
            action="sale.voided",
            created_at=now + timedelta(minutes=1),
        )

        response = client.get("/api/v1/audit-logs")

        assert response.status_code == 200
        body = response.json()
        assert [item["audit_log_id"] for item in body["items"]] == [str(own_log_id)]
        assert body["items"][0]["actor_label"] == "Ama Owner"
    finally:
        app.dependency_overrides.clear()


def test_staff_cannot_list_audit_logs() -> None:
    client, _, _owner, staff, *_rest = _build_audit_test_stack()
    set_current_user = _rest[-1]
    try:
        set_current_user(staff)
        response = client.get("/api/v1/audit-logs")
        assert response.status_code == 403
    finally:
        app.dependency_overrides.clear()


def test_audit_logs_filter_by_action() -> None:
    client, session_local, _owner, _staff, merchant_id, _, owner_id, _ = _build_audit_test_stack()
    try:
        now = datetime(2026, 5, 18, 12, tzinfo=UTC)
        expected_id = _insert_audit_log(
            session_local,
            business_id=merchant_id,
            actor_user_id=owner_id,
            action="sale.voided",
            created_at=now,
        )
        _insert_audit_log(
            session_local,
            business_id=merchant_id,
            actor_user_id=owner_id,
            action="receivable.cancelled",
            created_at=now + timedelta(minutes=1),
        )

        response = client.get("/api/v1/audit-logs", params={"action": "sale.voided"})

        assert response.status_code == 200
        body = response.json()
        assert [item["audit_log_id"] for item in body["items"]] == [str(expected_id)]
    finally:
        app.dependency_overrides.clear()


def test_audit_logs_cursor_paginates() -> None:
    client, session_local, _owner, _staff, merchant_id, _, owner_id, _ = _build_audit_test_stack()
    try:
        now = datetime(2026, 5, 18, 12, tzinfo=UTC)
        oldest_id = _insert_audit_log(
            session_local,
            business_id=merchant_id,
            actor_user_id=owner_id,
            action="item.deleted",
            created_at=now - timedelta(minutes=2),
        )
        middle_id = _insert_audit_log(
            session_local,
            business_id=merchant_id,
            actor_user_id=owner_id,
            action="receivable.cancelled",
            created_at=now - timedelta(minutes=1),
        )
        newest_id = _insert_audit_log(
            session_local,
            business_id=merchant_id,
            actor_user_id=owner_id,
            action="sale.voided",
            created_at=now,
        )

        first_page = client.get("/api/v1/audit-logs", params={"limit": "2"})
        assert first_page.status_code == 200
        first_body = first_page.json()
        assert [item["audit_log_id"] for item in first_body["items"]] == [
            str(newest_id),
            str(middle_id),
        ]
        assert first_body["next_cursor"] is not None

        second_page = client.get(
            "/api/v1/audit-logs",
            params={"limit": "2", "cursor": first_body["next_cursor"]},
        )
        assert second_page.status_code == 200
        second_body = second_page.json()
        assert [item["audit_log_id"] for item in second_body["items"]] == [str(oldest_id)]
        assert second_body["next_cursor"] is None
    finally:
        app.dependency_overrides.clear()
