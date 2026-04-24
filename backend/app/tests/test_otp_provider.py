"""OTP provider tests."""

from __future__ import annotations

from app.core.config import Settings
from app.services.otp_provider import ArkeselOtpProvider, OtpProviderError


def _settings() -> Settings:
    return Settings(
        app_env="local",
        database_url="sqlite:///unused.db",
        secret_key="test-secret-key-1234",
        arkesel_api_key="test-arkesel-key",
    )


def test_generate_uses_both_number_aliases_and_accepts_success_code() -> None:
    provider = ArkeselOtpProvider(settings=_settings())
    captured: dict[str, object] = {}

    def _fake_post_json(path: str, payload: dict[str, object]) -> dict[str, object]:
        captured["path"] = path
        captured["payload"] = payload
        return {
            "code": "1000",
            "message": "Successful, Message delivered",
        }

    provider._post_json = _fake_post_json  # type: ignore[method-assign]
    result = provider.generate(phone_number="233244123456")

    assert captured["path"] == "/api/otp/generate"
    assert isinstance(captured["payload"], dict)
    assert captured["payload"]["number"] == "233244123456"
    assert captured["payload"]["phone_number"] == "233244123456"
    assert result.provider_reference is None


def test_generate_raises_when_provider_returns_error_code_in_http_200() -> None:
    provider = ArkeselOtpProvider(settings=_settings())

    def _fake_post_json(path: str, payload: dict[str, object]) -> dict[str, object]:
        return {
            "code": "1007",
            "message": "Insufficient balance",
        }

    provider._post_json = _fake_post_json  # type: ignore[method-assign]

    try:
        provider.generate(phone_number="233244123456")
    except OtpProviderError as exc:
        assert "Insufficient balance" in str(exc)
        assert "1007" in str(exc)
    else:
        raise AssertionError("Expected OtpProviderError for Arkesel error response.")


def test_verify_uses_both_number_aliases_and_accepts_success_code() -> None:
    provider = ArkeselOtpProvider(settings=_settings())
    captured: dict[str, object] = {}

    def _fake_post_json(path: str, payload: dict[str, object]) -> dict[str, object]:
        captured["path"] = path
        captured["payload"] = payload
        return {
            "code": "1100",
            "message": "Successful",
        }

    provider._post_json = _fake_post_json  # type: ignore[method-assign]
    provider.verify(phone_number="233244123456", code="123456")

    assert captured["path"] == "/api/otp/verify"
    assert isinstance(captured["payload"], dict)
    assert captured["payload"]["number"] == "233244123456"
    assert captured["payload"]["phone_number"] == "233244123456"
    assert captured["payload"]["code"] == "123456"
