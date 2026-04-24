"""Paystack webhook tests (M4 Step 3)."""

from __future__ import annotations

import hashlib
import hmac
import json
import os
from collections.abc import Generator
from decimal import Decimal
from unittest.mock import patch
from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_db
from app.core.config import get_settings
from app.core.constants import (
    PAYMENT_PROVIDER_PAYSTACK,
    PAYMENT_STATUS_PENDING_PROVIDER,
    PAYMENT_STATUS_SUCCEEDED,
    PAYSTACK_MODE_TEST,
    SALE_STATUS_RECORDED,
)
from app.integrations.paystack.client import PaystackVerifyResult
from app.main import app
from app.models.audit_log import AuditLog
from app.models.customer import Customer
from app.models.item import Item
from app.models.merchant import Merchant
from app.models.payment import Payment
from app.models.payment_provider_connection import PaymentProviderConnection
from app.models.payment_webhook_event import PaymentWebhookEvent
from app.models.receivable import Receivable, ReceivablePayment
from app.models.sale import Sale, SaleItem
from app.models.store import Store
from app.models.user import User


def _build_sqlite_test_stack() -> tuple[TestClient, sessionmaker[Session], str]:
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
        PaymentProviderConnection.__table__,
        Payment.__table__,
        PaymentWebhookEvent.__table__,
        AuditLog.__table__,
    ):
        table.create(bind=engine)

    session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    provider_reference = "PSK_REF_WEBHOOK_123"

    owner = User(phone_number="233244123456")
    owner.id = uuid4()
    owner.is_active = True
    merchant = Merchant(
        owner_user_id=owner.id,
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
    )
    customer.id = uuid4()
    receivable = Receivable(
        store_id=store.id,
        customer_id=customer.id,
        original_amount=Decimal("120.00"),
        outstanding_amount=Decimal("120.00"),
        status="open",
        payment_provider_reference=provider_reference,
        payment_link="https://checkout.paystack.com/pending-link",
    )
    receivable.id = uuid4()
    payment = Payment(
        provider=PAYMENT_PROVIDER_PAYSTACK,
        provider_reference=provider_reference,
        amount=Decimal("120.00"),
        currency="GHS",
        status="pending",
    )
    payment.id = uuid4()
    connection = PaymentProviderConnection(
        merchant_id=merchant.id,
        provider=PAYMENT_PROVIDER_PAYSTACK,
        mode=PAYSTACK_MODE_TEST,
        account_label="Main Paystack",
        public_key="pk_test_abcdefghijk",
        is_connected=True,
    )
    connection.id = uuid4()

    with session_local() as db:
        db.add(owner)
        db.add(merchant)
        db.add(store)
        db.add(customer)
        db.add(receivable)
        db.add(payment)
        db.add(connection)
        db.commit()

    def _override_get_db() -> Generator[Session, None, None]:
        with session_local() as db:
            yield db

    app.dependency_overrides[get_db] = _override_get_db
    return TestClient(app), session_local, provider_reference


