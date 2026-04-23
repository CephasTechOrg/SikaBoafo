"""FastAPI dependencies shared across routers."""

from __future__ import annotations

from collections.abc import Callable
from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.constants import AUTH_TOKEN_TYPE_ACCESS
from app.core.security import decode_and_verify_session_token
from app.db.session import get_db
from app.models.user import User

_bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    db: Annotated[Session, Depends(get_db)],
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer_scheme)],
) -> User:
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token.",
        )
    try:
        payload = decode_and_verify_session_token(credentials.credentials)
        if payload.get("type") != AUTH_TOKEN_TYPE_ACCESS:
            raise ValueError("Access token required.")
        user_id = UUID(str(payload["sub"]))
    except (KeyError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid bearer token.",
        ) from exc

    user = db.scalar(select(User).where(User.id == user_id))
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive.",
        )
    return user


def require_role(*allowed_roles: str) -> Callable[[User], User]:
    """Return a FastAPI dependency that enforces role-based access control.

    Usage::

        @router.get("/admin-only")
        def admin_route(
            current_user: Annotated[User, Depends(require_role("merchant_owner", "manager"))],
        ) -> ...:
    """

    def _check(current_user: Annotated[User, Depends(get_current_user)]) -> User:
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions.",
            )
        return current_user

    return _check


__all__ = ["get_current_user", "get_db", "require_role"]
