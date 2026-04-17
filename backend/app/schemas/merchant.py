"""Merchant/store profile schemas."""

from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, Field


class MerchantProfileOut(BaseModel):
    merchant_id: UUID
    business_name: str
    business_type: str | None


class StoreProfileOut(BaseModel):
    store_id: UUID
    name: str
    location: str | None
    timezone: str
    is_default: bool


class MerchantContextOut(BaseModel):
    merchant: MerchantProfileOut
    default_store: StoreProfileOut


class MerchantUpdateIn(BaseModel):
    business_name: str = Field(min_length=2, max_length=255)
    business_type: str | None = Field(default=None, max_length=128)


class StoreUpdateIn(BaseModel):
    name: str = Field(min_length=2, max_length=255)
    location: str | None = None
    timezone: str = Field(min_length=2, max_length=64)
