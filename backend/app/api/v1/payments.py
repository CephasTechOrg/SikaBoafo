"""Payment settings and payment routes."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db, require_role
from app.core.constants import USER_ROLE_MERCHANT_OWNER
from app.models.user import User
from app.schemas.payment import (
    PaymentInitiateIn,
    PaymentInitiateOut,
    SalePaymentInitiateIn,
    SalePaymentInitiateOut,
)
from app.schemas.payment_settings import PaystackConnectionOut, PaystackConnectionUpdateIn
from app.services.payment_service import (
    PaymentInitiationContextError,
    PaymentInitiationStateError,
    PaymentInitiationTargetNotFoundError,
    PaymentService,
    PaystackClientError,
    PaystackConnectionMissingError,
    PaystackSecretKeyMissingError,
)
from app.services.payment_settings_service import (
    PaymentSettingsContextError,
    PaymentSettingsService,
)

router = APIRouter(prefix="/payments", tags=["payments"])

_OwnerOnly = Annotated[User, Depends(require_role(USER_ROLE_MERCHANT_OWNER))]
_Authenticated = Annotated[User, Depends(get_current_user)]


@router.get("/paystack/connection", response_model=PaystackConnectionOut)
def get_paystack_connection(
    db: Annotated[Session, Depends(get_db)],
    current_user: _OwnerOnly,
) -> PaystackConnectionOut:
    service = PaymentSettingsService(db=db)
    try:
        return service.get_paystack_connection(owner_user_id=current_user.id)
    except PaymentSettingsContextError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.put("/paystack/connection", response_model=PaystackConnectionOut)
def upsert_paystack_connection(
    payload: PaystackConnectionUpdateIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: _OwnerOnly,
) -> PaystackConnectionOut:
    service = PaymentSettingsService(db=db)
    try:
        return service.upsert_paystack_connection(
            owner_user_id=current_user.id,
            payload=payload,
        )
    except PaymentSettingsContextError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.delete("/paystack/connection", response_model=PaystackConnectionOut)
def disconnect_paystack_connection(
    db: Annotated[Session, Depends(get_db)],
    current_user: _OwnerOnly,
) -> PaystackConnectionOut:
    service = PaymentSettingsService(db=db)
    try:
        return service.disconnect_paystack_connection(owner_user_id=current_user.id)
    except PaymentSettingsContextError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.post("/initiate", response_model=PaymentInitiateOut)
def initiate_payment(
    payload: PaymentInitiateIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: _Authenticated,
) -> PaymentInitiateOut:
    service = PaymentService(db=db)
    try:
        initiated = service.initiate_receivable_payment(
            user_id=current_user.id,
            receivable_id=payload.receivable_id,
        )
    except PaymentInitiationContextError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except PaymentInitiationTargetNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except (PaymentInitiationStateError, PaystackConnectionMissingError) as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except PaystackSecretKeyMissingError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except PaystackClientError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    return PaymentInitiateOut(
        payment_id=initiated.payment_id,
        provider=initiated.provider,
        provider_reference=initiated.provider_reference,
        checkout_url=initiated.checkout_url,
        access_code=initiated.access_code,
        amount=initiated.amount,
        currency=initiated.currency,
        status=initiated.status,
        receivable_id=initiated.receivable_id,
    )


@router.post("/initiate-sale", response_model=SalePaymentInitiateOut)
def initiate_sale_payment(
    payload: SalePaymentInitiateIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: _Authenticated,
) -> SalePaymentInitiateOut:
    service = PaymentService(db=db)
    try:
        initiated = service.initiate_sale_payment(
            user_id=current_user.id,
            sale_id=payload.sale_id,
        )
    except PaymentInitiationContextError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except PaymentInitiationTargetNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except (PaymentInitiationStateError, PaystackConnectionMissingError) as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except PaystackSecretKeyMissingError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except PaystackClientError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    return SalePaymentInitiateOut(
        payment_id=initiated.payment_id,
        provider=initiated.provider,
        provider_reference=initiated.provider_reference,
        checkout_url=initiated.checkout_url,
        access_code=initiated.access_code,
        amount=initiated.amount,
        currency=initiated.currency,
        status=initiated.status,
        sale_id=initiated.sale_id,
    )
