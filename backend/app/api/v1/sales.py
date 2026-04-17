"""Sales routes."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.models.user import User
from app.schemas.sale import SaleCreateIn, SaleLineOut, SaleOut
from app.services.sales_service import (
    InsufficientStockError,
    SaleContextMissingError,
    SaleItemNotFoundError,
    SalesService,
)

router = APIRouter(prefix="/sales", tags=["sales"])


@router.get("", response_model=list[SaleOut])
def list_sales(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
) -> list[SaleOut]:
    service = SalesService(db=db)
    try:
        sales = service.list_sales_for_user(user_id=current_user.id, limit=limit)
    except SaleContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return [
        SaleOut(
            sale_id=s.sale_id,
            total_amount=s.total_amount,
            payment_method_label=s.payment_method_label,
            payment_status=s.payment_status,
            created_at=s.created_at,
            lines=[
                SaleLineOut(
                    sale_item_id=line.sale_item_id,
                    item_id=line.item_id,
                    quantity=line.quantity,
                    unit_price=line.unit_price,
                    line_total=line.line_total,
                )
                for line in s.lines
            ],
        )
        for s in sales
    ]


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
    return SaleOut(
        sale_id=sale.sale_id,
        total_amount=sale.total_amount,
        payment_method_label=sale.payment_method_label,
        payment_status=sale.payment_status,
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
