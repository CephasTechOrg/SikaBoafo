"""Payment settings API tests for merchant-owned credentials."""

from __future__ import annotations

import os
from collections.abc import Generator
from unittest.mock import patch
from uuid import uuid4

from cryptography.fernet import Fernet
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user, get_db
from app.core.config import get_settings
from app.core.constants import USER_ROLE_MERCHANT_OWNER
from app.integrations.paystack.client import PaystackClientError
from app.main import app
from app.models.item import Item
from app.models.merchant import Merchant
from app.models.payment_provider_connection import PaymentProviderConnection
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
        PaymentProviderConnection.__table__,
    ):
        table.create(bind=engine)

    session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    user_id = uuid4()
    user_phone = "233244123456"
    user = User(phone_number=user_phone)
    user.id = user_id
    user.is_active = True
    merchant = Merchant(
        owner_user_id=user.id,
        business_name="Ama Ventures",
        business_type="Provision Shop",
    )
    merchant.id = uuid4()
    with session_local() as db:
        db.add(user)
        db.add(merchant)
        db.commit()

    current_user = User(phone_number=user_phone)
    current_user.id = user_id
    current_user.is_active = True
    current_user.role = USER_ROLE_MERCHANT_OWNER

    def _override_get_db() -> Generator[Session, None, None]:
        with session_local() as db:
            yield db

    def _override_get_current_user() -> User:
        return current_user

    app.dependency_overrides[get_db] = _override_get_db
    app.dependency_overrides[get_current_user] = _override_get_current_user
    return TestClient(app), session_local, current_user


def _configure_encryption_env() -> str | None:
    original = os.environ.get("PAYMENT_CONFIG_ENCRYPTION_KEY")
    os.environ["PAYMENT_CONFIG_ENCRYPTION_KEY"] = Fernet.generate_key().decode("utf-8")
    get_settings.cache_clear()
    return original


def _restore_encryption_env(original: str | None) -> None:
    if original is None:
        os.environ.pop("PAYMENT_CONFIG_ENCRYPTION_KEY", None)
    else:
        os.environ["PAYMENT_CONFIG_ENCRYPTION_KEY"] = original
    get_settings.cache_clear()


def test_get_paystack_connection_defaults_to_disconnected() -> None:
    client, _, _ = _build_sqlite_test_stack()
    try:
        response = client.get("/api/v1/payments/paystack/connection")
        assert response.status_code == 200
        body = response.json()
        assert body["provider"] == "paystack"
        assert body["is_connected"] is False
        assert body["mode"] == "test"
        assert body["test"]["configured"] is False
        assert body["live"]["configured"] is False
    finally:
        app.dependency_overrides.clear()


def test_upsert_paystack_connection_verifies_and_encrypts_secret() -> None:
    client, session_local, _ = _build_sqlite_test_stack()
    original_encryption = _configure_encryption_env()
    try:
        with patch(
            "app.integrations.paystack.client.PaystackClient.fetch_payment_session_timeout",
            return_value=30,
        ) as mocked_verify:
            upsert = client.put(
                "/api/v1/payments/paystack/connection",
                json={
                    "public_key": "pk_test_abcdefgh12345678",
                    "secret_key": "sk_test_abcdefgh12345678",
                    "mode": "test",
                    "account_label": "Main Paystack Account",
                },
            )
        assert upsert.status_code == 200
        body = upsert.json()
        assert body["is_connected"] is True
        assert body["mode"] == "test"
        assert body["account_label"] == "Main Paystack Account"
        assert body["test"]["configured"] is True
        assert body["test"]["public_key_masked"].startswith("pk_tes")
        assert body["test"]["secret_key_masked"] == "sk_test_...5678"
        assert body["live"]["configured"] is False
        assert mocked_verify.call_count == 1

        with session_local() as db:
            row = db.scalar(select(PaymentProviderConnection))
            assert row is not None
            assert row.test_secret_key_encrypted is not None
            assert row.test_secret_key_encrypted != "sk_test_abcdefgh12345678"
            assert row.test_verified_at is not None
    finally:
        _restore_encryption_env(original_encryption)
        app.dependency_overrides.clear()


def test_failed_verify_does_not_overwrite_existing_working_secret() -> None:
    client, session_local, _ = _build_sqlite_test_stack()
    original_encryption = _configure_encryption_env()
    try:
        with patch(
            "app.integrations.paystack.client.PaystackClient.fetch_payment_session_timeout",
            return_value=30,
        ):
            first = client.put(
                "/api/v1/payments/paystack/connection",
                json={
                    "secret_key": "sk_test_original_12345678",
                    "mode": "test",
                },
            )
        assert first.status_code == 200

        with session_local() as db:
            before = db.scalar(select(PaymentProviderConnection))
            assert before is not None
            encrypted_before = before.test_secret_key_encrypted
            verified_before = before.test_verified_at

        with patch(
            "app.integrations.paystack.client.PaystackClient.fetch_payment_session_timeout",
            side_effect=PaystackClientError("provider down"),
        ):
            second = client.put(
                "/api/v1/payments/paystack/connection",
                json={
                    "secret_key": "sk_test_badbadbad5678",
                    "mode": "test",
                    "account_label": "Attempted rotation",
                },
            )
        assert second.status_code == 502

        with session_local() as db:
            after = db.scalar(select(PaymentProviderConnection))
            assert after is not None
            assert after.test_secret_key_encrypted == encrypted_before
            assert after.test_verified_at == verified_before
            assert after.account_label is None
    finally:
        _restore_encryption_env(original_encryption)
        app.dependency_overrides.clear()


def test_switching_to_verified_live_mode_does_not_require_secret_reentry() -> None:
    client, _, _ = _build_sqlite_test_stack()
    original_encryption = _configure_encryption_env()
    try:
        with patch(
            "app.integrations.paystack.client.PaystackClient.fetch_payment_session_timeout",
            return_value=30,
        ):
            first = client.put(
                "/api/v1/payments/paystack/connection",
                json={
                    "secret_key": "sk_test_abcdefgh12345678",
                    "mode": "test",
                },
            )
            second = client.put(
                "/api/v1/payments/paystack/connection",
                json={
                    "secret_key": "sk_live_abcdefgh12345678",
                    "mode": "live",
                    "public_key": "pk_live_abcdefgh12345678",
                },
            )
        assert first.status_code == 200
        assert second.status_code == 200

        switch = client.put(
            "/api/v1/payments/paystack/connection",
            json={
                "mode": "test",
                "account_label": "Main Account",
            },
        )
        assert switch.status_code == 200
        body = switch.json()
        assert body["mode"] == "test"
        assert body["is_connected"] is True
        assert body["test"]["configured"] is True
        assert body["live"]["configured"] is True
    finally:
        _restore_encryption_env(original_encryption)
        app.dependency_overrides.clear()


def test_disconnect_paystack_connection_clears_both_modes() -> None:
    client, session_local, _ = _build_sqlite_test_stack()
    original_encryption = _configure_encryption_env()
    try:
        with patch(
            "app.integrations.paystack.client.PaystackClient.fetch_payment_session_timeout",
            return_value=30,
        ):
            client.put(
                "/api/v1/payments/paystack/connection",
                json={
                    "secret_key": "sk_test_abcdefgh12345678",
                    "mode": "test",
                },
            )
            client.put(
                "/api/v1/payments/paystack/connection",
                json={
                    "secret_key": "sk_live_abcdefgh12345678",
                    "mode": "live",
                },
            )

        response = client.delete("/api/v1/payments/paystack/connection")
        assert response.status_code == 200
        body = response.json()
        assert body["is_connected"] is False
        assert body["test"]["configured"] is False
        assert body["live"]["configured"] is False

        with session_local() as db:
            row = db.scalar(select(PaymentProviderConnection))
            assert row is not None
            assert row.test_secret_key_encrypted is None
            assert row.live_secret_key_encrypted is None
            assert row.is_connected is False
    finally:
        _restore_encryption_env(original_encryption)
        app.dependency_overrides.clear()
