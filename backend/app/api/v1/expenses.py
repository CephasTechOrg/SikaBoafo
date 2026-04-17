"""Expense routes."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.models.user import User
from app.schemas.expense import ExpenseCreateIn, ExpenseOut
from app.services.expense_service import ExpenseContextMissingError, ExpenseService

router = APIRouter(prefix="/expenses", tags=["expenses"])


@router.get("", response_model=list[ExpenseOut])
def list_expenses(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
) -> list[ExpenseOut]:
    service = ExpenseService(db=db)
    try:
        expenses = service.list_expenses_for_user(
            user_id=current_user.id,
            limit=limit,
        )
    except ExpenseContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return [
        ExpenseOut(
            expense_id=e.expense_id,
            category=e.category,
            amount=e.amount,
            note=e.note,
            created_at=e.created_at,
        )
        for e in expenses
    ]


@router.post("", response_model=ExpenseOut, status_code=status.HTTP_201_CREATED)
def create_expense(
    payload: ExpenseCreateIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> ExpenseOut:
    service = ExpenseService(db=db)
    try:
        expense = service.create_expense(
            user_id=current_user.id,
            payload=payload,
        )
    except ExpenseContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return ExpenseOut(
        expense_id=expense.expense_id,
        category=expense.category,
        amount=expense.amount,
        note=expense.note,
        created_at=expense.created_at,
    )
