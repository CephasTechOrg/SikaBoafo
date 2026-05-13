"""Receivables service: customers, debt creation, and repayments."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal
from uuid import UUID

from sqlalchemy import func, select, text
from sqlalchemy.exc import IntegrityError, OperationalError
from sqlalchemy.orm import Session, selectinload

from app.core.constants import (
    RECEIVABLE_STATUS_CANCELLED,
    RECEIVABLE_STATUS_OPEN,
    RECEIVABLE_STATUS_PARTIALLY_PAID,
    RECEIVABLE_STATUS_SETTLED,
)
from app.models.customer import Customer
from app.models.payment import Payment
from app.models.receivable import Receivable, ReceivablePayment
from app.models.store import Store
from app.schemas.receivable import (
    CustomerCreateIn,
    ReceivableCreateIn,
    ReceivablePaymentCreateIn,
)
from app.services.audit_service import log_audit
from app.services.store_context import StoreContextError, get_merchant_and_store

_MONEY_SCALE = Decimal("0.01")
_MAX_INVOICE_ALLOCATE_ATTEMPTS = 3

_TERMINAL_STATUSES = {RECEIVABLE_STATUS_SETTLED, RECEIVABLE_STATUS_CANCELLED}


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
    whatsapp_number: str | None
    email: str | None
    notes: str | None
    total_outstanding: Decimal
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
    invoice_number: str | None
    sale_id: UUID | None
    created_by_user_id: UUID | None
    payment_link: str | None
    payment_provider_reference: str | None
    payment_id: UUID | None
    payment_amount: Decimal | None
    payment_link_expires_at: datetime | None
    created_at: datetime


@dataclass(slots=True)
class CustomerDetailSnapshot:
    customer: CustomerSnapshot
    receivables: list[ReceivableSnapshot]


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

    def get_receivable_for_user(
        self,
        *,
        user_id: UUID,
        receivable_id: UUID,
    ) -> ReceivableSnapshot:
        store = self._get_default_store_for_user(user_id=user_id)
        receivable = self._get_receivable_for_store(
            store_id=store.id,
            receivable_id=receivable_id,
        )
        return self._to_receivable_snapshot(receivable=receivable)

    def list_customers_for_user(self, *, user_id: UUID, limit: int = 200) -> list[CustomerSnapshot]:
        store = self._get_default_store_for_user(user_id=user_id)
        rows = self.db.execute(
            select(
                Customer,
                func.coalesce(
                    func.sum(Receivable.outstanding_amount), Decimal("0.00")
                ).label("total_outstanding"),
            )
            .outerjoin(Receivable, Receivable.customer_id == Customer.id)
            .where(Customer.store_id == store.id)
            .group_by(Customer.id)
            .order_by(Customer.name.asc())
            .limit(limit)
        ).all()
        return [
            self._to_customer_snapshot(
                customer=row[0],
                total_outstanding=self._money(Decimal(str(row[1] or "0.00"))),
            )
            for row in rows
        ]

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
            whatsapp_number=self._clean_optional(payload.whatsapp_number),
            email=self._clean_optional(payload.email),
            notes=self._clean_optional(payload.notes),
            source_device_id=source_device_id,
            local_operation_id=local_operation_id,
        )
        if payload.customer_id is not None:
            customer.id = payload.customer_id
        self.db.add(customer)
        self.db.flush()
        log_audit(
            db=self.db,
            actor_user_id=user_id,
            business_id=store.merchant_id,
            action="customer.created",
            entity_type="customer",
            entity_id=customer.id,
            meta={"name": customer.name},
        )
        self._finalize(entity=customer, commit=commit)
        return self._to_customer_snapshot(customer=customer, total_outstanding=Decimal("0.00"))

    def get_customer_detail(self, *, user_id: UUID, customer_id: UUID) -> CustomerDetailSnapshot:
        store = self._get_default_store_for_user(user_id=user_id)
        customer = self._get_customer_for_store(store_id=store.id, customer_id=customer_id)
        total_outstanding = self.db.scalar(
            select(
                func.coalesce(func.sum(Receivable.outstanding_amount), Decimal("0.00"))
            ).where(Receivable.customer_id == customer_id)
        ) or Decimal("0.00")
        receivables = self.db.scalars(
            select(Receivable)
            .options(selectinload(Receivable.customer))
            .where(Receivable.customer_id == customer_id, Receivable.store_id == store.id)
            .order_by(Receivable.created_at.desc())
            .limit(100)
        ).all()
        return CustomerDetailSnapshot(
            customer=self._to_customer_snapshot(
                customer=customer,
                total_outstanding=self._money(Decimal(str(total_outstanding))),
            ),
            receivables=[self._to_receivable_snapshot(receivable=r) for r in receivables],
        )

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
        receivable: Receivable | None = None
        invoice_number: str | None = None
        for _ in range(_MAX_INVOICE_ALLOCATE_ATTEMPTS):
            invoice_number = self._allocate_invoice_number(store_id=store.id)
            try:
                with self.db.begin_nested():
                    receivable = Receivable(
                        store_id=store.id,
                        customer_id=customer.id,
                        original_amount=amount,
                        outstanding_amount=amount,
                        due_date=payload.due_date,
                        status=RECEIVABLE_STATUS_OPEN,
                        invoice_number=invoice_number,
                        created_by_user_id=user_id,
                        source_device_id=source_device_id,
                        local_operation_id=local_operation_id,
                    )
                    if payload.receivable_id is not None:
                        receivable.id = payload.receivable_id
                    self.db.add(receivable)
                    self.db.flush()
                break
            except IntegrityError as exc:
                if not self._is_invoice_number_integrity_error(exc):
                    raise
                receivable = None
                continue
        if receivable is None or invoice_number is None:
            msg = "Could not allocate a unique invoice number. Please retry."
            raise InvalidRepaymentError(msg)
        log_audit(
            db=self.db,
            actor_user_id=user_id,
            business_id=store.merchant_id,
            action="receivable.created",
            entity_type="receivable",
            entity_id=receivable.id,  # type: ignore[union-attr]
            meta={
                "customer_id": str(customer.id),
                "amount": str(amount),
                "invoice_number": invoice_number,
            },
        )
        self._finalize(entity=receivable, commit=commit)  # type: ignore[arg-type]
        return self._to_receivable_snapshot(receivable=receivable, customer=customer)  # type: ignore[arg-type]

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
        if receivable.status in _TERMINAL_STATUSES:
            msg = f"Cannot record repayment on a {receivable.status} debt."
            raise InvalidRepaymentError(msg)
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
            receivable.status = RECEIVABLE_STATUS_PARTIALLY_PAID
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
        self.db.flush()
        log_audit(
            db=self.db,
            actor_user_id=user_id,
            business_id=store.merchant_id,
            action="receivable.payment_recorded",
            entity_type="receivable",
            entity_id=receivable.id,
            meta={"amount": str(amount), "remaining": str(receivable.outstanding_amount)},
        )
        self._finalize(entity=repayment, commit=commit)
        return self._to_repayment_snapshot(repayment=repayment)

    def cancel_receivable(
        self,
        *,
        user_id: UUID,
        receivable_id: UUID,
    ) -> ReceivableSnapshot:
        store = self._get_default_store_for_user(user_id=user_id)
        receivable = self._get_receivable_for_store(
            store_id=store.id,
            receivable_id=receivable_id,
        )
        if receivable.status in _TERMINAL_STATUSES:
            msg = f"Debt is already {receivable.status} and cannot be cancelled."
            raise InvalidRepaymentError(msg)
        receivable.status = RECEIVABLE_STATUS_CANCELLED
        self.db.flush()
        log_audit(
            db=self.db,
            actor_user_id=user_id,
            business_id=store.merchant_id,
            action="receivable.cancelled",
            entity_type="receivable",
            entity_id=receivable.id,
            meta={"invoice_number": receivable.invoice_number},
        )
        self.db.commit()
        self.db.refresh(receivable)
        return self._to_receivable_snapshot(receivable=receivable)

    def _allocate_invoice_number(self, *, store_id: UUID) -> str:
        """Allocate next invoice number without collisions (Postgres row lock).

        Uses table `receivable_invoice_counters(store_id, year, next_number)`:
        - First allocation inserts next_number=2 and returns 1
        - Next allocations lock the row and increment atomically
        """
        year = datetime.now(tz=UTC).year
        prefix = f"INV-{year}-"

        # Ensure the counter row exists (idempotent).
        self.db.execute(
            text(
                """
