"""Payment initiation request/response schemas."""

from __future__ import annotations

from decimal import Decimal
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field


class PaymentInitiateIn(BaseModel):
    receivable_id: UUID


class PaymentInitiateOut(BaseModel):
    payment_id: UUID
    provider: str
    provider_reference: str
    checkout_url: str
    access_code: str | None = None
    amount: Decimal = Field(max_digits=18, decimal_places=2)
    currency: str
    status: str
    receivable_id: UUID


class SalePaymentInitiateIn(BaseModel):
    sale_id: UUID


class SalePaymentInitiateOut(BaseModel):
    payment_id: UUID
    provider: str
    provider_reference: str
    checkout_url: str
    access_code: str | None = None
    amount: Decimal = Field(max_digits=18, decimal_places=2)
    currency: str
    status: str
    sale_id: UUID


class SaleMomoChargeIn(BaseModel):
    phone: str = Field(min_length=8, max_length=20)
    provider: Literal["mtn", "atl", "vod"]


class SaleMomoChargeOut(BaseModel):
    payment_id: UUID
    provider: str
    provider_reference: str
    amount: Decimal = Field(max_digits=18, decimal_places=2)
    currency: str
    status: str
    sale_id: UUID
    display_text: str | None = None


class PaymentVerifyOut(BaseModel):
    payment_id: UUID
    sale_id: UUID
    provider_payment_status: str
    sale_payment_status: str
    paystack_transaction_status: str
