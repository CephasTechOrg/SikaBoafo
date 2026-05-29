"""OTP request endpoint rate limit integration test."""

from __future__ import annotations

from collections.abc import Generator
from unittest.mock import patch

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_db
from app.core.config import Settings, get_settings
from app.main import app
from app.models.otp_code import OtpCode
from app.models.otp_send_throttle import OtpSendThrottle
from app.services.otp_provider import GenerateOtpResult


def test_otp_request_returns_429_after_send_limit() -> None:
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    OtpSendThrottle.__table__.create(bind=engine)
    OtpCode.__table__.create(bind=engine)
    session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    def _override_get_db() -> Generator[Session, None, None]:
        with session_local() as db:
            yield db

    def _override_settings() -> Settings:
        return Settings(
            app_env="local",
            database_url="sqlite:///unused.db",
            secret_key="test-secret-key-1234",
            auth_otp_send_max_per_window=2,
            auth_otp_send_window_minutes=15,
        )

    app.dependency_overrides[get_db] = _override_get_db
    app.dependency_overrides[get_settings] = _override_settings
    client = TestClient(app)
    stub_result = GenerateOtpResult(provider_reference="stub", expires_in_minutes=5)
    try:
        with patch(
            "app.services.otp_provider.ArkeselOtpProvider.generate",
            return_value=stub_result,
        ):
            for _ in range(2):
                resp = client.post(
                    "/api/v1/auth/otp/request",
                    json={"phone_number": "0244123456"},
                )
                assert resp.status_code == 200

            blocked = client.post(
                "/api/v1/auth/otp/request",
                json={"phone_number": "0244123456"},
            )
        assert blocked.status_code == 429
        assert "Too many verification code requests" in blocked.json()["detail"]
    finally:
        app.dependency_overrides.clear()
        get_settings.cache_clear()
