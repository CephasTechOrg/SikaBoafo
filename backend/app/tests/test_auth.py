"""Auth tests (OTP request/verify + service behavior)."""

from __future__ import annotations

from collections.abc import Generator
from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy.sql import Select

from app.api.deps import get_current_user, get_db
from app.core.config import Settings, get_settings
from app.core.constants import AUTH_TOKEN_TYPE_ACCESS, AUTH_TOKEN_TYPE_REFRESH
from app.core.security import create_session_token
from app.main import app
from app.models.merchant import Merchant
from app.models.store import Store
from app.models.user import User
from app.services.auth_service import AuthService


class _FakeDbSession:
    def __init__(self) -> None:
        self.users_by_phone: dict[str, User] = {}
        self.users_by_id: dict[object, User] = {}
        self.merchants_by_owner: dict[object, Merchant] = {}
        self.stores_by_merchant: dict[object, Store] = {}

    def scalar(self, statement: object):
        if not isinstance(statement, Select):
            return None
        params = statement.compile().params
        table = statement.column_descriptions[0]["entity"].__tablename__
        phone_number = params.get("phone_number_1")
        if table == "users":
            if isinstance(phone_number, str):
                return self.users_by_phone.get(phone_number)
            user_id = params.get("id_1")
            return self.users_by_id.get(user_id)
        if table == "merchants":
            return self.merchants_by_owner.get(params.get("owner_user_id_1"))
        if table == "stores":
            return self.stores_by_merchant.get(params.get("merchant_id_1"))
        return None

    def add(self, entity) -> None:
        if isinstance(entity, User):
            self.users_by_phone[entity.phone_number] = entity
            if getattr(entity, "id", None) is not None:
                self.users_by_id[entity.id] = entity
            return
        if isinstance(entity, Merchant):
            if getattr(entity, "id", None) is None:
                entity.id = uuid4()
            self.merchants_by_owner[entity.owner_user_id] = entity
            return
        if isinstance(entity, Store):
            if getattr(entity, "id", None) is None:
                entity.id = uuid4()
            self.stores_by_merchant[entity.merchant_id] = entity

    def commit(self) -> None:
        return None

    def flush(self) -> None:
        return None

    def refresh(self, entity) -> None:
        if getattr(entity, "id", None) is None:
            entity.id = uuid4()
        if isinstance(entity, User):
            self.users_by_phone[entity.phone_number] = entity
            self.users_by_id[entity.id] = entity

    def close(self) -> None:
        return None


class _OtpProviderDouble:
    def __init__(self) -> None:
        self.last_requested_phone: str | None = None
        self.last_verified_phone: str | None = None
        self.last_verified_code: str | None = None

    def generate(self, *, phone_number: str):  # type: ignore[no-untyped-def]
        self.last_requested_phone = phone_number
        from app.services.otp_provider import GenerateOtpResult

        return GenerateOtpResult(provider_reference="unit-test", expires_in_minutes=5)

    def verify(self, *, phone_number: str, code: str) -> None:
        self.last_verified_phone = phone_number
        self.last_verified_code = code


def _test_settings() -> Settings:
    return Settings(
        app_env="local",
        database_url="sqlite:///unused.db",
        secret_key="test-secret-key-1234",
        auth_mock_otp_code="123456",
    )


def test_auth_service_verify_otp_creates_user_and_tokens() -> None:
    fake_db = _FakeDbSession()
    otp = _OtpProviderDouble()
    settings = _test_settings()
    service = AuthService(db=fake_db, settings=settings, otp_provider=otp)

    result = service.verify_otp(phone_number="0244123456", code="123456")

    assert result.is_new_user is True
    assert result.phone_number == "233244123456"
    assert result.access_token
    assert result.refresh_token
    assert result.onboarding_required is True
    assert otp.last_verified_phone == "233244123456"
    assert otp.last_verified_code == "123456"


