"""Phone number normalization rules."""

from __future__ import annotations

import pytest

from app.services.phone_number import InvalidPhoneNumberError, normalize_phone_number


@pytest.mark.parametrize(
    ("raw", "normalized"),
    [
        ("0244123456", "233244123456"),
        ("244123456", "233244123456"),
        ("233244123456", "233244123456"),
        ("+233 24 412 3456", "233244123456"),
    ],
)
def test_normalize_phone_number_valid(raw: str, normalized: str) -> None:
    assert normalize_phone_number(raw) == normalized


@pytest.mark.parametrize("raw", ["", "12345", "1234567890123", "abcd"])
def test_normalize_phone_number_invalid(raw: str) -> None:
    with pytest.raises(InvalidPhoneNumberError):
        normalize_phone_number(raw)
