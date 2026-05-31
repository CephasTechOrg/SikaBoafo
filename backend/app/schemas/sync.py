"""Sync apply schemas."""

from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.inventory import InventoryItemOut
from app.schemas.receivable import CustomerOut, ReceivableOut


class SyncOperationIn(BaseModel):
    local_operation_id: str = Field(min_length=8, max_length=128)
    entity_type: str = Field(min_length=1, max_length=64)
    action_type: str = Field(min_length=1, max_length=32)
    payload: dict[str, Any] = Field(default_factory=dict)


class SyncApplyIn(BaseModel):
    device_id: str = Field(min_length=8, max_length=128)
    operations: list[SyncOperationIn] = Field(min_length=1, max_length=200)


class SyncApplyOperationOut(BaseModel):
    local_operation_id: str
    entity_type: str
    action_type: str
    status: str
    entity_id: UUID | None = None
    detail: str | None = None
    server_version: int | None = None


class SyncApplyOut(BaseModel):
    results: list[SyncApplyOperationOut]


class SyncPullOut(BaseModel):
    """Incremental server snapshot for inventory + debts domains."""

    cursor: datetime
    full_refresh: bool = False
    inventory: list[InventoryItemOut] = Field(default_factory=list)
    customers: list[CustomerOut] = Field(default_factory=list)
    receivables: list[ReceivableOut] = Field(default_factory=list)
