"""Sync apply schemas."""

from __future__ import annotations

from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field


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


class SyncApplyOut(BaseModel):
    results: list[SyncApplyOperationOut]
