"""OTP SMS send throttle tests."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import Settings
from app.models.otp_send_throttle import OtpSendThrottle
from app.services.otp_send_guard import OtpSendGuard, OtpSendRateLimitedError


def test_blocks_after_max_sends_in_window() -> None:
    settings = Settings(
        app_env="local",
        secret_key="test-secret-key-1234",
        auth_otp_send_max_per_window=3,
        auth_otp_send_window_minutes=15,
    )
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    OtpSendThrottle.__table__.create(bind=engine)
    session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    phone = "233244123456"

    with session_local() as db:
        guard = OtpSendGuard(db=db, settings=settings)
        for _ in range(3):
            guard.record_send(phone_number=phone)
        db.commit()

        with pytest.raises(OtpSendRateLimitedError):
            guard.assert_can_send(phone_number=phone)


def test_new_window_resets_count() -> None:
    settings = Settings(
        app_env="local",
        secret_key="test-secret-key-1234",
        auth_otp_send_max_per_window=2,
        auth_otp_send_window_minutes=15,
    )
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    OtpSendThrottle.__table__.create(bind=engine)
    session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    phone = "233244123457"

    with session_local() as db:
        db.add(
            OtpSendThrottle(
                id=uuid4(),
                phone_number=phone,
                window_started_at=datetime.now(tz=UTC) - timedelta(minutes=20),
                send_count=99,
            )
        )
        db.commit()

        guard = OtpSendGuard(db=db, settings=settings)
        guard.assert_can_send(phone_number=phone)
