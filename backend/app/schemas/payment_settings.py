"""Payment settings schemas (M4 Step 1: Paystack connection page)."""

from __future__ import annotations

from datetime import datetime
import re

from pydantic import BaseModel, Field, field_validator

from app.core.constants import PAYSTACK_MODE_LIVE, PAYSTACK_MODE_TEST

_VALID_MODES = {PAYSTACK_MODE_TEST, PAYSTACK_MODE_LIVE}
_KEY_WHITESPACE_RE = re.compile(r"\s+")
_HIDDEN_KEY_CHARS = {"\u200b", "\u200c", "\u200d", "\ufeff"}


def _normalize_api_key(value: str | None) -> str | None:
    if value is None:
        return None
    normalized = "".join(
        ch for ch in value.strip() if not ch.isspace() and ch not in _HIDDEN_KEY_CHARS
    )
    normalized = _KEY_WHITESPACE_RE.sub("", normalized)
    return normalized or None


class PaystackConnectionUpdateIn(BaseModel):
    public_key: str | None = Field(default=None, max_length=255)
    secret_key: str | None = Field(default=None, min_length=32, max_length=255)
    mode: str = Field(default=PAYSTACK_MODE_TEST)
    account_label: str | None = Field(default=None, max_length=120)

    @field_validator("public_key")
    @classmethod
    def normalize_public_key(cls, value: str | None) -> str | None:
        return _normalize_api_key(value)

    @field_validator("secret_key")
    @classmethod
    def normalize_secret_key(cls, value: str | None) -> str | None:
        return _normalize_api_key(value)

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
    class ModeCredentialState(BaseModel):
        configured: bool
        verified_at: datetime | None
        public_key_masked: str | None
        secret_key_masked: str | None

    provider: str
    is_connected: bool
    mode: str
    account_label: str | None
    test: ModeCredentialState
    live: ModeCredentialState
