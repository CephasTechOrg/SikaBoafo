"""Immutable result snapshots returned by the payments service.

Extracted from ``payment_service`` (PAY-01). Re-exported from
``payment_service`` for backward compatibility.
"""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from uuid import UUID


@dataclass(slots=True)
class PaymentInitiationSnapshot:
    payment_id: UUID
    provider: str
    provider_reference: str
    checkout_url: str
    access_code: str | None
    amount: Decimal
    currency: str
    status: str
    receivable_id: UUID


@dataclass(slots=True)
class SalePaymentInitiationSnapshot:
    payment_id: UUID
    provider: str
    provider_reference: str
    checkout_url: str
    access_code: str | None
    amount: Decimal
    currency: str
    status: str
    sale_id: UUID


@dataclass(slots=True)
class SaleMomoChargeSnapshot:
    payment_id: UUID
    provider: str
    provider_reference: str
    amount: Decimal
    currency: str
    status: str
    sale_id: UUID
    display_text: str | None = None
    needs_otp: bool = False


@dataclass(slots=True)
class PaymentVerifySnapshot:
    payment_id: UUID
    sale_id: UUID
    provider_payment_status: str
    sale_payment_status: str
    paystack_transaction_status: str
    display_text: str | None = None
    needs_otp: bool = False


@dataclass(slots=True)
class ReceivableMomoChargeSnapshot:
    payment_id: UUID
    provider: str
    provider_reference: str
    amount: Decimal
    currency: str
    status: str
    receivable_id: UUID
    display_text: str | None = None
    needs_otp: bool = False


@dataclass(slots=True)
class ReceivablePaymentVerifySnapshot:
    payment_id: UUID
    receivable_id: UUID
    provider_payment_status: str
    receivable_status: str
    outstanding_amount: Decimal
    paystack_transaction_status: str
    display_text: str | None = None
    needs_otp: bool = False


@dataclass(slots=True)
class PaymentWebhookSnapshot:
    status: str
    payment_id: UUID | None = None
    provider_reference: str | None = None


__all__ = [
    "PaymentInitiationSnapshot",
    "PaymentVerifySnapshot",
    "PaymentWebhookSnapshot",
    "ReceivableMomoChargeSnapshot",
    "ReceivablePaymentVerifySnapshot",
    "SaleMomoChargeSnapshot",
    "SalePaymentInitiationSnapshot",
]
