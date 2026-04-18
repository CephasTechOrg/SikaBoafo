"""Sales request and response schemas."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator

from app.core.constants import (
    PAYMENT_METHOD_BANK_TRANSFER,
    PAYMENT_METHOD_CASH,
    PAYMENT_METHOD_MOBILE_MONEY,
)

_ALLOWED_PAYMENT_METHODS = {
    PAYMENT_METHOD_CASH,
    PAYMENT_METHOD_MOBILE_MONEY,
    PAYMENT_METHOD_BANK_TRANSFER,
}


class SaleLineIn(BaseModel):
    item_id: UUID
    quantity: int = Field(gt=0)
    unit_price: Decimal = Field(gt=0, max_digits=18, decimal_places=2)


class SaleCreateIn(BaseModel):
    sale_id: UUID | None = None
    payment_method_label: str = Field(min_length=2, max_length=64)
    lines: list[SaleLineIn] = Field(min_length=1, max_length=200)
    note: str | None = Field(default=None, max_length=500)

    @field_validator("payment_method_label")
    @classmethod
    def validate_payment_method(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in _ALLOWED_PAYMENT_METHODS:
            msg = f"Unsupported payment_method_label: {value!r}"
            raise ValueError(msg)
        return normalized


class SyncSaleCreateIn(SaleCreateIn):
    """Sync payload alias for sale create operations."""


class SaleUpdateLineIn(BaseModel):
    item_id: UUID
    quantity: int = Field(gt=0)


class SaleUpdateIn(BaseModel):
    payment_method_label: str | None = Field(default=None, min_length=2, max_length=64)
    lines: list[SaleUpdateLineIn] | None = Field(default=None, min_length=1, max_length=200)

    @field_validator("payment_method_label")
    @classmethod
    def validate_optional_payment_method(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip().lower()
        if normalized not in _ALLOWED_PAYMENT_METHODS:
            msg = f"Unsupported payment_method_label: {value!r}"
            raise ValueError(msg)
        return normalized

    @model_validator(mode="after")
    def validate_edit_scope(self) -> SaleUpdateIn:
        if self.payment_method_label is None and self.lines is None:
            msg = "Provide payment_method_label or lines to update a sale."
            raise ValueError(msg)
        if self.lines is not None:
            item_ids = [line.item_id for line in self.lines]
            if len(item_ids) != len(set(item_ids)):
                msg = "Duplicate item_id is not allowed in sale update lines."
                raise ValueError(msg)
        return self


class SyncSaleUpdateIn(SaleUpdateIn):
    sale_id: UUID


class SaleVoidIn(BaseModel):
    reason: str | None = Field(default=None, min_length=2, max_length=255)

    @field_validator("reason")
    @classmethod
    def normalize_reason(cls, value: str | None) -> str | None:
        if value is None:
            return None
        reason = value.strip()
        return reason or None


class SyncSaleVoidIn(SaleVoidIn):
    sale_id: UUID


class SaleLineOut(BaseModel):
    sale_item_id: UUID
    item_id: UUID
    quantity: int
    unit_price: Decimal
    line_total: Decimal


class SaleOut(BaseModel):
    sale_id: UUID
    total_amount: Decimal
    payment_method_label: str
    payment_status: str
    sale_status: str
    voided_at: datetime | None
    void_reason: str | None
    note: str | None
    created_at: datetime
    lines: list[SaleLineOut]
