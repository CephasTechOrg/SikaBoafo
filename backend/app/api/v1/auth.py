"""Auth endpoints: SMS OTP (signup/recovery) and PIN login/set."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.core.config import Settings, get_settings
from app.models.user import User
from app.schemas.auth import (
    OnboardingIn,
    OnboardingOut,
    OtpRequestIn,
    OtpRequestOut,
    OtpVerifyIn,
    PinLoginIn,
    RefreshTokenIn,
    PinSetIn,
    PinSetOut,
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
from app.services.phone_number import InvalidPhoneNumberError

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
    except InvalidPinLoginError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid phone number or PIN.",
        ) from exc


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
