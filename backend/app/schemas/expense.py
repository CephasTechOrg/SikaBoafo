"""Expense request and response schemas."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

_ALLOWED_EXPENSE_CATEGORIES = {
    "inventory_purchase",
    "transport",
    "utilities",
    "rent",
    "salary",
    "tax",
    "other",
}


class ExpenseCreateIn(BaseModel):
    expense_id: UUID | None = None
    category: str = Field(min_length=2, max_length=64)
    amount: Decimal = Field(gt=0, max_digits=18, decimal_places=2)
    note: str | None = Field(default=None, max_length=1000)

    @field_validator("category")
    @classmethod
    def validate_category(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in _ALLOWED_EXPENSE_CATEGORIES:
            msg = f"Unsupported expense category: {value!r}"
            raise ValueError(msg)
        return normalized


class SyncExpenseCreateIn(ExpenseCreateIn):
    """Sync payload alias for expense create operations."""


class ExpenseOut(BaseModel):
    expense_id: UUID
    category: str
    amount: Decimal
    note: str | None
    created_at: datetime
