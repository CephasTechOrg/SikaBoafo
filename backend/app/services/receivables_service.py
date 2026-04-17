"""Receivables service: customers, debt creation, and repayments."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from decimal import ROUND_HALF_UP, Decimal
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.constants import RECEIVABLE_STATUS_OPEN, RECEIVABLE_STATUS_SETTLED
from app.models.customer import Customer
from app.models.merchant import Merchant
from app.models.receivable import Receivable, ReceivablePayment
from app.models.store import Store
from app.schemas.receivable import (
    CustomerCreateIn,
    ReceivableCreateIn,
    ReceivablePaymentCreateIn,
)

_MONEY_SCALE = Decimal("0.01")


class ReceivableContextMissingError(Exception):
    """User does not have merchant/store context for debt operations."""


class CustomerNotFoundError(Exception):
    """Customer does not exist for the resolved store."""


class ReceivableNotFoundError(Exception):
    """Receivable does not exist for the resolved store."""


class InvalidRepaymentError(Exception):
    """Repayment breaks outstanding amount invariants."""


@dataclass(slots=True)
class CustomerSnapshot:
    customer_id: UUID
    name: str
    phone_number: str | None
    created_at: datetime


@dataclass(slots=True)
class ReceivableSnapshot:
    receivable_id: UUID
    customer_id: UUID
    customer_name: str
    original_amount: Decimal
    outstanding_amount: Decimal
    due_date: date | None
    status: str
    created_at: datetime


@dataclass(slots=True)
class ReceivablePaymentSnapshot:
    payment_id: UUID
    receivable_id: UUID
    amount: Decimal
    payment_method_label: str
    created_at: datetime


@dataclass(slots=True)
class ReceivablesService:
    db: Session

    def list_customers_for_user(self, *, user_id: UUID, limit: int = 200) -> list[CustomerSnapshot]:
        store = self._get_default_store_for_user(user_id=user_id)
        customers = self.db.scalars(
            select(Customer)
            .where(Customer.store_id == store.id)
            .order_by(Customer.name.asc())
            .limit(limit)
        ).all()
        return [self._to_customer_snapshot(customer=c) for c in customers]

    def create_customer(
        self,
        *,
        user_id: UUID,
        payload: CustomerCreateIn,
        source_device_id: str | None = None,
        local_operation_id: str | None = None,
        commit: bool = True,
    ) -> CustomerSnapshot:
        store = self._get_default_store_for_user(user_id=user_id)
        customer = Customer(
            store_id=store.id,
            name=payload.name.strip(),
            phone_number=self._clean_optional(payload.phone_number),
            source_device_id=source_device_id,
            local_operation_id=local_operation_id,
        )
        if payload.customer_id is not None:
            customer.id = payload.customer_id
        self.db.add(customer)
        self._finalize(entity=customer, commit=commit)
        return self._to_customer_snapshot(customer=customer)

    def list_receivables_for_user(
        self,
        *,
        user_id: UUID,
        limit: int = 100,
    ) -> list[ReceivableSnapshot]:
        store = self._get_default_store_for_user(user_id=user_id)
        receivables = self.db.scalars(
            select(Receivable)
            .options(selectinload(Receivable.customer))
            .where(Receivable.store_id == store.id)
            .order_by(Receivable.created_at.desc())
            .limit(limit)
        ).all()
        return [self._to_receivable_snapshot(receivable=r) for r in receivables]

    def create_receivable(
        self,
        *,
        user_id: UUID,
        payload: ReceivableCreateIn,
        source_device_id: str | None = None,
        local_operation_id: str | None = None,
        commit: bool = True,
    ) -> ReceivableSnapshot:
        store = self._get_default_store_for_user(user_id=user_id)
        customer = self._get_customer_for_store(store_id=store.id, customer_id=payload.customer_id)
        amount = self._money(payload.original_amount)
        receivable = Receivable(
            store_id=store.id,
            customer_id=customer.id,
            original_amount=amount,
            outstanding_amount=amount,
            due_date=payload.due_date,
            status=RECEIVABLE_STATUS_OPEN,
            source_device_id=source_device_id,
            local_operation_id=local_operation_id,
        )
        if payload.receivable_id is not None:
            receivable.id = payload.receivable_id
        self.db.add(receivable)
        self._finalize(entity=receivable, commit=commit)
        return self._to_receivable_snapshot(receivable=receivable, customer=customer)

    def record_repayment(
        self,
        *,
        user_id: UUID,
        payload: ReceivablePaymentCreateIn,
        source_device_id: str | None = None,
        local_operation_id: str | None = None,
        commit: bool = True,
    ) -> ReceivablePaymentSnapshot:
        store = self._get_default_store_for_user(user_id=user_id)
        receivable = self._get_receivable_for_store(
            store_id=store.id,
            receivable_id=payload.receivable_id,
        )
        amount = self._money(payload.amount)
        if amount > receivable.outstanding_amount:
            msg = (
                f"Repayment amount exceeds outstanding balance: "
                f"outstanding={receivable.outstanding_amount}, amount={amount}."
            )
            raise InvalidRepaymentError(msg)

        receivable.outstanding_amount = self._money(receivable.outstanding_amount - amount)
        if receivable.outstanding_amount == Decimal("0.00"):
            receivable.status = RECEIVABLE_STATUS_SETTLED
        else:
            receivable.status = RECEIVABLE_STATUS_OPEN
        if source_device_id is not None:
            receivable.source_device_id = source_device_id
        if local_operation_id is not None:
            receivable.local_operation_id = local_operation_id

        repayment = ReceivablePayment(
            receivable_id=receivable.id,
            amount=amount,
            payment_method_label=payload.payment_method_label,
        )
        if payload.payment_id is not None:
            repayment.id = payload.payment_id
        self.db.add(repayment)
        self._finalize(entity=repayment, commit=commit)
        return self._to_repayment_snapshot(repayment=repayment)

    def _get_default_store_for_user(self, *, user_id: UUID) -> Store:
        merchant = self.db.scalar(select(Merchant).where(Merchant.owner_user_id == user_id))
        if merchant is None:
            msg = "Merchant profile not found."
            raise ReceivableContextMissingError(msg)
        store = self.db.scalar(
            select(Store).where(
                Store.merchant_id == merchant.id,
                Store.is_default.is_(True),
            )
        )
        if store is None:
            msg = "Default store not found."
            raise ReceivableContextMissingError(msg)
        return store

    def _get_customer_for_store(self, *, store_id: UUID, customer_id: UUID) -> Customer:
        customer = self.db.scalar(
            select(Customer).where(
                Customer.id == customer_id,
                Customer.store_id == store_id,
            )
        )
        if customer is None:
            msg = "Customer not found."
            raise CustomerNotFoundError(msg)
        return customer

    def _get_receivable_for_store(self, *, store_id: UUID, receivable_id: UUID) -> Receivable:
        receivable = self.db.scalar(
            select(Receivable)
            .options(selectinload(Receivable.customer))
            .where(
                Receivable.id == receivable_id,
                Receivable.store_id == store_id,
            )
        )
        if receivable is None:
            msg = "Receivable not found."
            raise ReceivableNotFoundError(msg)
        return receivable

    def _finalize(self, *, entity: object, commit: bool) -> None:
        if commit:
            self.db.commit()
            self.db.refresh(entity)
        else:
            self.db.flush()

    @staticmethod
    def _to_customer_snapshot(*, customer: Customer) -> CustomerSnapshot:
        return CustomerSnapshot(
            customer_id=customer.id,
            name=customer.name,
            phone_number=customer.phone_number,
            created_at=customer.created_at,
        )

    @staticmethod
    def _to_receivable_snapshot(
        *,
        receivable: Receivable,
        customer: Customer | None = None,
    ) -> ReceivableSnapshot:
        row_customer = customer or receivable.customer
        return ReceivableSnapshot(
            receivable_id=receivable.id,
            customer_id=receivable.customer_id,
            customer_name=row_customer.name,
            original_amount=receivable.original_amount,
            outstanding_amount=receivable.outstanding_amount,
            due_date=receivable.due_date,
            status=receivable.status,
            created_at=receivable.created_at,
        )

    @staticmethod
    def _to_repayment_snapshot(*, repayment: ReceivablePayment) -> ReceivablePaymentSnapshot:
        return ReceivablePaymentSnapshot(
            payment_id=repayment.id,
            receivable_id=repayment.receivable_id,
            amount=repayment.amount,
            payment_method_label=repayment.payment_method_label,
            created_at=repayment.created_at,
        )

    @staticmethod
    def _money(value: Decimal) -> Decimal:
        return value.quantize(_MONEY_SCALE, rounding=ROUND_HALF_UP)

    @staticmethod
    def _clean_optional(value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None
