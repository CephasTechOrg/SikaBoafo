"""Auth service: request/verify OTP and issue tokens."""

from __future__ import annotations

from dataclasses import dataclass
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.constants import AUTH_TOKEN_TYPE_ACCESS, AUTH_TOKEN_TYPE_REFRESH
from app.core.security import create_session_token
from app.models.merchant import Merchant
from app.models.user import User
from app.schemas.auth import UserSessionOut
from app.services.otp_provider import (
    ArkeselOtpProvider,
    GenerateOtpResult,
    OtpVerificationFailedError,
)
from app.services.phone_number import normalize_phone_number


@dataclass(slots=True)
class AuthService:
    db: Session
    settings: Settings
    otp_provider: ArkeselOtpProvider

    def request_otp(self, *, phone_number: str) -> GenerateOtpResult:
        normalized = normalize_phone_number(phone_number)
        return self.otp_provider.generate(phone_number=normalized)

    def verify_otp(self, *, phone_number: str, code: str) -> UserSessionOut:
        normalized = normalize_phone_number(phone_number)
        self.otp_provider.verify(phone_number=normalized, code=code)

        user = self._get_user_by_phone(normalized)
        is_new_user = False
        if user is None:
            try:
                user = User(phone_number=normalized)
                self.db.add(user)
                self.db.commit()
                self.db.refresh(user)
                is_new_user = True
            except IntegrityError:
                # Concurrent verify requests can race; fallback to existing row.
                self.db.rollback()
                existing = self._get_user_by_phone(normalized)
                if existing is None:
                    raise
                user = existing

        access_token = create_session_token(
            user_id=user.id,
            phone_number=user.phone_number,
            token_type=AUTH_TOKEN_TYPE_ACCESS,
            expires_in_minutes=self.settings.auth_access_token_exp_minutes,
        )
        refresh_token = create_session_token(
            user_id=user.id,
            phone_number=user.phone_number,
            token_type=AUTH_TOKEN_TYPE_REFRESH,
            expires_in_minutes=self.settings.auth_refresh_token_exp_minutes,
        )
        onboarding_required = self._get_owner_merchant(user_id=user.id) is None
        return UserSessionOut(
            user_id=user.id,
            phone_number=user.phone_number,
            is_new_user=is_new_user,
            access_token=access_token,
            refresh_token=refresh_token,
            access_token_expires_in_minutes=self.settings.auth_access_token_exp_minutes,
            onboarding_required=onboarding_required,
        )

    def _get_user_by_phone(self, phone_number: str) -> User | None:
        stmt = select(User).where(User.phone_number == phone_number)
        return self.db.scalar(stmt)

    def _get_owner_merchant(self, user_id: UUID) -> Merchant | None:
        stmt = select(Merchant).where(Merchant.owner_user_id == user_id)
        return self.db.scalar(stmt)


__all__ = ["AuthService", "OtpVerificationFailedError"]
