"""Role helpers shared by API dependencies."""

from __future__ import annotations

from app.core.constants import USER_ROLE_MERCHANT_OWNER
from app.models.user import User


def is_merchant_owner(user: User) -> bool:
    """Legacy users without a persisted role are treated as owners."""
    return user.role in (None, USER_ROLE_MERCHANT_OWNER)
