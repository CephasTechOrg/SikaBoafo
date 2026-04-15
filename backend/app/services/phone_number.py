"""Phone number normalization (Ghana-first)."""

from __future__ import annotations

import re


class InvalidPhoneNumberError(ValueError):
    """Raised when a user-provided phone number cannot be normalized."""


def normalize_phone_number(raw_phone_number: str) -> str:
    """Return E.164-like numeric format without plus, e.g. 233244123456."""
    digits = re.sub(r"\D+", "", raw_phone_number.strip())
    if not digits:
        msg = "Phone number is required."
        raise InvalidPhoneNumberError(msg)

    if digits.startswith("233") and len(digits) == 12:
        return digits
    if digits.startswith("0") and len(digits) == 10:
        return f"233{digits[1:]}"
    if len(digits) == 9:
        return f"233{digits}"

    msg = "Use a valid Ghana phone number."
    raise InvalidPhoneNumberError(msg)