def test_auth_endpoints_request_and_verify_with_mock_otp() -> None:
    fake_db = _FakeDbSession()

    def _override_get_db() -> Generator[_FakeDbSession, None, None]:
        yield fake_db

    def _override_get_settings() -> Settings:
        return _test_settings()

    app.dependency_overrides[get_db] = _override_get_db
    app.dependency_overrides[get_settings] = _override_get_settings
    client = TestClient(app)
    try:
        request_resp = client.post(
            "/api/v1/auth/otp/request",
            json={"phone_number": "0244123456"},
        )
        assert request_resp.status_code == 200
        assert request_resp.json()["status"] == "otp_sent"

        verify_resp = client.post(
            "/api/v1/auth/otp/verify",
            json={"phone_number": "0244123456", "code": "123456"},
        )
        assert verify_resp.status_code == 200
        body = verify_resp.json()
        assert body["token_type"] == "bearer"
        assert body["phone_number"] == "233244123456"
        assert body["is_new_user"] is True
        assert body["access_token"]
        assert body["refresh_token"]
        assert body["onboarding_required"] is True
    finally:
        app.dependency_overrides.clear()


def test_auth_verify_rejects_wrong_code_with_mock_otp() -> None:
    fake_db = _FakeDbSession()

    def _override_get_db() -> Generator[_FakeDbSession, None, None]:
        yield fake_db

    def _override_get_settings() -> Settings:
        return _test_settings()

    app.dependency_overrides[get_db] = _override_get_db
    app.dependency_overrides[get_settings] = _override_get_settings
    client = TestClient(app)
    try:
        resp = client.post(
            "/api/v1/auth/otp/verify",
            json={"phone_number": "0244123456", "code": "000000"},
        )
        assert resp.status_code == 401
        assert resp.json()["detail"] == "Invalid verification code."
    finally:
        app.dependency_overrides.clear()


def test_onboarding_complete_creates_merchant_and_default_store() -> None:
    fake_db = _FakeDbSession()
    user = User(phone_number="233244123456")
    user.id = uuid4()
    user.is_active = True
    fake_db.add(user)

    def _override_get_db() -> Generator[_FakeDbSession, None, None]:
        yield fake_db

    def _override_get_current_user() -> User:
        return user

    app.dependency_overrides[get_db] = _override_get_db
    app.dependency_overrides[get_current_user] = _override_get_current_user
    client = TestClient(app)
    try:
        resp = client.post(
            "/api/v1/auth/onboarding/complete",
            json={
                "business_name": "Ama Ventures",
                "business_type": "Provision Shop",
            },
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["business_name"] == "Ama Ventures"
        assert body["business_type"] == "Provision Shop"
        assert body["onboarding_completed"] is True
        assert body["merchant_id"]
        assert body["store_id"]
    finally:
        app.dependency_overrides.clear()


def test_onboarding_rejects_refresh_token() -> None:
    fake_db = _FakeDbSession()
    user = User(phone_number="233244123456")
    user.id = uuid4()
    user.is_active = True
    fake_db.add(user)

    def _override_get_db() -> Generator[_FakeDbSession, None, None]:
        yield fake_db

    app.dependency_overrides[get_db] = _override_get_db
    client = TestClient(app)
    try:
        refresh_token = create_session_token(
            user_id=user.id,
            phone_number=user.phone_number,
            token_type=AUTH_TOKEN_TYPE_REFRESH,
            expires_in_minutes=60,
        )
        resp = client.post(
            "/api/v1/auth/onboarding/complete",
            json={"business_name": "Ama Ventures"},
            headers={"Authorization": f"Bearer {refresh_token}"},
        )
        assert resp.status_code == 401

        access_token = create_session_token(
            user_id=user.id,
            phone_number=user.phone_number,
            token_type=AUTH_TOKEN_TYPE_ACCESS,
            expires_in_minutes=60,
        )
        success_resp = client.post(
            "/api/v1/auth/onboarding/complete",
            json={"business_name": "Ama Ventures"},
            headers={"Authorization": f"Bearer {access_token}"},
        )
        assert success_resp.status_code == 200
    finally:
        app.dependency_overrides.clear()
