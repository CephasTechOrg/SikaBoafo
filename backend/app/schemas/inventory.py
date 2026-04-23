"""Inventory/item request and response schemas."""

from __future__ import annotations

from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator


class ItemCreateIn(BaseModel):
    item_id: UUID | None = None
    name: str = Field(min_length=2, max_length=255)
    default_price: Decimal = Field(gt=0, max_digits=18, decimal_places=2)
    cost_price: Decimal | None = Field(default=None, gt=0, max_digits=18, decimal_places=2)
    unit: str | None = Field(default=None, max_length=32)
    sku: str | None = Field(default=None, max_length=128)
    category: str | None = Field(default=None, max_length=128)
    low_stock_threshold: int | None = Field(default=None, ge=0)


class ItemUpdateIn(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=255)
    default_price: Decimal | None = Field(default=None, gt=0, max_digits=18, decimal_places=2)
    cost_price: Decimal | None = Field(default=None, gt=0, max_digits=18, decimal_places=2)
    unit: str | None = Field(default=None, max_length=32)
    sku: str | None = Field(default=None, max_length=128)
    category: str | None = Field(default=None, max_length=128)
    low_stock_threshold: int | None = Field(default=None, ge=0)
    is_active: bool | None = None

    @model_validator(mode="after")
    def validate_has_changes(self) -> ItemUpdateIn:
        if (
            self.name is None
            and self.default_price is None
            and self.cost_price is None
            and self.unit is None
            and self.sku is None
            and self.category is None
            and self.low_stock_threshold is None
            and self.is_active is None
        ):
            msg = "At least one field must be provided."
            raise ValueError(msg)
        return self


class StockInIn(BaseModel):
    quantity: int = Field(gt=0)
    reason: str | None = Field(default=None, max_length=255)


class StockAdjustIn(BaseModel):
    quantity_delta: int
    reason: str | None = Field(default=None, max_length=255)

    @field_validator("quantity_delta")
    @classmethod
    def validate_non_zero_delta(cls, value: int) -> int:
        if value == 0:
            msg = "quantity_delta must not be 0."
            raise ValueError(msg)
        return value


class SyncItemUpdateIn(ItemUpdateIn):
    item_id: UUID


class SyncStockInIn(StockInIn):
    item_id: UUID


class SyncStockAdjustIn(StockAdjustIn):
    item_id: UUID


class InventoryItemOut(BaseModel):
    item_id: UUID
    name: str
    default_price: Decimal
    cost_price: Decimal | None
    unit: str | None
    sku: str | None
    category: str | None
    low_stock_threshold: int | None
    is_active: bool
    quantity_on_hand: int


class InventoryMutationOut(BaseModel):
    item: InventoryItemOut
    movement_type: str
    movement_quantity: int
