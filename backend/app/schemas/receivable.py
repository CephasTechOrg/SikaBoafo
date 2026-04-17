"""Receivable/debt request and response schemas."""

from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

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


class CustomerCreateIn(BaseModel):
    customer_id: UUID | None = None
    name: str = Field(min_length=2, max_length=255)
    phone_number: str | None = Field(default=None, min_length=8, max_length=32)


class SyncCustomerCreateIn(CustomerCreateIn):
    """Sync payload alias for customer create operations."""


class ReceivableCreateIn(BaseModel):
    receivable_id: UUID | None = None
    customer_id: UUID
    original_amount: Decimal = Field(gt=0, max_digits=18, decimal_places=2)
    due_date: date | None = None


class SyncReceivableCreateIn(ReceivableCreateIn):
    """Sync payload alias for receivable create operations."""


class ReceivablePaymentCreateIn(BaseModel):
    payment_id: UUID | None = None
    receivable_id: UUID
    amount: Decimal = Field(gt=0, max_digits=18, decimal_places=2)
    payment_method_label: str = Field(min_length=2, max_length=64)

    @field_validator("payment_method_label")
    @classmethod
    def validate_payment_method(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in _ALLOWED_PAYMENT_METHODS:
            msg = f"Unsupported payment_method_label: {value!r}"
            raise ValueError(msg)
        return normalized


class SyncReceivablePaymentCreateIn(ReceivablePaymentCreateIn):
    """Sync payload alias for receivable payment create operations."""


class ReceivableRepaymentIn(BaseModel):
    payment_id: UUID | None = None
    amount: Decimal = Field(gt=0, max_digits=18, decimal_places=2)
    payment_method_label: str = Field(min_length=2, max_length=64)

    @field_validator("payment_method_label")
    @classmethod
    def validate_payment_method(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in _ALLOWED_PAYMENT_METHODS:
            msg = f"Unsupported payment_method_label: {value!r}"
            raise ValueError(msg)
        return normalized


class CustomerOut(BaseModel):
    customer_id: UUID
    name: str
    phone_number: str | None
    created_at: datetime


class ReceivablePaymentOut(BaseModel):
    payment_id: UUID
    receivable_id: UUID
    amount: Decimal
    payment_method_label: str
    created_at: datetime


class ReceivableOut(BaseModel):
    receivable_id: UUID
    customer_id: UUID
    customer_name: str
    original_amount: Decimal
    outstanding_amount: Decimal
    due_date: date | None
    status: str
    created_at: datetime
