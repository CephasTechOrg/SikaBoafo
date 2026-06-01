"""Token utilities for OTP auth sessions (PyJWT, HS256)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID

import jwt

from app.core.config import get_settings


def session_version_from_payload(payload: dict[str, str | int]) -> int:
    """Read ``sv`` claim; legacy tokens without the claim default to 0."""
    raw = payload.get("sv", 0)
    if isinstance(raw, bool) or not isinstance(raw, int):
        return 0
    return raw


def create_session_token(
    *,
    user_id: UUID,
    phone_number: str,
    token_type: str,
    expires_in_minutes: int,
    session_version: int = 0,
) -> str:
    now = datetime.now(tz=UTC)
    payload = {
        "sub": str(user_id),
        "phone": phone_number,
        "type": token_type,
        "sv": session_version,
        "iss": get_settings().auth_token_issuer,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=expires_in_minutes)).timestamp()),
    }
    return jwt.encode(
        payload,
        get_settings().secret_key,
        algorithm="HS256",
    )


def decode_and_verify_session_token(token: str) -> dict[str, str | int]:
    """Decode HS256 token and verify signature, expiration, and issuer."""
    settings = get_settings()
    try:
        payload = jwt.decode(
            token,
            settings.secret_key,
            algorithms=["HS256"],
            issuer=settings.auth_token_issuer,
            options={"require": ["exp", "sub", "iss"]},
        )
    except jwt.ExpiredSignatureError as exc:
        raise ValueError("Token expired.") from exc
    except jwt.InvalidIssuerError as exc:
        raise ValueError("Invalid token issuer.") from exc
    except jwt.InvalidSignatureError as exc:
        raise ValueError("Invalid token signature.") from exc
    except jwt.DecodeError as exc:
        raise ValueError("Malformed token.") from exc
    except jwt.InvalidTokenError as exc:
        raise ValueError("Invalid token payload.") from exc

    if not isinstance(payload, dict):
        raise ValueError("Invalid token payload object.")
    return payload
