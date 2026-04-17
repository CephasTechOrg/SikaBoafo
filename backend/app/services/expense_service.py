"""Expense domain service: record and list operating expenses."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.expense import Expense
from app.models.merchant import Merchant
from app.models.store import Store
from app.schemas.expense import ExpenseCreateIn


class ExpenseContextMissingError(Exception):
    """User does not have merchant/store context for recording expenses."""


@dataclass(slots=True)
class ExpenseSnapshot:
    expense_id: UUID
    category: str
    amount: Decimal
    note: str | None
    created_at: datetime


@dataclass(slots=True)
class ExpenseService:
    db: Session

    def list_expenses_for_user(self, *, user_id: UUID, limit: int = 50) -> list[ExpenseSnapshot]:
        store = self._get_default_store_for_user(user_id=user_id)
        expenses = self.db.scalars(
            select(Expense)
            .where(Expense.store_id == store.id)
            .order_by(Expense.created_at.desc())
            .limit(limit)
        ).all()
        return [self._to_snapshot(expense=e) for e in expenses]

    def create_expense(
        self,
        *,
        user_id: UUID,
        payload: ExpenseCreateIn,
        source_device_id: str | None = None,
        local_operation_id: str | None = None,
        commit: bool = True,
    ) -> ExpenseSnapshot:
        store = self._get_default_store_for_user(user_id=user_id)
        expense = Expense(
            store_id=store.id,
            category=payload.category,
            amount=payload.amount,
            note=self._clean_optional(payload.note),
            source_device_id=source_device_id,
            local_operation_id=local_operation_id,
        )
        if payload.expense_id is not None:
            expense.id = payload.expense_id
        self.db.add(expense)

        if commit:
            self.db.commit()
            self.db.refresh(expense)
        else:
            self.db.flush()

        return self._to_snapshot(expense=expense)

    def _get_default_store_for_user(self, *, user_id: UUID) -> Store:
        merchant = self.db.scalar(select(Merchant).where(Merchant.owner_user_id == user_id))
        if merchant is None:
            msg = "Merchant profile not found."
            raise ExpenseContextMissingError(msg)
        store = self.db.scalar(
            select(Store).where(
                Store.merchant_id == merchant.id,
                Store.is_default.is_(True),
            )
        )
        if store is None:
            msg = "Default store not found."
            raise ExpenseContextMissingError(msg)
        return store

    @staticmethod
    def _to_snapshot(*, expense: Expense) -> ExpenseSnapshot:
        return ExpenseSnapshot(
            expense_id=expense.id,
            category=expense.category,
            amount=expense.amount,
            note=expense.note,
            created_at=expense.created_at,
        )

    @staticmethod
    def _clean_optional(value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None
