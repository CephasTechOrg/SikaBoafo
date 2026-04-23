"""Auth service: OTP verification, PIN login, PIN set, and token issuance."""

from __future__ import annotations

from dataclasses import dataclass
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.constants import (
    AUTH_TOKEN_TYPE_ACCESS,
    AUTH_TOKEN_TYPE_REFRESH,
    STAFF_INVITE_STATUS_ACCEPTED,
    STAFF_INVITE_STATUS_PENDING,
    USER_ROLE_MERCHANT_OWNER,
)
from app.core.security import create_session_token
from app.models.merchant import Merchant
from app.models.staff_invite import StaffInvite
from app.models.user import User
from app.schemas.auth import UserSessionOut
from app.services.otp_provider import (
    ArkeselOtpProvider,
    GenerateOtpResult,
    OtpVerificationFailedError,
)
from app.services.phone_number import normalize_phone_number
from app.services.pin_hash import hash_pin, is_valid_pin_format
from app.services.pin_hash import verify_pin as verify_pin_hash


class PinNotSetError(Exception):
    """Account exists but merchant has not set a PIN yet — use OTP once."""


class InvalidPinLoginError(Exception):
    """Wrong phone, wrong PIN, or inactive user (generic client message)."""


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
                user = User(phone_number=normalized, role=USER_ROLE_MERCHANT_OWNER)
                self.db.add(user)
                self.db.flush()
                is_new_user = True
            except IntegrityError:
                # Concurrent verify requests can race; fallback to existing row.
                self.db.rollback()
                existing = self._get_user_by_phone(normalized)
                if existing is None:
                    raise
                user = existing

        # Accept any pending staff invite for this phone number.
        self._accept_pending_invite(user=user, phone_number=normalized)

        self.db.commit()
        self.db.refresh(user)
        return self._issue_session(user=user, is_new_user=is_new_user)

    def login_with_pin(self, *, phone_number: str, pin: str) -> UserSessionOut:
        normalized = normalize_phone_number(phone_number)
        user = self._get_user_by_phone(normalized)
        if user is None or not user.is_active:
            raise InvalidPinLoginError
        if user.pin_hash is None:
            raise PinNotSetError
        if not verify_pin_hash(pin, user.pin_hash):
            raise InvalidPinLoginError
        return self._issue_session(user=user, is_new_user=False)

    def set_pin(self, *, user: User, pin: str) -> None:
        if not is_valid_pin_format(pin):
            msg = "PIN must be 4–6 digits."
            raise ValueError(msg)
        user.pin_hash = hash_pin(pin)
        self.db.add(user)
        self.db.commit()

    def _issue_session(self, *, user: User, is_new_user: bool) -> UserSessionOut:
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
        owner_merchant = self._get_owner_merchant(user_id=user.id)
        active_merchant_id = owner_merchant.id if owner_merchant else user.merchant_id
        # Staff users always have onboarding done (owner completed it for their business).
        onboarding_required = active_merchant_id is None
        pin_set = user.pin_hash is not None
        return UserSessionOut(
            user_id=user.id,
            phone_number=user.phone_number,
            is_new_user=is_new_user,
            role=user.role or USER_ROLE_MERCHANT_OWNER,
            merchant_id=active_merchant_id,
            access_token=access_token,
            refresh_token=refresh_token,
            access_token_expires_in_minutes=self.settings.auth_access_token_exp_minutes,
            onboarding_required=onboarding_required,
            pin_set=pin_set,
        )

    def _get_user_by_phone(self, phone_number: str) -> User | None:
        stmt = select(User).where(User.phone_number == phone_number)
        return self.db.scalar(stmt)

    def _get_owner_merchant(self, user_id: UUID) -> Merchant | None:
        stmt = select(Merchant).where(Merchant.owner_user_id == user_id)
        return self.db.scalar(stmt)

    def _accept_pending_invite(self, *, user: User, phone_number: str) -> None:
        """If a pending invite exists for this phone, link user to that merchant."""
        from datetime import UTC, datetime  # noqa: PLC0415

        now = datetime.now(UTC)
        invite = self.db.scalar(
            select(StaffInvite).where(
                StaffInvite.phone_number == phone_number,
                StaffInvite.status == STAFF_INVITE_STATUS_PENDING,
                StaffInvite.expires_at > now,
            )
        )
        if invite is None:
            return
        user.merchant_id = invite.merchant_id
        user.role = invite.role
        invite.status = STAFF_INVITE_STATUS_ACCEPTED
        self.db.add(user)
        self.db.add(invite)


__all__ = [
    "AuthService",
    "InvalidPinLoginError",
    "OtpVerificationFailedError",
    "PinNotSetError",
]
