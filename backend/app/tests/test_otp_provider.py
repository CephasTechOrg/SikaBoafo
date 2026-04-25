"""OTP provider tests for locally managed OTP storage."""

from __future__ import annotations

from collections.abc import Generator
from urllib import parse

from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import Settings
from app.models.otp_code import OtpCode
from app.services.otp_provider import ArkeselOtpProvider, OtpVerificationFailedError


def _settings() -> Settings:
    return Settings(
        app_env="local",
        database_url="sqlite:///unused.db",
        secret_key="test-secret-key-1234",
        arkesel_api_key="test-arkesel-key",
        arkesel_otp_length=6,
        arkesel_otp_type="numeric",
        arkesel_otp_expiry_minutes=5,
        auth_mock_otp_code=None,  # ensure .env mock code doesn't short-circuit DB writes
    )


def _session_local() -> sessionmaker[Session]:
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    OtpCode.__table__.create(bind=engine)
    return sessionmaker(autocommit=False, autoflush=False, bind=engine)


def test_generate_stores_hashed_code_and_delivery_reference() -> None:
    session_local = _session_local()
    with session_local() as db:
        provider = ArkeselOtpProvider(db=db, settings=_settings())
        provider._generate_code = lambda: "123456"  # type: ignore[method-assign]
        provider._send_sms = lambda **kwargs: "sms-ref-123"  # type: ignore[method-assign]

        result = provider.generate(phone_number="233244123456")
        db.commit()

        row = db.scalar(select(OtpCode).where(OtpCode.phone_number == "233244123456"))
        assert row is not None
        assert row.code_hash != "123456"
        assert row.delivery_reference == "sms-ref-123"
        assert row.delivery_provider == "arkesel"
        assert row.used_at is None
        assert result.provider_reference == "sms-ref-123"


def test_verify_marks_code_used_on_success() -> None:
    session_local = _session_local()
    with session_local() as db:
        provider = ArkeselOtpProvider(db=db, settings=_settings())
        provider._generate_code = lambda: "123456"  # type: ignore[method-assign]
        provider._send_sms = lambda **kwargs: "sms-ref-123"  # type: ignore[method-assign]

        provider.generate(phone_number="233244123456")
        db.commit()

        provider.verify(phone_number="233244123456", code="123456")
        db.commit()

        row = db.scalar(select(OtpCode).where(OtpCode.phone_number == "233244123456"))
        assert row is not None
        assert row.used_at is not None
        assert row.attempt_count == 1


def test_verify_wrong_code_increments_attempt_count() -> None:
    session_local = _session_local()
    with session_local() as db:
        provider = ArkeselOtpProvider(db=db, settings=_settings())
        provider._generate_code = lambda: "123456"  # type: ignore[method-assign]
        provider._send_sms = lambda **kwargs: "sms-ref-123"  # type: ignore[method-assign]

        provider.generate(phone_number="233244123456")
        db.commit()

        try:
            provider.verify(phone_number="233244123456", code="000000")
        except OtpVerificationFailedError as exc:
            assert "Invalid verification code." in str(exc)
        else:
            raise AssertionError("Expected invalid OTP verification failure.")

        row = db.scalar(select(OtpCode).where(OtpCode.phone_number == "233244123456"))
        assert row is not None
        assert row.used_at is None
        assert row.attempt_count == 1


def test_generate_invalidates_previous_active_code() -> None:
    session_local = _session_local()
    with session_local() as db:
        provider = ArkeselOtpProvider(db=db, settings=_settings())
        provider._send_sms = lambda **kwargs: "sms-ref-123"  # type: ignore[method-assign]

        provider._generate_code = lambda: "111111"  # type: ignore[method-assign]
        provider.generate(phone_number="233244123456")
        db.commit()

        provider._generate_code = lambda: "222222"  # type: ignore[method-assign]
        provider.generate(phone_number="233244123456")
        db.commit()

        rows = db.scalars(
            select(OtpCode)
            .where(OtpCode.phone_number == "233244123456")
            .order_by(OtpCode.created_at.asc())
        ).all()
        assert len(rows) == 2
        assert rows[0].used_at is not None
        assert rows[1].used_at is None


def test_send_sms_uses_query_string_route_expected_by_arkesel() -> None:
    session_local = _session_local()
    with session_local() as db:
        provider = ArkeselOtpProvider(db=db, settings=_settings())
        captured: dict[str, str] = {}

        def fake_get_json(*, endpoint: str) -> dict[str, object]:
            captured["endpoint"] = endpoint
            return {"code": "ok", "message": "Successfully Sent"}

        provider._get_json = fake_get_json  # type: ignore[method-assign]

        provider._send_sms(
            phone_number="233244123456",
            message="Your BizTrack code is 123456.",
        )

        parsed = parse.urlparse(captured["endpoint"])
        params = parse.parse_qs(parsed.query)
        assert parsed.path.endswith("/sms/api")
        assert params["action"] == ["send-sms"]
        assert params["api_key"] == ["test-arkesel-key"]
        assert params["to"] == ["233244123456"]
        assert params["from"] == ["BizTrack"]
        assert params["sms"] == ["Your BizTrack code is 123456."]
