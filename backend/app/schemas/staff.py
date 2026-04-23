"""Staff management schemas."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.core.constants import (
    USER_ROLE_CASHIER,
    USER_ROLE_MANAGER,
    USER_ROLE_STOCK_KEEPER,
)

_STAFF_ROLES = {USER_ROLE_MANAGER, USER_ROLE_CASHIER, USER_ROLE_STOCK_KEEPER}

_ROLE_DISPLAY = {
    USER_ROLE_MANAGER: "Manager",
    USER_ROLE_CASHIER: "Cashier",
    USER_ROLE_STOCK_KEEPER: "Stock Keeper",
}


class StaffMemberOut(BaseModel):
    user_id: UUID
    phone_number: str
    full_name: str | None
    role: str
    role_display: str
    is_active: bool


class InviteStaffIn(BaseModel):
    phone_number: str = Field(min_length=8, max_length=20)
    role: str

    @field_validator("role")
    @classmethod
    def role_valid(cls, v: str) -> str:
        if v not in _STAFF_ROLES:
            msg = f"role must be one of: {sorted(_STAFF_ROLES)}"
            raise ValueError(msg)
        return v


class StaffInviteOut(BaseModel):
    invite_id: UUID
    phone_number: str
    role: str
    role_display: str
    status: str
    expires_at: datetime


class UpdateRoleIn(BaseModel):
    role: str

    @field_validator("role")
    @classmethod
    def role_valid(cls, v: str) -> str:
        if v not in _STAFF_ROLES:
            msg = f"role must be one of: {sorted(_STAFF_ROLES)}"
            raise ValueError(msg)
        return v
