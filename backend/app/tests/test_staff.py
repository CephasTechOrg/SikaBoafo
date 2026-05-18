"""Staff management API tests (owner-only)."""

from __future__ import annotations

from collections.abc import Generator
from datetime import UTC, datetime, timedelta
from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user, get_db
from app.core.constants import (
    STAFF_INVITE_STATUS_CANCELLED,
    STAFF_INVITE_STATUS_PENDING,
    USER_ROLE_CASHIER,
    USER_ROLE_MERCHANT_OWNER,
)
from app.main import app
from app.models.merchant import Merchant
from app.models.staff_invite import StaffInvite
from app.models.user import User


def _build_staff_test_stack(
    *,
    role: str = USER_ROLE_MERCHANT_OWNER,
) -> tuple[TestClient, sessionmaker[Session], User, Merchant]:
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    for table in (User.__table__, Merchant.__table__, StaffInvite.__table__):
        table.create(bind=engine)

    session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    user_id = uuid4()
    user = User(phone_number="233244123456", role=role)
    user.id = user_id
    user.is_active = True
    merchant = Merchant(
        owner_user_id=user.id,
        business_name="Test Shop",
        business_type="Retail",
    )
    merchant.id = uuid4()
    with session_local() as db:
        db.add(user)
        db.add(merchant)
        db.commit()

    current_user = User(phone_number=user.phone_number, role=role)
    current_user.id = user_id
    current_user.is_active = True

    def _override_get_db() -> Generator[Session, None, None]:
        with session_local() as db:
            yield db

    def _override_get_current_user() -> User:
        return current_user

    app.dependency_overrides[get_db] = _override_get_db
    app.dependency_overrides[get_current_user] = _override_get_current_user
    return TestClient(app), session_local, current_user, merchant


def test_cancel_invite_marks_cancelled() -> None:
    client, session_local, owner, merchant = _build_staff_test_stack()
    try:
        with session_local() as db:
            invite = StaffInvite(
                merchant_id=merchant.id,
                phone_number="233200000001",
                role=USER_ROLE_CASHIER,
                invited_by_user_id=owner.id,
                status=STAFF_INVITE_STATUS_PENDING,
                expires_at=datetime.now(UTC) + timedelta(days=7),
            )
            invite.id = uuid4()
            db.add(invite)
            db.commit()
            invite_id = invite.id

        response = client.delete(f"/api/v1/staff/invites/{invite_id}")
        assert response.status_code == 200
        body = response.json()
        assert body["status"] == STAFF_INVITE_STATUS_CANCELLED

        with session_local() as db:
            stored = db.get(StaffInvite, invite_id)
            assert stored is not None
            assert stored.status == STAFF_INVITE_STATUS_CANCELLED
    finally:
        app.dependency_overrides.clear()


def test_reactivate_staff_sets_active() -> None:
    client, session_local, owner, merchant = _build_staff_test_stack()
    try:
        staff_id = uuid4()
        with session_local() as db:
            staff = User(
                phone_number="233200000002",
                role=USER_ROLE_CASHIER,
                merchant_id=merchant.id,
            )
            staff.id = staff_id
            staff.is_active = False
            db.add(staff)
            db.commit()

        response = client.patch(f"/api/v1/staff/{staff_id}/reactivate")
        assert response.status_code == 200
        assert response.json()["is_active"] is True

        with session_local() as db:
            stored = db.get(User, staff_id)
            assert stored is not None
            assert stored.is_active is True
    finally:
        app.dependency_overrides.clear()


def test_staff_routes_forbidden_for_cashier() -> None:
    client, _, _, _ = _build_staff_test_stack(role=USER_ROLE_CASHIER)
    try:
        assert client.get("/api/v1/staff").status_code == 403
        assert client.get("/api/v1/staff/invites").status_code == 403
    finally:
        app.dependency_overrides.clear()
