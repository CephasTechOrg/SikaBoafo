"""Pure helper functions for the payments service (no DB/session state).

Extracted from ``payment_service`` (PAY-01): email derivation, Paystack channel
mapping, ISO datetime parsing, Ghana MoMo phone normalization, and small payload
readers. Kept side-effect free so they are trivially unit-testable.
"""

from __future__ import annotations

import re
from datetime import UTC, datetime
from typing import Any

from app.core.constants import (
    PAYMENT_METHOD_BANK_TRANSFER,
    PAYMENT_METHOD_MOBILE_MONEY,
)
from app.models.customer import Customer
from app.models.payment import Payment
from app.models.sale import Sale
from app.services.payment_errors import PaymentInitiationStateError

_PAYSTACK_CHANNEL_MAP: dict[str, str] = {
    "mobile_money": PAYMENT_METHOD_MOBILE_MONEY,
    "bank_transfer": PAYMENT_METHOD_BANK_TRANSFER,
    "bank": PAYMENT_METHOD_BANK_TRANSFER,
}


def paystack_display_text_from_raw(raw: dict[str, Any]) -> str | None:
    data = raw.get("data")
    if not isinstance(data, dict):
        return None
    dt = data.get("display_text")
    if isinstance(dt, str) and dt.strip():
        return dt.strip()
    return None


def payment_is_momo_number_charge(payment: Payment) -> bool:
    """True when this payment was started via our MoMo-on-number `/charge` flow."""
    raw = payment.raw_provider_payload
    if not isinstance(raw, dict):
        return False
    data = raw.get("data")
    if not isinstance(data, dict):
        return False
    meta = data.get("metadata")
    if not isinstance(meta, dict):
        return False
    return meta.get("payment_flow") == "momo_number_charge"


def customer_email(customer: Customer) -> str:
    if customer.email is not None:
        candidate = customer.email.strip()
        if candidate and "@" in candidate:
            return candidate
    phone = customer.phone_number or ""
    digits = re.sub(r"\D", "", phone)
    if digits:
        return f"{digits}@pay.biztrackgh.com"
    return f"customer-{customer.id.hex[:12]}@pay.biztrackgh.com"


def sale_contact_email(*, sale: Sale) -> str:
    if sale.customer is not None:
        return customer_email(sale.customer)
    return f"sale-{sale.id.hex[:12]}@pay.biztrackgh.com"


def paystack_channel_label(channel: str | None) -> str:
    """Map a Paystack channel string to our internal payment_method_label constant."""
    if channel and isinstance(channel, str):
        normalized = channel.strip().lower()
        if normalized in _PAYSTACK_CHANNEL_MAP:
            return _PAYSTACK_CHANNEL_MAP[normalized]
    return PAYMENT_METHOD_MOBILE_MONEY


def parse_iso_datetime(value: str | None) -> datetime | None:
    if value is None:
        return None
    candidate = value.strip()
    if not candidate:
        return None
    if candidate.endswith("Z"):
        candidate = f"{candidate[:-1]}+00:00"
    try:
        parsed = datetime.fromisoformat(candidate)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def normalize_ghana_momo_phone(phone: str) -> str:
    """Digits-only local 0XXXXXXXXX for Paystack Ghana mobile money."""
    digits = re.sub(r"\D", "", phone.strip())
    if digits.startswith("233") and len(digits) >= 12:
        local = digits[3:]
        if local.startswith("0"):
            return local[:10]
        return f"0{local[:9]}"
    if digits.startswith("0") and len(digits) >= 10:
        return digits[:10]
    if len(digits) >= 9 and not digits.startswith("0"):
        return f"0{digits[-9:]}"
    return digits


def paystack_gh_momo_provider_code(provider: str) -> str:
    """Map API provider codes to Paystack's Ghana mobile_money.provider values."""
    key = provider.strip().lower()
    mapping = {
        "mtn": "mtn",
        "vod": "vod",
        "atl": "tgo",
    }
    if key not in mapping:
        msg = f"Unsupported MoMo provider: {provider!r}."
        raise PaymentInitiationStateError(msg)
    return mapping[key]


__all__ = [
    "customer_email",
    "normalize_ghana_momo_phone",
    "parse_iso_datetime",
    "payment_is_momo_number_charge",
    "paystack_channel_label",
    "paystack_display_text_from_raw",
    "paystack_gh_momo_provider_code",
    "sale_contact_email",
]
