"""Payment settings and payment routes."""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db, require_role
from app.core.constants import USER_ROLE_MERCHANT_OWNER
from app.core.crypto import CryptoConfigError
from app.models.user import User
from app.schemas.payment import (
    PaymentInitiateIn,
    PaymentInitiateOut,
    PaymentVerifyOut,
    SaleMomoChargeIn,
    SaleMomoChargeOut,
    SaleMomoOtpIn,
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
    PaymentSettingsValidationError,
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
    except PaymentSettingsValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except CryptoConfigError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except PaystackClientError as exc:
        status_code = (
            status.HTTP_400_BAD_REQUEST
            if exc.status_code == 401
            else status.HTTP_502_BAD_GATEWAY
        )
        raise HTTPException(status_code=status_code, detail=str(exc)) from exc


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
    except CryptoConfigError as exc:
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
    except CryptoConfigError as exc:
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


@router.post("/sales/{sale_id}/momo-charge", response_model=SaleMomoChargeOut)
def initiate_sale_momo_charge(
    sale_id: UUID,
    payload: SaleMomoChargeIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: _Authenticated,
) -> SaleMomoChargeOut:
    service = PaymentService(db=db)
    try:
        charged = service.initiate_sale_momo_charge(
            user_id=current_user.id,
            sale_id=sale_id,
            phone=payload.phone,
            provider=payload.provider,
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
    except CryptoConfigError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except PaystackClientError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    return SaleMomoChargeOut(
        payment_id=charged.payment_id,
        provider=charged.provider,
        provider_reference=charged.provider_reference,
        amount=charged.amount,
        currency=charged.currency,
        status=charged.status,
        sale_id=charged.sale_id,
        display_text=charged.display_text,
        needs_otp=charged.needs_otp,
    )


@router.post("/{payment_id}/submit-momo-otp", response_model=PaymentVerifyOut)
def submit_sale_momo_otp(
    payment_id: UUID,
    payload: SaleMomoOtpIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: _Authenticated,
) -> PaymentVerifyOut:
    service = PaymentService(db=db)
    try:
        out = service.submit_sale_momo_otp(
            user_id=current_user.id,
            payment_id=payment_id,
            otp=payload.otp,
        )
    except PaymentInitiationContextError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except PaymentInitiationTargetNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except PaymentInitiationStateError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except PaystackSecretKeyMissingError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except CryptoConfigError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except PaystackClientError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    return PaymentVerifyOut(
        payment_id=out.payment_id,
        sale_id=out.sale_id,
        provider_payment_status=out.provider_payment_status,
        sale_payment_status=out.sale_payment_status,
        paystack_transaction_status=out.paystack_transaction_status,
    )


@router.post("/{payment_id}/verify", response_model=PaymentVerifyOut)
def verify_sale_payment(
    payment_id: UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: _Authenticated,
) -> PaymentVerifyOut:
    service = PaymentService(db=db)
    try:
        out = service.verify_sale_payment(
            user_id=current_user.id,
            payment_id=payment_id,
        )
    except PaymentInitiationContextError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except PaymentInitiationTargetNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except PaymentInitiationStateError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except PaystackSecretKeyMissingError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except CryptoConfigError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except PaystackClientError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    return PaymentVerifyOut(
        payment_id=out.payment_id,
        sale_id=out.sale_id,
        provider_payment_status=out.provider_payment_status,
        sale_payment_status=out.sale_payment_status,
        paystack_transaction_status=out.paystack_transaction_status,
    )
