"""Payment initiation request/response schemas."""

from __future__ import annotations

from decimal import Decimal
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field


class PaymentInitiateIn(BaseModel):
    receivable_id: UUID
    amount: Decimal | None = Field(default=None, max_digits=18, decimal_places=2, gt=0)


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
    needs_otp: bool = False


class SaleMomoOtpIn(BaseModel):
    """OTP or network voucher code from the customer (Paystack `send_otp` / Telecel-style flows)."""

    otp: str = Field(min_length=4, max_length=32)


class PaymentVerifyOut(BaseModel):
    payment_id: UUID
    sale_id: UUID
    provider_payment_status: str
    sale_payment_status: str
    paystack_transaction_status: str
    display_text: str | None = None
    needs_otp: bool = False


class ReceivableMomoChargeIn(BaseModel):
    phone: str = Field(min_length=8, max_length=20)
    provider: Literal["mtn", "atl", "vod"]


class ReceivableMomoChargeOut(BaseModel):
    payment_id: UUID
    provider: str
    provider_reference: str
    amount: Decimal = Field(max_digits=18, decimal_places=2)
    currency: str
    status: str
    receivable_id: UUID
    display_text: str | None = None
    needs_otp: bool = False


class ReceivablePaymentVerifyOut(BaseModel):
    payment_id: UUID
    receivable_id: UUID
    provider_payment_status: str
    receivable_status: str
    outstanding_amount: Decimal = Field(max_digits=18, decimal_places=2)
    paystack_transaction_status: str
    display_text: str | None = None
    needs_otp: bool = False
