"""Payment settings schemas (M4 Step 1: Paystack connection page)."""

from __future__ import annotations

from pydantic import BaseModel, Field, field_validator

from app.core.constants import PAYSTACK_MODE_LIVE, PAYSTACK_MODE_TEST

_VALID_MODES = {PAYSTACK_MODE_TEST, PAYSTACK_MODE_LIVE}


class PaystackConnectionUpdateIn(BaseModel):
    public_key: str = Field(min_length=10, max_length=255)
    mode: str = Field(default=PAYSTACK_MODE_TEST)
    account_label: str | None = Field(default=None, max_length=120)

    @field_validator("public_key")
    @classmethod
    def normalize_public_key(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            msg = "public_key is required."
            raise ValueError(msg)
        return normalized

    @field_validator("mode")
    @classmethod
    def normalize_mode(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in _VALID_MODES:
            msg = f"mode must be one of: {sorted(_VALID_MODES)}"
            raise ValueError(msg)
        return normalized

    @field_validator("account_label")
    @classmethod
    def normalize_account_label(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        return normalized or None


class PaystackConnectionOut(BaseModel):
    provider: str
    is_connected: bool
    mode: str
    account_label: str | None
    public_key_masked: str | None