def _build_sqlite_sale_payment_stack() -> tuple[TestClient, sessionmaker[Session], str]:
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
        PaymentWebhookEvent.__table__,
        AuditLog.__table__,
    ):
        table.create(bind=engine)

    session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    provider_reference = "PSK_REF_SALE_WEBHOOK_123"

    owner = User(phone_number="233244123456")
    owner.id = uuid4()
    owner.is_active = True
    merchant = Merchant(
        owner_user_id=owner.id,
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
    sale = Sale(
        store_id=store.id,
        customer_id=None,
        total_amount=Decimal("85.00"),
        payment_method_label="mobile_money",
        payment_status=PAYMENT_STATUS_PENDING_PROVIDER,
        sale_status=SALE_STATUS_RECORDED,
        cashier_id=owner.id,
    )
    sale.id = uuid4()
    payment = Payment(
        sale_id=sale.id,
        provider=PAYMENT_PROVIDER_PAYSTACK,
        provider_reference=provider_reference,
        amount=Decimal("85.00"),
        currency="GHS",
        status="pending",
    )
    payment.id = uuid4()
    connection = PaymentProviderConnection(
        merchant_id=merchant.id,
        provider=PAYMENT_PROVIDER_PAYSTACK,
        mode=PAYSTACK_MODE_TEST,
        account_label="Main Paystack",
        public_key="pk_test_abcdefghijk",
        is_connected=True,
    )
    connection.id = uuid4()

    with session_local() as db:
        db.add(owner)
        db.add(merchant)
        db.add(store)
        db.add(sale)
        db.add(payment)
        db.add(connection)
        db.commit()

    def _override_get_db() -> Generator[Session, None, None]:
        with session_local() as db:
            yield db

    app.dependency_overrides[get_db] = _override_get_db
    return TestClient(app), session_local, provider_reference


def _body_and_signature(*, reference: str, secret: str) -> tuple[bytes, str]:
    body = json.dumps(
        {
            "event": "charge.success",
            "data": {"reference": reference},
        },
        separators=(",", ":"),
    ).encode("utf-8")
    signature = hmac.new(secret.encode("utf-8"), body, hashlib.sha512).hexdigest()
    return body, signature


def test_paystack_webhook_success_settles_receivable() -> None:
    client, session_local, reference = _build_sqlite_test_stack()
    original_secret = os.environ.get("PAYSTACK_SECRET_KEY_TEST")
    os.environ["PAYSTACK_SECRET_KEY_TEST"] = "sk_test_webhook_123"
    get_settings.cache_clear()
    body, signature = _body_and_signature(
        reference=reference,
        secret="sk_test_webhook_123",
    )
    try:
        with patch(
            "app.integrations.paystack.client.PaystackClient.verify_transaction",
            return_value=PaystackVerifyResult(
                reference=reference,
                status="success",
                amount_kobo=12000,
                paid_at="2026-04-24T12:30:00Z",
                raw_payload={"status": True, "data": {"status": "success"}},
            ),
        ) as mocked_verify:
            response = client.post(
                "/api/v1/webhooks/paystack",
                content=body,
                headers={
                    "x-paystack-signature": signature,
                    "content-type": "application/json",
                },
            )
        assert response.status_code == 200
        assert response.json()["status"] == "processed"
        assert mocked_verify.call_count == 1

        with session_local() as db:
            payment = db.scalar(
                select(Payment).where(Payment.provider_reference == reference)
            )
            assert payment is not None
            assert payment.status == "succeeded"
            assert payment.receivable_payment_id is not None
            assert payment.confirmed_at is not None

            receivable = db.scalar(
                select(Receivable).where(Receivable.payment_provider_reference == reference)
            )
            assert receivable is not None
            assert receivable.status == "settled"
            assert receivable.outstanding_amount == Decimal("0.00")

            repayment_count = db.scalar(select(func.count()).select_from(ReceivablePayment))
            assert repayment_count == 1

            success_audit = db.scalar(
                select(AuditLog).where(AuditLog.action == "payment.succeeded")
            )
            assert success_audit is not None
            webhook_event_count = db.scalar(select(func.count()).select_from(PaymentWebhookEvent))
            assert webhook_event_count == 1
    finally:
        if original_secret is None:
            os.environ.pop("PAYSTACK_SECRET_KEY_TEST", None)
        else:
            os.environ["PAYSTACK_SECRET_KEY_TEST"] = original_secret
        get_settings.cache_clear()
        app.dependency_overrides.clear()


def test_paystack_webhook_duplicate_is_idempotent() -> None:
    client, session_local, reference = _build_sqlite_test_stack()
    original_secret = os.environ.get("PAYSTACK_SECRET_KEY_TEST")
    os.environ["PAYSTACK_SECRET_KEY_TEST"] = "sk_test_webhook_123"
    get_settings.cache_clear()
    body, signature = _body_and_signature(
        reference=reference,
        secret="sk_test_webhook_123",
    )
    try:
        with patch(
            "app.integrations.paystack.client.PaystackClient.verify_transaction",
            return_value=PaystackVerifyResult(
                reference=reference,
                status="success",
                amount_kobo=12000,
                paid_at="2026-04-24T12:35:00Z",
                raw_payload={"status": True, "data": {"status": "success"}},
            ),
        ):
            first = client.post(
                "/api/v1/webhooks/paystack",
                content=body,
                headers={
                    "x-paystack-signature": signature,
                    "content-type": "application/json",
                },
            )
            second = client.post(
                "/api/v1/webhooks/paystack",
                content=body,
                headers={
                    "x-paystack-signature": signature,
                    "content-type": "application/json",
                },
            )
        assert first.status_code == 200
        assert first.json()["status"] == "processed"
        assert second.status_code == 200
        assert second.json()["status"] == "duplicate"

        with session_local() as db:
            repayment_count = db.scalar(select(func.count()).select_from(ReceivablePayment))
            assert repayment_count == 1
            webhook_event_count = db.scalar(select(func.count()).select_from(PaymentWebhookEvent))
            assert webhook_event_count == 1
    finally:
        if original_secret is None:
            os.environ.pop("PAYSTACK_SECRET_KEY_TEST", None)
        else:
            os.environ["PAYSTACK_SECRET_KEY_TEST"] = original_secret
        get_settings.cache_clear()
        app.dependency_overrides.clear()


def test_paystack_webhook_rejects_invalid_signature() -> None:
    client, _, reference = _build_sqlite_test_stack()
    original_secret = os.environ.get("PAYSTACK_SECRET_KEY_TEST")
    os.environ["PAYSTACK_SECRET_KEY_TEST"] = "sk_test_webhook_123"
    get_settings.cache_clear()
    body, _ = _body_and_signature(
        reference=reference,
        secret="sk_test_webhook_123",
    )
    try:
        response = client.post(
            "/api/v1/webhooks/paystack",
            content=body,
            headers={
                "x-paystack-signature": "invalid-signature",
                "content-type": "application/json",
            },
        )
        assert response.status_code == 401
    finally:
        if original_secret is None:
            os.environ.pop("PAYSTACK_SECRET_KEY_TEST", None)
        else:
            os.environ["PAYSTACK_SECRET_KEY_TEST"] = original_secret
        get_settings.cache_clear()
        app.dependency_overrides.clear()


def test_paystack_webhook_verify_failed_marks_payment_failed() -> None:
    client, session_local, reference = _build_sqlite_test_stack()
    original_secret = os.environ.get("PAYSTACK_SECRET_KEY_TEST")
    os.environ["PAYSTACK_SECRET_KEY_TEST"] = "sk_test_webhook_123"
    get_settings.cache_clear()
    body, signature = _body_and_signature(
        reference=reference,
        secret="sk_test_webhook_123",
    )
    try:
        with patch(
            "app.integrations.paystack.client.PaystackClient.verify_transaction",
            return_value=PaystackVerifyResult(
                reference=reference,
                status="failed",
                amount_kobo=12000,
                paid_at=None,
                raw_payload={"status": True, "data": {"status": "failed"}},
            ),
        ):
            response = client.post(
                "/api/v1/webhooks/paystack",
                content=body,
                headers={
                    "x-paystack-signature": signature,
                    "content-type": "application/json",
                },
            )
        assert response.status_code == 200
        assert response.json()["status"] == "processed"

        with session_local() as db:
            payment = db.scalar(
                select(Payment).where(Payment.provider_reference == reference)
            )
            assert payment is not None
            assert payment.status == "failed"

            receivable = db.scalar(
                select(Receivable).where(Receivable.payment_provider_reference == reference)
            )
            assert receivable is not None
            assert receivable.status == "open"
            assert receivable.outstanding_amount == Decimal("120.00")

            repayment_count = db.scalar(select(func.count()).select_from(ReceivablePayment))
            assert repayment_count == 0
            webhook_event = db.scalar(select(PaymentWebhookEvent))
            assert webhook_event is not None
            assert webhook_event.result_status == "processed"
    finally:
        if original_secret is None:
            os.environ.pop("PAYSTACK_SECRET_KEY_TEST", None)
        else:
            os.environ["PAYSTACK_SECRET_KEY_TEST"] = original_secret
        get_settings.cache_clear()
        app.dependency_overrides.clear()


def test_paystack_webhook_success_marks_sale_payment_succeeded() -> None:
    client, session_local, reference = _build_sqlite_sale_payment_stack()
    original_secret = os.environ.get("PAYSTACK_SECRET_KEY_TEST")
    os.environ["PAYSTACK_SECRET_KEY_TEST"] = "sk_test_webhook_123"
    get_settings.cache_clear()
    body, signature = _body_and_signature(
        reference=reference,
        secret="sk_test_webhook_123",
    )
    try:
        with patch(
            "app.integrations.paystack.client.PaystackClient.verify_transaction",
            return_value=PaystackVerifyResult(
                reference=reference,
                status="success",
                amount_kobo=8500,
                paid_at="2026-04-24T13:10:00Z",
                raw_payload={"status": True, "data": {"status": "success"}},
            ),
        ):
            response = client.post(
                "/api/v1/webhooks/paystack",
                content=body,
                headers={
                    "x-paystack-signature": signature,
                    "content-type": "application/json",
                },
            )
        assert response.status_code == 200
        assert response.json()["status"] == "processed"

        with session_local() as db:
            payment = db.scalar(
                select(Payment).where(Payment.provider_reference == reference)
            )
            assert payment is not None
            assert payment.status == "succeeded"
            assert payment.confirmed_at is not None

            sale = db.scalar(select(Sale).where(Sale.id == payment.sale_id))
            assert sale is not None
            assert sale.payment_status == PAYMENT_STATUS_SUCCEEDED

            webhook_event_count = db.scalar(select(func.count()).select_from(PaymentWebhookEvent))
            assert webhook_event_count == 1
    finally:
        if original_secret is None:
            os.environ.pop("PAYSTACK_SECRET_KEY_TEST", None)
        else:
            os.environ["PAYSTACK_SECRET_KEY_TEST"] = original_secret
        get_settings.cache_clear()
        app.dependency_overrides.clear()


def test_paystack_webhook_verify_failed_marks_sale_payment_failed() -> None:
    client, session_local, reference = _build_sqlite_sale_payment_stack()
    original_secret = os.environ.get("PAYSTACK_SECRET_KEY_TEST")
    os.environ["PAYSTACK_SECRET_KEY_TEST"] = "sk_test_webhook_123"
    get_settings.cache_clear()
    body, signature = _body_and_signature(
        reference=reference,
        secret="sk_test_webhook_123",
    )
    try:
        with patch(
            "app.integrations.paystack.client.PaystackClient.verify_transaction",
            return_value=PaystackVerifyResult(
                reference=reference,
                status="failed",
                amount_kobo=8500,
                paid_at=None,
                raw_payload={"status": True, "data": {"status": "failed"}},
            ),
        ):
            response = client.post(
                "/api/v1/webhooks/paystack",
                content=body,
                headers={
                    "x-paystack-signature": signature,
                    "content-type": "application/json",
                },
            )
        assert response.status_code == 200
        assert response.json()["status"] == "processed"

        with session_local() as db:
            payment = db.scalar(
                select(Payment).where(Payment.provider_reference == reference)
            )
            assert payment is not None
            assert payment.status == "failed"

            sale = db.scalar(select(Sale).where(Sale.id == payment.sale_id))
            assert sale is not None
            assert sale.payment_status == "failed"

            webhook_event_count = db.scalar(select(func.count()).select_from(PaymentWebhookEvent))
            assert webhook_event_count == 1
    finally:
        if original_secret is None:
            os.environ.pop("PAYSTACK_SECRET_KEY_TEST", None)
        else:
            os.environ["PAYSTACK_SECRET_KEY_TEST"] = original_secret
        get_settings.cache_clear()
        app.dependency_overrides.clear()
