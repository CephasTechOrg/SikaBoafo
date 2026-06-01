"""PIN login lockout guard tests."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import Settings
from app.models.pin_login_lockout import PinLoginLockout
from app.services.pin_login_guard import PinLoginGuard, PinLoginLockedError


def _session_local() -> sessionmaker[Session]:
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    PinLoginLockout.__table__.create(bind=engine)
    return sessionmaker(autocommit=False, autoflush=False, bind=engine)


def test_lockout_after_max_failed_attempts() -> None:
    settings = Settings(
        app_env="local",
        secret_key="test-secret-key-1234",
        auth_pin_max_attempts=3,
        auth_pin_lockout_minutes=10,
    )
    session_local = _session_local()
    phone = "233244123456"

    with session_local() as db:
        guard = PinLoginGuard(db=db, settings=settings)
        for _ in range(3):
            guard.record_failure(phone_number=phone)
        db.commit()

        row = db.scalar(select(PinLoginLockout).where(PinLoginLockout.phone_number == phone))
        assert row is not None
        assert row.locked_until is not None

        with pytest.raises(PinLoginLockedError):
            guard.assert_can_attempt(phone_number=phone)


def test_success_clears_lockout_row() -> None:
    settings = Settings(
        app_env="local",
        secret_key="test-secret-key-1234",
        auth_pin_max_attempts=5,
        auth_pin_lockout_minutes=15,
    )
    session_local = _session_local()
    phone = "233244123457"

    with session_local() as db:
        guard = PinLoginGuard(db=db, settings=settings)
        guard.record_failure(phone_number=phone)
        db.commit()
        guard.clear_failures(phone_number=phone)
        db.commit()
        lockout = db.scalar(
            select(PinLoginLockout).where(PinLoginLockout.phone_number == phone)
        )
        assert lockout is None


def test_expired_lockout_allows_retry() -> None:
    settings = Settings(
        app_env="local",
        secret_key="test-secret-key-1234",
        auth_pin_max_attempts=5,
        auth_pin_lockout_minutes=15,
    )
    session_local = _session_local()
    phone = "233244123458"

    with session_local() as db:
        db.add(
            PinLoginLockout(
                id=uuid4(),
                phone_number=phone,
                failed_attempt_count=0,
                locked_until=datetime.now(tz=UTC) - timedelta(minutes=1),
            )
        )
        db.commit()

        guard = PinLoginGuard(db=db, settings=settings)
        guard.assert_can_attempt(phone_number=phone)
