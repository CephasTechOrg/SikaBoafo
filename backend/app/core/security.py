"""Token utilities for OTP auth sessions.

Keeps dependencies light by producing JWT-compatible HS256 tokens using only the
standard library. Verification can be added when protected endpoints arrive.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
from datetime import UTC, datetime, timedelta
from uuid import UUID

from app.core.config import get_settings


def _b64url_encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def _b64url_decode(raw: str) -> bytes:
    padding = "=" * (-len(raw) % 4)
    return base64.urlsafe_b64decode(f"{raw}{padding}".encode("ascii"))


def _sign(message: str, secret: str) -> str:
    digest = hmac.new(secret.encode("utf-8"), message.encode("utf-8"), hashlib.sha256).digest()
    return _b64url_encode(digest)


def _encode_jwt(payload: dict[str, str | int]) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    header_raw = _b64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_raw = _b64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{header_raw}.{payload_raw}"
    signature = _sign(signing_input, get_settings().secret_key)
    return f"{signing_input}.{signature}"


def create_session_token(
    *,
    user_id: UUID,
    phone_number: str,
    token_type: str,
    expires_in_minutes: int,
) -> str:
    now = datetime.now(tz=UTC)
    payload = {
        "sub": str(user_id),
        "phone": phone_number,
        "type": token_type,
        "iss": get_settings().auth_token_issuer,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=expires_in_minutes)).timestamp()),
    }
    return _encode_jwt(payload)


def decode_and_verify_session_token(token: str) -> dict[str, str | int]:
    """Decode HS256 token and verify signature + expiration."""
    try:
        header_raw, payload_raw, signature = token.split(".")
    except ValueError as exc:
        msg = "Malformed token."
        raise ValueError(msg) from exc

    signing_input = f"{header_raw}.{payload_raw}"
    expected_signature = _sign(signing_input, get_settings().secret_key)
    if not hmac.compare_digest(signature, expected_signature):
        msg = "Invalid token signature."
        raise ValueError(msg)

    try:
        payload_json = _b64url_decode(payload_raw).decode("utf-8")
        payload = json.loads(payload_json)
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        msg = "Invalid token payload."
        raise ValueError(msg) from exc

    exp = payload.get("exp")
    if not isinstance(exp, int):
        msg = "Invalid token expiration."
        raise ValueError(msg)
    if int(datetime.now(tz=UTC).timestamp()) >= exp:
        msg = "Token expired."
        raise ValueError(msg)
    if payload.get("iss") != get_settings().auth_token_issuer:
        msg = "Invalid token issuer."
        raise ValueError(msg)

    if not isinstance(payload, dict):
        msg = "Invalid token payload object."
        raise ValueError(msg)
    return payload