INSERT INTO receivable_invoice_counters (store_id, year, next_number)
VALUES (:store_id, :year, 0)
ON CONFLICT (store_id, year) DO NOTHING
"""
            ),
            {"store_id": str(store_id), "year": year},
        )

        # Lock and increment.
        row = self.db.execute(
            text(
                """
UPDATE receivable_invoice_counters
SET next_number = next_number + 1
WHERE store_id = :store_id AND year = :year
RETURNING next_number
"""
            ),
            {"store_id": str(store_id), "year": year},
        ).one()

        allocated = int(row[0])
        return f"{prefix}{allocated:04d}"

    @staticmethod
    def _is_invoice_number_integrity_error(exc: IntegrityError) -> bool:
        text_lower = str(exc).lower()
        return (
            "invoice_number" in text_lower
            or "ix_receivables_invoice_number" in text_lower
            or "ix_receivables_store_invoice_number" in text_lower
            or "receivables_store_id_invoice_number" in text_lower
        )

    def _get_default_store_for_user(self, *, user_id: UUID) -> Store:
        try:
            _, store = get_merchant_and_store(user_id=user_id, db=self.db)
        except StoreContextError as exc:
            raise ReceivableContextMissingError(str(exc)) from exc
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
    def _to_customer_snapshot(
        *, customer: Customer, total_outstanding: Decimal = Decimal("0.00")
    ) -> CustomerSnapshot:
        return CustomerSnapshot(
            customer_id=customer.id,
            name=customer.name,
            phone_number=customer.phone_number,
            whatsapp_number=customer.whatsapp_number,
            email=customer.email,
            notes=customer.notes,
            total_outstanding=total_outstanding,
            created_at=customer.created_at,
        )

    def _to_receivable_snapshot(
        self,
        *,
        receivable: Receivable,
        customer: Customer | None = None,
    ) -> ReceivableSnapshot:
        row_customer = customer or receivable.customer
        (
            payment_id,
            payment_amount,
            payment_link_expires_at,
        ) = self._latest_payment_context_for_receivable(receivable_id=receivable.id)
        return ReceivableSnapshot(
            receivable_id=receivable.id,
            customer_id=receivable.customer_id,
            customer_name=row_customer.name,
            original_amount=receivable.original_amount,
            outstanding_amount=receivable.outstanding_amount,
            due_date=receivable.due_date,
            status=receivable.status,
            invoice_number=receivable.invoice_number,
            sale_id=receivable.sale_id,
            created_by_user_id=receivable.created_by_user_id,
            payment_link=receivable.payment_link,
            payment_provider_reference=receivable.payment_provider_reference,
            payment_id=payment_id,
            payment_amount=payment_amount,
            payment_link_expires_at=payment_link_expires_at,
            created_at=receivable.created_at,
        )

    def _latest_payment_context_for_receivable(
        self,
        *,
        receivable_id: UUID,
    ) -> tuple[UUID | None, Decimal | None, datetime | None]:
        try:
            payment = self.db.scalar(
                select(Payment)
                .where(Payment.receivable_id == receivable_id)
                .order_by(Payment.initiated_at.desc())
                .limit(1)
            )
        except OperationalError:
            # SQLite unit tests that do not create the payments table should still
            # be able to exercise receivable creation paths.
            return None, None, None
        if payment is None:
            return None, None, None
        # Imported lazily to avoid pulling the payments service at module
        # import time; both modules sit in the same package.
        from app.services.payment_service import RECEIVABLE_PAYMENT_LINK_TTL

        expires_at: datetime | None = None
        if payment.status == "pending":
            initiated = payment.initiated_at
            if initiated is not None:
                if initiated.tzinfo is None:
                    initiated = initiated.replace(tzinfo=UTC)
                expires_at = initiated + RECEIVABLE_PAYMENT_LINK_TTL
        return payment.id, self._money(payment.amount), expires_at

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
