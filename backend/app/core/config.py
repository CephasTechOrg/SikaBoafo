"""Environment-backed settings (single source of truth for app config)."""

from functools import lru_cache

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: str = Field(default="local", description="local | staging | production")
    app_name: str = "SikaBoafo API"
    api_v1_prefix: str = "/api/v1"

    database_url: str = Field(
        default="postgresql+psycopg://postgres:postgres@localhost:5432/biztrack",
        description="SQLAlchemy URL, e.g. postgresql+psycopg://user:pass@localhost:5432/biztrack",
    )

    @field_validator("database_url", mode="before")
    @classmethod
    def normalise_db_url(cls, v: str) -> str:
        # Render supplies postgres:// or postgresql:// — rewrite to psycopg v3 scheme
        if v.startswith("postgres://"):
            return v.replace("postgres://", "postgresql+psycopg://", 1)
        if v.startswith("postgresql://"):
            return v.replace("postgresql://", "postgresql+psycopg://", 1)
        return v

    redis_url: str | None = Field(default=None, description="Redis URL for cache / future workers")

    paystack_api_base_url: str = Field(default="https://api.paystack.co")
    paystack_secret_key_test: str | None = Field(default=None)
    paystack_secret_key_live: str | None = Field(default=None)
    paystack_http_timeout_seconds: float = Field(default=15.0, ge=3.0, le=60.0)
    payment_config_encryption_key: str | None = Field(default=None)

    secret_key: str = Field(default="change-me-in-production", min_length=16)
    auth_token_issuer: str = Field(default="biztrack-gh")
    auth_access_token_exp_minutes: int = Field(default=60, ge=5, le=1440)
    auth_refresh_token_exp_minutes: int = Field(default=10080, ge=60, le=43200)
    auth_mock_otp_code: str | None = Field(
        default=None,
        description="Dev-only fallback code when SMS provider is unavailable.",
    )

    arkesel_base_url: str = Field(default="https://sms.arkesel.com")
    arkesel_api_key: str | None = Field(default=None)
    arkesel_sender_id: str = Field(default="BizTrack")
    arkesel_otp_expiry_minutes: int = Field(default=5, ge=1, le=10)
    arkesel_otp_length: int = Field(default=6, ge=4, le=10)
    arkesel_otp_type: str = Field(default="numeric")
    arkesel_otp_medium: str = Field(default="sms")

    cors_origins: str = Field(
        default="*",
        description="Comma-separated origins, or * for dev",
    )

    @property
    def cors_origin_list(self) -> list[str]:
        raw = self.cors_origins.strip()
        if raw == "*":
            return ["*"]
        return [o.strip() for o in raw.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    """Return cached settings. Call ``get_settings.cache_clear()`` in tests when env changes."""
    return Settings()
