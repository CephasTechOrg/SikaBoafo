"""Fail fast when production/staging is misconfigured."""

from __future__ import annotations

from app.core.config import Settings

_INSECURE_DEFAULT_SECRET = "change-me-in-production"


class ProductionConfigError(RuntimeError):
    """Required production settings are missing or unsafe."""


def validate_settings_or_raise(settings: Settings) -> None:
    """Refuse to boot in production-like envs with known-unsafe defaults."""
    env = settings.app_env.strip().lower()
    if env not in {"production", "staging"}:
        return

    if settings.secret_key == _INSECURE_DEFAULT_SECRET:
        msg = (
            "SECRET_KEY is still the default placeholder. "
            "Set a long random value before running in production or staging."
        )
        raise ProductionConfigError(msg)

    if env == "production" and (settings.auth_mock_otp_code or "").strip():
        msg = (
            "AUTH_MOCK_OTP_CODE must be empty in production. "
            "Remove it from the environment to prevent OTP bypass."
        )
        raise ProductionConfigError(msg)

    if env == "production" and not (settings.payment_config_encryption_key or "").strip():
        msg = (
            "PAYMENT_CONFIG_ENCRYPTION_KEY is required in production "
            "to store merchant Paystack credentials."
        )
        raise ProductionConfigError(msg)


__all__ = ["ProductionConfigError", "validate_settings_or_raise"]
