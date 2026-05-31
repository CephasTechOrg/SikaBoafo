"""Production/staging startup configuration checks."""

from __future__ import annotations

import pytest

from app.core.config import Settings
from app.core.startup_checks import ProductionConfigError, validate_settings_or_raise


def test_local_env_allows_default_secret_and_mock_otp() -> None:
    validate_settings_or_raise(
        Settings(
            app_env="local",
            secret_key="change-me-in-production",
            auth_mock_otp_code="123456",
        )
    )


def test_production_rejects_default_secret() -> None:
    with pytest.raises(ProductionConfigError, match="SECRET_KEY"):
        validate_settings_or_raise(
            Settings(
                app_env="production",
                secret_key="change-me-in-production",
                auth_mock_otp_code=None,
            )
        )


def test_production_rejects_mock_otp() -> None:
    with pytest.raises(ProductionConfigError, match="AUTH_MOCK_OTP_CODE"):
        validate_settings_or_raise(
            Settings(
                app_env="production",
                secret_key="production-secret-key-value",
                auth_mock_otp_code="123456",
            )
        )


def test_production_requires_payment_encryption_key() -> None:
    with pytest.raises(ProductionConfigError, match="PAYMENT_CONFIG_ENCRYPTION_KEY"):
        validate_settings_or_raise(
            Settings(
                app_env="production",
                secret_key="production-secret-key-value",
                auth_mock_otp_code=None,
                payment_config_encryption_key=None,
            )
        )


def test_staging_rejects_default_secret_but_allows_mock_otp() -> None:
    with pytest.raises(ProductionConfigError, match="SECRET_KEY"):
        validate_settings_or_raise(
            Settings(
                app_env="staging",
                secret_key="change-me-in-production",
                auth_mock_otp_code="123456",
            )
        )

    validate_settings_or_raise(
        Settings(
            app_env="staging",
            secret_key="staging-secret-key-value",
            auth_mock_otp_code="123456",
        )
    )


def test_production_rejects_wildcard_cors() -> None:
    with pytest.raises(ProductionConfigError, match="CORS_ORIGINS"):
        validate_settings_or_raise(
            Settings(
                app_env="production",
                secret_key="production-secret-key-value",
                auth_mock_otp_code=None,
                payment_config_encryption_key="payment-encryption-key",
                cors_origins="*",
            )
        )


def test_staging_rejects_wildcard_cors() -> None:
    with pytest.raises(ProductionConfigError, match="CORS_ORIGINS"):
        validate_settings_or_raise(
            Settings(
                app_env="staging",
                secret_key="staging-secret-key-value",
                cors_origins="*",
            )
        )


def test_production_allows_empty_cors_for_mobile_only() -> None:
    validate_settings_or_raise(
        Settings(
            app_env="production",
            secret_key="production-secret-key-value",
            auth_mock_otp_code=None,
            payment_config_encryption_key="payment-encryption-key",
            cors_origins="",
        )
    )
