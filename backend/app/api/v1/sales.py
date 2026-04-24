"""Sales routes."""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.models.user import User
from app.schemas.sale import SaleCreateIn, SaleLineOut, SaleOut, SaleUpdateIn, SaleVoidIn
from app.services.sales_service import (
    InsufficientStockError,
    SaleAlreadyVoidedError,
    SaleContextMissingError,
    SaleNotFoundError,
    SaleItemNotFoundError,
    SaleSnapshot,
    SaleUpdateScopeError,
    SalesService,
)

router = APIRouter(prefix="/sales", tags=["sales"])


def _to_sale_out(sale: SaleSnapshot) -> SaleOut:
    return SaleOut(
        sale_id=sale.sale_id,
        total_amount=sale.total_amount,
        payment_method_label=sale.payment_method_label,
        payment_status=sale.payment_status,
        sale_status=sale.sale_status,
        voided_at=sale.voided_at,
        void_reason=sale.void_reason,
        note=sale.note,
        created_at=sale.created_at,
        lines=[
            SaleLineOut(
                sale_item_id=line.sale_item_id,
                item_id=line.item_id,
                quantity=line.quantity,
                unit_price=line.unit_price,
                line_total=line.line_total,
            )
            for line in sale.lines
        ],
    )


@router.get("/{sale_id}", response_model=SaleOut)
def get_sale(
    sale_id: UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> SaleOut:
    service = SalesService(db=db)
    try:
        sale = service.get_sale_for_user(user_id=current_user.id, sale_id=sale_id)
    except SaleContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except SaleNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return _to_sale_out(sale)


@router.get("", response_model=list[SaleOut])
def list_sales(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    include_voided: Annotated[bool, Query()] = False,
) -> list[SaleOut]:
    service = SalesService(db=db)
    try:
        sales = service.list_sales_for_user(
            user_id=current_user.id,
            limit=limit,
            include_voided=include_voided,
        )
    except SaleContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return [_to_sale_out(sale) for sale in sales]


@router.post("", response_model=SaleOut, status_code=status.HTTP_201_CREATED)
def create_sale(
    payload: SaleCreateIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> SaleOut:
    service = SalesService(db=db)
    try:
        sale = service.create_sale(user_id=current_user.id, payload=payload)
    except SaleContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except SaleItemNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InsufficientStockError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    return _to_sale_out(sale)


@router.patch("/{sale_id}", response_model=SaleOut)
def update_sale(
    sale_id: UUID,
    payload: SaleUpdateIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> SaleOut:
    service = SalesService(db=db)
    try:
        sale = service.update_sale(
            user_id=current_user.id,
            sale_id=sale_id,
            payload=payload,
        )
    except SaleContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except SaleNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except SaleAlreadyVoidedError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except SaleUpdateScopeError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc
    except InsufficientStockError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc
    return _to_sale_out(sale)


@router.post("/{sale_id}/void", response_model=SaleOut)
def void_sale(
    sale_id: UUID,
    payload: SaleVoidIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> SaleOut:
    service = SalesService(db=db)
    try:
        sale = service.void_sale(
            user_id=current_user.id,
            sale_id=sale_id,
            payload=payload,
        )
    except SaleContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except SaleNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except SaleAlreadyVoidedError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    return _to_sale_out(sale)
