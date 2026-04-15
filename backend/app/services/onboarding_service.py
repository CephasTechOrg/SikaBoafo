"""Onboarding service: business profile + first store bootstrap."""

from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.merchant import Merchant
from app.models.store import Store
from app.models.user import User
from app.schemas.auth import OnboardingIn, OnboardingOut


@dataclass(slots=True)
class OnboardingService:
    db: Session

    def complete(self, *, user: User, payload: OnboardingIn) -> OnboardingOut:
        merchant = self.db.scalar(select(Merchant).where(Merchant.owner_user_id == user.id))
        if merchant is None:
            merchant = Merchant(
                owner_user_id=user.id,
                business_name=payload.business_name.strip(),
                business_type=self._clean_optional(payload.business_type),
            )
            self.db.add(merchant)
            self.db.flush()
        else:
            merchant.business_name = payload.business_name.strip()
            merchant.business_type = self._clean_optional(payload.business_type)

        store = self.db.scalar(
            select(Store).where(Store.merchant_id == merchant.id, Store.is_default.is_(True))
        )
        if store is None:
            store = Store(
                merchant_id=merchant.id,
                name=self._default_store_name(
                    payload=payload,
                    business_name=merchant.business_name,
                ),
                is_default=True,
            )
            self.db.add(store)
        elif payload.store_name and payload.store_name.strip():
            store.name = payload.store_name.strip()

        self.db.commit()
        self.db.refresh(merchant)
        self.db.refresh(store)

        return OnboardingOut(
            merchant_id=merchant.id,
            store_id=store.id,
            business_name=merchant.business_name,
            business_type=merchant.business_type,
        )

    @staticmethod
    def _default_store_name(*, payload: OnboardingIn, business_name: str) -> str:
        if payload.store_name and payload.store_name.strip():
            return payload.store_name.strip()
        return f"{business_name} Main Store"

    @staticmethod
    def _clean_optional(value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None
