"""Webhook routes."""

from __future__ import annotations

import logging
from typing import Annotated

from fastapi import APIRouter, Depends, Header, Request
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

    Always returns 200 so Paystack does not retry.  Rejections and errors are
    logged server-side; the caller only sees a status string.
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
        return {"status": "rejected"}
    except PaystackWebhookPayloadError as exc:
        logger.warning("Paystack webhook payload malformed: %s", exc)
        return {"status": "rejected"}
    except PaystackSecretKeyMissingError as exc:
        logger.error("Paystack secret key missing during webhook handling: %s", exc)
        return {"status": "error"}
    except CryptoConfigError as exc:
        logger.error("Crypto configuration error during webhook handling: %s", exc)
        return {"status": "error"}
    except PaystackClientError as exc:
        logger.error("Paystack verify call failed during webhook handling: %s", exc)
        return {"status": "error"}
