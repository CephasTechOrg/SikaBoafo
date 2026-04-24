"""Payments initiate API tests."""

from __future__ import annotations

import os
from collections.abc import Generator
from datetime import UTC, datetime
from decimal import Decimal
from unittest.mock import patch
from uuid import UUID, uuid4

from cryptography.fernet import Fernet
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_user, get_db
from app.core.config import get_settings
from app.core.constants import (
    PAYMENT_PROVIDER_PAYSTACK,
    PAYMENT_STATUS_PENDING_PROVIDER,
    PAYMENT_STATUS_RECORDED,
    PAYSTACK_MODE_TEST,
    SALE_STATUS_RECORDED,
    SALE_STATUS_VOIDED,
)
from app.core.crypto import encrypt_text
from app.integrations.paystack.client import PaystackInitializeResult
from app.main import app
from app.models.audit_log import AuditLog
from app.models.customer import Customer
from app.models.item import Item
from app.models.merchant import Merchant
from app.models.payment import Payment
from app.models.payment_provider_connection import PaymentProviderConnection
from app.models.receivable import Receivable, ReceivablePayment
from app.models.sale import Sale, SaleItem
from app.models.store import Store
from app.models.user import User


def _configure_env(*, app_env: str = "local", test_secret: str | None = None) -> dict[str, str | None]:
    original = {
        "APP_ENV": os.environ.get("APP_ENV"),
        "PAYMENT_CONFIG_ENCRYPTION_KEY": os.environ.get("PAYMENT_CONFIG_ENCRYPTION_KEY"),
        "PAYSTACK_SECRET_KEY_TEST": os.environ.get("PAYSTACK_SECRET_KEY_TEST"),
    }
    os.environ["APP_ENV"] = app_env
    os.environ["PAYMENT_CONFIG_ENCRYPTION_KEY"] = Fernet.generate_key().decode("utf-8")
    if test_secret is None:
        os.environ.pop("PAYSTACK_SECRET_KEY_TEST", None)
    else:
        os.environ["PAYSTACK_SECRET_KEY_TEST"] = test_secret
    get_settings.cache_clear()
    return original


def _restore_env(original: dict[str, str | None]) -> None:
    for key, value in original.items():
        if value is None:
            os.environ.pop(key, None)
        else:
            os.environ[key] = value
    get_settings.cache_clear()


def _build_sqlite_test_stack(
    *,
    is_paystack_connected: bool = True,
    receivable_status: str = "open",
    sale_status: str = SALE_STATUS_RECORDED,
    sale_payment_status: str = PAYMENT_STATUS_RECORDED,
    with_merchant_secret: bool = True,
) -> tuple[TestClient, sessionmaker[Session], UUID, UUID]:
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
        Customer.__table__,
        Receivable.__table__,
        ReceivablePayment.__table__,
        Sale.__table__,
        SaleItem.__table__,
        PaymentProviderConnection.__table__,
        Payment.__table__,
        AuditLog.__table__,
    ):
        table.create(bind=engine)

    session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    user_id = uuid4()
    receivable_id = uuid4()
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
    store = Store(
        merchant_id=merchant.id,
        name="Main Store",
        location="Madina",
        timezone="Africa/Accra",
        is_default=True,
    )
    store.id = uuid4()
    customer = Customer(
        store_id=store.id,
        name="Kofi Mensah",
        phone_number="0244123456",
        email="kofi@example.com",
    )
    customer.id = uuid4()
    receivable = Receivable(
        store_id=store.id,
        customer_id=customer.id,
        original_amount=Decimal("120.00"),
        outstanding_amount=Decimal("120.00"),
        status=receivable_status,
    )
    receivable.id = receivable_id
    sale = Sale(
        store_id=store.id,
        customer_id=customer.id,
        total_amount=Decimal("85.00"),
        payment_method_label="mobile_money",
        payment_status=sale_payment_status,
        sale_status=sale_status,
        cashier_id=user.id,
    )
    sale.id = uuid4()
    sale_id = sale.id
    secret_encrypted = None
    verified_at = None
    if with_merchant_secret:
        settings = get_settings()
        secret_encrypted = encrypt_text(
            plaintext="sk_test_unit_123",
            key=settings.payment_config_encryption_key,
        )
        verified_at = datetime.now(tz=UTC)
    connection = PaymentProviderConnection(
        merchant_id=merchant.id,
        provider=PAYMENT_PROVIDER_PAYSTACK,
        mode=PAYSTACK_MODE_TEST,
        account_label="Main Account",
        test_public_key="pk_test_abcdefghijklmnop",
        test_secret_key_encrypted=secret_encrypted,
        test_secret_key_last4="_123" if with_merchant_secret else None,
        test_verified_at=verified_at,
        is_connected=is_paystack_connected,
    )
    connection.id = uuid4()

    with session_local() as db:
        db.add(user)
        db.add(merchant)
        db.add(store)
        db.add(customer)
        db.add(receivable)
        db.add(sale)
        db.add(connection)
        db.commit()

    current_user = User(phone_number=user_phone)
    current_user.id = user_id
    current_user.is_active = True

    def _override_get_db() -> Generator[Session, None, None]:
        with session_local() as db:
            yield db

    def _override_get_current_user() -> User:
        return current_user

    app.dependency_overrides[get_db] = _override_get_db
    app.dependency_overrides[get_current_user] = _override_get_current_user
    return TestClient(app), session_local, receivable_id, sale_id


def test_initiate_receivable_payment_uses_merchant_secret_and_creates_payment() -> None:
    env = _configure_env()
    client, session_local, receivable_id, _ = _build_sqlite_test_stack()
    try:
        with patch(
            "app.integrations.paystack.client.PaystackClient.initialize_transaction",
            return_value=PaystackInitializeResult(
                authorization_url="https://checkout.paystack.com/test-link-123",
                access_code="ACCESS_123",
                reference="PSK_REF_12345",
                raw_payload={"status": True, "data": {"reference": "PSK_REF_12345"}},
            ),
        ) as mocked_initialize:
            response = client.post(
                "/api/v1/payments/initiate",
                json={"receivable_id": str(receivable_id)},
            )
        assert response.status_code == 200
        body = response.json()
        assert body["provider_reference"] == "PSK_REF_12345"

        kwargs = mocked_initialize.call_args.kwargs
        assert kwargs["secret_key"] == "sk_test_unit_123"

        with session_local() as db:
            payment = db.scalar(
                select(Payment).where(Payment.provider_reference == "PSK_REF_12345")
            )
            assert payment is not None
            assert payment.internal_reference is not None
            assert payment.provider_mode == "test"
            assert payment.merchant_id is not None
    finally:
        _restore_env(env)
        app.dependency_overrides.clear()


def test_initiate_receivable_payment_requires_connected_paystack() -> None:
    env = _configure_env()
    client, _, receivable_id, _ = _build_sqlite_test_stack(is_paystack_connected=False)
    try:
        response = client.post(
            "/api/v1/payments/initiate",
            json={"receivable_id": str(receivable_id)},
        )
        assert response.status_code == 409
        assert "not connected" in response.json()["detail"].lower()
    finally:
        _restore_env(env)
        app.dependency_overrides.clear()


def test_initiate_receivable_payment_rejects_terminal_status() -> None:
    env = _configure_env()
    client, _, receivable_id, _ = _build_sqlite_test_stack(receivable_status="settled")
    try:
        response = client.post(
            "/api/v1/payments/initiate",
            json={"receivable_id": str(receivable_id)},
        )
        assert response.status_code == 409
        assert "settled debt" in response.json()["detail"].lower()
    finally:
        _restore_env(env)
        app.dependency_overrides.clear()


def test_initiate_sale_payment_creates_payment_and_sets_pending_provider() -> None:
    env = _configure_env()
    client, session_local, _, sale_id = _build_sqlite_test_stack()
    try:
        with patch(
            "app.integrations.paystack.client.PaystackClient.initialize_transaction",
            return_value=PaystackInitializeResult(
                authorization_url="https://checkout.paystack.com/sale-link-123",
                access_code="ACCESS_SALE_123",
                reference="PSK_SALE_REF_12345",
                raw_payload={"status": True, "data": {"reference": "PSK_SALE_REF_12345"}},
            ),
        ) as mocked_initialize:
            response = client.post(
                "/api/v1/payments/initiate-sale",
                json={"sale_id": str(sale_id)},
            )
        assert response.status_code == 200
        assert mocked_initialize.call_args.kwargs["secret_key"] == "sk_test_unit_123"

        with session_local() as db:
            payment = db.scalar(
                select(Payment).where(Payment.provider_reference == "PSK_SALE_REF_12345")
            )
            assert payment is not None
            assert payment.provider_mode == "test"
            assert payment.internal_reference is not None

            sale = db.scalar(select(Sale).where(Sale.id == sale_id))
            assert sale is not None
            assert sale.payment_status == PAYMENT_STATUS_PENDING_PROVIDER
    finally:
        _restore_env(env)
        app.dependency_overrides.clear()


def test_initiate_sale_payment_rejects_voided_sale() -> None:
    env = _configure_env()
    client, _, _, sale_id = _build_sqlite_test_stack(sale_status=SALE_STATUS_VOIDED)
    try:
        response = client.post(
            "/api/v1/payments/initiate-sale",
            json={"sale_id": str(sale_id)},
        )
        assert response.status_code == 409
        assert "voided sale" in response.json()["detail"].lower()
    finally:
        _restore_env(env)
        app.dependency_overrides.clear()


def test_production_rejects_when_selected_mode_has_no_merchant_secret() -> None:
    env = _configure_env(app_env="production")
    client, _, receivable_id, _ = _build_sqlite_test_stack(with_merchant_secret=False)
    try:
        response = client.post(
            "/api/v1/payments/initiate",
            json={"receivable_id": str(receivable_id)},
        )
        assert response.status_code == 503
        assert "merchant-specific paystack secret is missing" in response.json()["detail"].lower()
    finally:
        _restore_env(env)
        app.dependency_overrides.clear()


def test_non_production_falls_back_to_env_secret_when_merchant_secret_missing() -> None:
    env = _configure_env(app_env="local", test_secret="sk_test_fallback_123")
    client, _, receivable_id, _ = _build_sqlite_test_stack(with_merchant_secret=False)
    try:
        with patch(
            "app.integrations.paystack.client.PaystackClient.initialize_transaction",
            return_value=PaystackInitializeResult(
                authorization_url="https://checkout.paystack.com/test-link-123",
                access_code="ACCESS_123",
                reference="PSK_REF_12345",
                raw_payload={"status": True, "data": {"reference": "PSK_REF_12345"}},
            ),
        ) as mocked_initialize:
            response = client.post(
                "/api/v1/payments/initiate",
                json={"receivable_id": str(receivable_id)},
            )
        assert response.status_code == 200
        assert mocked_initialize.call_args.kwargs["secret_key"] == "sk_test_fallback_123"
    finally:
        _restore_env(env)
        app.dependency_overrides.clear()
