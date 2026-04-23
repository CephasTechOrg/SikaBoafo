"""Item and inventory routes."""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.models.user import User
from app.schemas.inventory import (
    InventoryItemOut,
    InventoryMutationOut,
    ItemCreateIn,
    ItemUpdateIn,
    StockAdjustIn,
    StockInIn,
)
from app.services.inventory_service import (
    InvalidInventoryAdjustmentError,
    InvalidItemArchiveError,
    InventoryItemNotFoundError,
    InventoryItemSnapshot,
    InventoryMutationSnapshot,
    InventoryService,
    MerchantContextMissingError,
)

router = APIRouter(prefix="/items", tags=["items"])


@router.get("", response_model=list[InventoryItemOut])
def list_items(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> list[InventoryItemOut]:
    service = InventoryService(db=db)
    try:
        snapshots = service.list_items_for_user(user_id=current_user.id)
    except MerchantContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return [_to_item_out(s) for s in snapshots]


@router.post("", response_model=InventoryItemOut, status_code=status.HTTP_201_CREATED)
def create_item(
    payload: ItemCreateIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> InventoryItemOut:
    service = InventoryService(db=db)
    try:
        item = service.create_item(user_id=current_user.id, payload=payload)
    except MerchantContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return _to_item_out(item)


@router.patch("/{item_id}", response_model=InventoryItemOut)
def update_item(
    item_id: UUID,
    payload: ItemUpdateIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> InventoryItemOut:
    service = InventoryService(db=db)
    try:
        item = service.update_item(user_id=current_user.id, item_id=item_id, payload=payload)
    except MerchantContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InventoryItemNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InvalidItemArchiveError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    return _to_item_out(item)


@router.post("/{item_id}/stock-in", response_model=InventoryMutationOut)
def stock_in(
    item_id: UUID,
    payload: StockInIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> InventoryMutationOut:
    service = InventoryService(db=db)
    try:
        result = service.stock_in(
            user_id=current_user.id,
            item_id=item_id,
            quantity=payload.quantity,
            reason=payload.reason,
        )
    except MerchantContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InventoryItemNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return _to_mutation_out(result)


@router.post("/{item_id}/adjust", response_model=InventoryMutationOut)
def adjust_stock(
    item_id: UUID,
    payload: StockAdjustIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> InventoryMutationOut:
    service = InventoryService(db=db)
    try:
        result = service.adjust_stock(
            user_id=current_user.id,
            item_id=item_id,
            quantity_delta=payload.quantity_delta,
            reason=payload.reason,
        )
    except MerchantContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InventoryItemNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InvalidInventoryAdjustmentError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    return _to_mutation_out(result)


def _to_item_out(s: InventoryItemSnapshot) -> InventoryItemOut:
    return InventoryItemOut(
        item_id=s.item_id,
        name=s.name,
        default_price=s.default_price,
        cost_price=s.cost_price,
        unit=s.unit,
        sku=s.sku,
        category=s.category,
        low_stock_threshold=s.low_stock_threshold,
        is_active=s.is_active,
        quantity_on_hand=s.quantity_on_hand,
    )


def _to_mutation_out(result: InventoryMutationSnapshot) -> InventoryMutationOut:
    return InventoryMutationOut(
        item=_to_item_out(result.item),
        movement_type=result.movement_type,
        movement_quantity=result.movement_quantity,
    )
