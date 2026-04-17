"""Receivables / debt routes."""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.models.user import User
from app.schemas.receivable import (
    CustomerCreateIn,
    CustomerOut,
    ReceivableCreateIn,
    ReceivableOut,
    ReceivablePaymentCreateIn,
    ReceivablePaymentOut,
    ReceivableRepaymentIn,
)
from app.services.receivables_service import (
    CustomerNotFoundError,
    InvalidRepaymentError,
    ReceivableContextMissingError,
    ReceivableNotFoundError,
    ReceivablesService,
)

router = APIRouter(prefix="/receivables", tags=["receivables"])


@router.get("/customers", response_model=list[CustomerOut])
def list_customers(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    limit: Annotated[int, Query(ge=1, le=500)] = 200,
) -> list[CustomerOut]:
    service = ReceivablesService(db=db)
    try:
        customers = service.list_customers_for_user(user_id=current_user.id, limit=limit)
    except ReceivableContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return [
        CustomerOut(
            customer_id=c.customer_id,
            name=c.name,
            phone_number=c.phone_number,
            created_at=c.created_at,
        )
        for c in customers
    ]


@router.post("/customers", response_model=CustomerOut, status_code=status.HTTP_201_CREATED)
def create_customer(
    payload: CustomerCreateIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> CustomerOut:
    service = ReceivablesService(db=db)
    try:
        customer = service.create_customer(user_id=current_user.id, payload=payload)
    except ReceivableContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return CustomerOut(
        customer_id=customer.customer_id,
        name=customer.name,
        phone_number=customer.phone_number,
        created_at=customer.created_at,
    )


@router.get("", response_model=list[ReceivableOut])
def list_receivables(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    limit: Annotated[int, Query(ge=1, le=300)] = 100,
) -> list[ReceivableOut]:
    service = ReceivablesService(db=db)
    try:
        receivables = service.list_receivables_for_user(user_id=current_user.id, limit=limit)
    except ReceivableContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return [
        ReceivableOut(
            receivable_id=r.receivable_id,
            customer_id=r.customer_id,
            customer_name=r.customer_name,
            original_amount=r.original_amount,
            outstanding_amount=r.outstanding_amount,
            due_date=r.due_date,
            status=r.status,
            created_at=r.created_at,
        )
        for r in receivables
    ]


@router.post("", response_model=ReceivableOut, status_code=status.HTTP_201_CREATED)
def create_receivable(
    payload: ReceivableCreateIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> ReceivableOut:
    service = ReceivablesService(db=db)
    try:
        receivable = service.create_receivable(user_id=current_user.id, payload=payload)
    except ReceivableContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except CustomerNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return ReceivableOut(
        receivable_id=receivable.receivable_id,
        customer_id=receivable.customer_id,
        customer_name=receivable.customer_name,
        original_amount=receivable.original_amount,
        outstanding_amount=receivable.outstanding_amount,
        due_date=receivable.due_date,
        status=receivable.status,
        created_at=receivable.created_at,
    )


@router.post("/{receivable_id}/repayments", response_model=ReceivablePaymentOut)
def record_repayment(
    receivable_id: UUID,
    payload: ReceivableRepaymentIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> ReceivablePaymentOut:
    service = ReceivablesService(db=db)
    try:
        repayment = service.record_repayment(
            user_id=current_user.id,
            payload=ReceivablePaymentCreateIn(
                payment_id=payload.payment_id,
                receivable_id=receivable_id,
                amount=payload.amount,
                payment_method_label=payload.payment_method_label,
            ),
        )
    except ReceivableContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except ReceivableNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InvalidRepaymentError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    return ReceivablePaymentOut(
        payment_id=repayment.payment_id,
        receivable_id=repayment.receivable_id,
        amount=repayment.amount,
        payment_method_label=repayment.payment_method_label,
        created_at=repayment.created_at,
    )
