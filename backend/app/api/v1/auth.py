"""Auth endpoints: SMS OTP (signup/recovery) and PIN login/set."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db, get_merchant_owner
from app.core.config import Settings, get_settings
from app.models.user import User
from app.schemas.auth import (
    AccountDeleteOut,
    LogoutOut,
    OnboardingIn,
    OnboardingOut,
    OtpRequestIn,
    OtpRequestOut,
    OtpVerifyIn,
    PinLoginIn,
    PinSetIn,
    PinSetOut,
    RefreshTokenIn,
    UserSessionOut,
)
from app.services.auth_service import (
    AuthService,
    InvalidPinLoginError,
    InvalidRefreshTokenError,
    OtpVerificationFailedError,
    PinNotSetError,
)
from app.services.onboarding_service import (
    OnboardingPermissionError,
    OnboardingService,
)
from app.services.otp_provider import ArkeselOtpProvider, OtpProviderError
from app.services.otp_send_guard import OtpSendRateLimitedError
from app.services.phone_number import InvalidPhoneNumberError
from app.services.pin_login_guard import PinLoginLockedError

router = APIRouter(prefix="/auth", tags=["auth"])


def _build_auth_service(db: Session, settings: Settings) -> AuthService:
    return AuthService(
        db=db,
        settings=settings,
        otp_provider=ArkeselOtpProvider(db=db, settings=settings),
    )


@router.post("/otp/request", response_model=OtpRequestOut)
def request_otp(
    payload: OtpRequestIn,
    db: Annotated[Session, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> OtpRequestOut:
    service = _build_auth_service(db=db, settings=settings)
    try:
        result = service.request_otp(phone_number=payload.phone_number)
    except InvalidPhoneNumberError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    except OtpSendRateLimitedError as exc:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=str(exc),
        ) from exc
    except OtpProviderError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    return OtpRequestOut(
        provider_reference=result.provider_reference,
        expires_in_minutes=result.expires_in_minutes,
    )


@router.post("/otp/verify", response_model=UserSessionOut)
def verify_otp(
    payload: OtpVerifyIn,
    db: Annotated[Session, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> UserSessionOut:
    service = _build_auth_service(db=db, settings=settings)
    try:
        return service.verify_otp(phone_number=payload.phone_number, code=payload.code)
    except InvalidPhoneNumberError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    except OtpVerificationFailedError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(exc),
        ) from exc
    except OtpProviderError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc


@router.post("/pin/login", response_model=UserSessionOut)
def login_with_pin(
    payload: PinLoginIn,
    db: Annotated[Session, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> UserSessionOut:
    service = _build_auth_service(db=db, settings=settings)
    try:
        return service.login_with_pin(phone_number=payload.phone_number, pin=payload.pin)
    except InvalidPhoneNumberError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    except PinNotSetError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="pin_not_set",
        ) from exc
    except PinLoginLockedError as exc:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=str(exc),
        ) from exc
    except InvalidPinLoginError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid phone number or PIN.",
        ) from exc


@router.post("/logout", response_model=LogoutOut)
def logout(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> LogoutOut:
    service = _build_auth_service(db=db, settings=settings)
    service.logout(user=current_user)
    return LogoutOut()


@router.post("/refresh", response_model=UserSessionOut)
def refresh_session(
    payload: RefreshTokenIn,
    db: Annotated[Session, Depends(get_db)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> UserSessionOut:
    service = _build_auth_service(db=db, settings=settings)
    try:
        return service.refresh_session(refresh_token=payload.refresh_token)
    except InvalidRefreshTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token.",
        ) from exc


@router.post("/pin/set", response_model=PinSetOut)
def set_pin(
    payload: PinSetIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> PinSetOut:
    service = _build_auth_service(db=db, settings=settings)
    try:
        service.set_pin(user=current_user, pin=payload.pin)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    return PinSetOut()


@router.post("/onboarding/complete", response_model=OnboardingOut)
def complete_onboarding(
    payload: OnboardingIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> OnboardingOut:
    service = OnboardingService(db=db)
    try:
        return service.complete(user=current_user, payload=payload)
    except OnboardingPermissionError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(exc),
        ) from exc


@router.delete("/account", response_model=AccountDeleteOut)
def delete_account(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_merchant_owner)],
) -> AccountDeleteOut:
    # Immediate, permanent delete (no recovery) — the UI warns the user clearly.
    # TODO(retention): later, switch to deactivate + `deletion_requested_at`, allow
    # recovery on login within a window, and purge via a scheduled Render cron job
    # (no long-running worker needed). Keep this anonymization as the purge step.
    # Soft-delete: deactivate and anonymize PII while preserving referential integrity.
    if not current_user.is_active:
        return AccountDeleteOut()

    current_user.is_active = False
    current_user.pin_hash = None
    current_user.full_name = None
    current_user.email = None
    # Keep within `users.phone_number` length (32) and unique.
    # UUID hex is 32 chars; we prefix with "deleted:" and trim to fit.
    current_user.phone_number = f"deleted:{current_user.id.hex}"[:32]
    db.add(current_user)
    db.commit()
    return AccountDeleteOut()
