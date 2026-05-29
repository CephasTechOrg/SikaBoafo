"""/sync/apply endpoint rate limit integration test (AUTH-08b)."""

from __future__ import annotations

from collections.abc import Generator
from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user, get_db
from app.core.config import Settings, get_settings
from app.main import app
from app.models.sync_apply_throttle import SyncApplyThrottle
from app.models.sync_operation import SyncOperation
from app.models.user import User


def test_sync_apply_returns_429_after_request_limit() -> None:
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SyncApplyThrottle.__table__.create(bind=engine)
    SyncOperation.__table__.create(bind=engine)
    session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    user = User(phone_number="233244123456")
    user.id = uuid4()
    user.is_active = True

    def _override_get_db() -> Generator[Session, None, None]:
        with session_local() as db:
            yield db

    def _override_current_user() -> User:
        return user

    def _override_settings() -> Settings:
        return Settings(
            app_env="local",
            database_url="sqlite:///unused.db",
            secret_key="test-secret-key-1234",
            sync_apply_max_per_window=2,
            sync_apply_window_minutes=5,
        )

    app.dependency_overrides[get_db] = _override_get_db
    app.dependency_overrides[get_current_user] = _override_current_user
    app.dependency_overrides[get_settings] = _override_settings
    client = TestClient(app)
    try:
        payload = {
            "device_id": "device-01",
            "operations": [
                {
                    "local_operation_id": "op-00000001",
                    "entity_type": "unsupported_entity",
                    "action_type": "noop",
                    "payload": {},
                }
            ],
        }
        for _ in range(2):
            resp = client.post("/api/v1/sync/apply", json=payload)
            assert resp.status_code == 200

        blocked = client.post("/api/v1/sync/apply", json=payload)
        assert blocked.status_code == 429
        assert "Too many sync requests" in blocked.json()["detail"]
    finally:
        app.dependency_overrides.clear()
        get_settings.cache_clear()
