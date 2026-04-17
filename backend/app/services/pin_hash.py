"""PIN hashing (stdlib scrypt) — no extra dependencies."""

from __future__ import annotations

import base64
import hashlib
import secrets

# Stored format: scrypt18$<salt_b64>$<hash_b64> (n=2**14, r=8, p=1, dklen=32)
_PIN_PREFIX = "scrypt18"
_SCRYPT_N = 2**14


def is_valid_pin_format(pin: str) -> bool:
    return 4 <= len(pin) <= 6 and pin.isdigit()


def hash_pin(pin: str) -> str:
    if not is_valid_pin_format(pin):
        msg = "PIN must be 4–6 digits."
        raise ValueError(msg)
    salt = secrets.token_bytes(16)
    dk = hashlib.scrypt(
        pin.encode("utf-8"),
        salt=salt,
        n=_SCRYPT_N,
        r=8,
        p=1,
        dklen=32,
    )
    return (
        f"{_PIN_PREFIX}${base64.b64encode(salt).decode('ascii')}"
        f"${base64.b64encode(dk).decode('ascii')}"
    )


def verify_pin(pin: str, stored: str) -> bool:
    if not is_valid_pin_format(pin):
        return False
    try:
        prefix, salt_b64, hash_b64 = stored.split("$", 2)
        if prefix != _PIN_PREFIX:
            return False
        salt = base64.b64decode(salt_b64.encode("ascii"), validate=True)
        expected = base64.b64decode(hash_b64.encode("ascii"), validate=True)
    except (ValueError, UnicodeDecodeError, TypeError):
        return False
    dk = hashlib.scrypt(
        pin.encode("utf-8"),
        salt=salt,
        n=_SCRYPT_N,
        r=8,
        p=1,
        dklen=32,
    )
    return secrets.compare_digest(dk, expected)
