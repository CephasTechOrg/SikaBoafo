"""Webhook routes."""

from __future__ import annotations

import logging
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.core.crypto import CryptoConfigError
from app.services.payment_service import (
    PaymentService,
    PaystackClientError,
    PaystackSecretKeyMissingError,
    PaystackWebhookPayloadError,
    PaystackWebhookSignatureError,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/webhooks", tags=["webhooks"])


@router.post("/paystack")
async def paystack_webhook(
    request: Request,
    db: Annotated[Session, Depends(get_db)],
    x_paystack_signature: Annotated[str | None, Header()] = None,
) -> dict[str, str]:
    """Receive Paystack webhook events.

    Return explicit HTTP failures so Paystack retries transient issues and stops
    on invalid signatures.
    """
    raw_body = await request.body()
    service = PaymentService(db=db)
    try:
        result = service.handle_paystack_webhook(
            raw_body=raw_body,
            signature=x_paystack_signature,
        )
        return {"status": result.status}
    except PaystackWebhookSignatureError as exc:
        logger.warning("Paystack webhook signature rejected: %s", exc)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except PaystackWebhookPayloadError as exc:
        logger.warning("Paystack webhook payload malformed: %s", exc)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except PaystackSecretKeyMissingError as exc:
        logger.error("Paystack secret key missing during webhook handling: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except CryptoConfigError as exc:
        logger.error("Crypto configuration error during webhook handling: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    except PaystackClientError as exc:
        logger.error("Paystack verify call failed during webhook handling: %s", exc)
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc
