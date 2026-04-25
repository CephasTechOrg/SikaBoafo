"""Paystack HTTP client (M4 Step 2: transaction initiation)."""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from typing import Any
from urllib import error, request

logger = logging.getLogger(__name__)


class PaystackClientError(Exception):
    """Paystack request failed or returned an invalid payload."""

    def __init__(
        self,
        message: str,
        *,
        status_code: int | None = None,
        response_body: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.response_body = response_body


@dataclass(slots=True)
class PaystackInitializeResult:
    authorization_url: str
    access_code: str | None
    reference: str
    raw_payload: dict[str, Any]


@dataclass(slots=True)
class PaystackVerifyResult:
    reference: str
    status: str
    amount_kobo: int | None
    paid_at: str | None
    raw_payload: dict[str, Any]


@dataclass(slots=True)
class PaystackClient:
    base_url: str = "https://api.paystack.co"
    timeout_seconds: float = 15.0

    def verify_secret_key(self, *, secret_key: str) -> None:
        """Verify a Paystack secret key using GET /bank.

        /bank is a simple read-only endpoint that works for any valid sk_test_ or
        sk_live_ key with no special account permissions. Invalid keys return 401.
        Raises PaystackClientError if the key is rejected or Paystack is unreachable.
        """
        url = f"{self.base_url.rstrip('/')}/bank"
        raw = self._get_json(
            url=url,
            headers={
                "Authorization": f"Bearer {secret_key}",
                "Content-Type": "application/json",
            },
        )
        if raw.get("status") is not True:
            msg = str(raw.get("message") or "Paystack credential verification failed.")
            raise PaystackClientError(msg, response_body=raw)

    def initialize_transaction(
        self,
        *,
        secret_key: str,
        email: str,
        amount_kobo: int,
        reference: str,
        currency: str,
        metadata: dict[str, Any] | None = None,
    ) -> PaystackInitializeResult:
        url = f"{self.base_url.rstrip('/')}/transaction/initialize"
        payload: dict[str, Any] = {
            "email": email,
            "amount": amount_kobo,
            "reference": reference,
            "currency": currency,
        }
        if metadata:
            payload["metadata"] = metadata

        raw = self._post_json(
            url=url,
            headers={
                "Authorization": f"Bearer {secret_key}",
                "Content-Type": "application/json",
            },
            payload=payload,
        )
        data = raw.get("data")
        if raw.get("status") is not True or not isinstance(data, dict):
            msg = str(raw.get("message") or "Paystack initialization failed.")
            raise PaystackClientError(msg, response_body=raw)

        authorization_url = data.get("authorization_url")
        if not isinstance(authorization_url, str) or not authorization_url.strip():
            msg = "Paystack response missing authorization_url."
            raise PaystackClientError(msg, response_body=raw)

        access_code = data.get("access_code")
        if access_code is not None and not isinstance(access_code, str):
            msg = "Paystack response has invalid access_code."
            raise PaystackClientError(msg, response_body=raw)

        provider_reference = data.get("reference")
        if not isinstance(provider_reference, str) or not provider_reference.strip():
            provider_reference = reference

        return PaystackInitializeResult(
            authorization_url=authorization_url,
            access_code=access_code,
            reference=provider_reference,
            raw_payload=raw,
        )

    def verify_transaction(
        self,
        *,
        secret_key: str,
        reference: str,
    ) -> PaystackVerifyResult:
        url = f"{self.base_url.rstrip('/')}/transaction/verify/{reference}"
        raw = self._get_json(
            url=url,
            headers={
                "Authorization": f"Bearer {secret_key}",
                "Content-Type": "application/json",
            },
        )
        data = raw.get("data")
        if raw.get("status") is not True or not isinstance(data, dict):
            msg = str(raw.get("message") or "Paystack verify failed.")
            raise PaystackClientError(msg, response_body=raw)

        provider_reference = data.get("reference")
        if not isinstance(provider_reference, str) or not provider_reference.strip():
            provider_reference = reference

        payment_status = data.get("status")
        if not isinstance(payment_status, str) or not payment_status.strip():
            msg = "Paystack verify response missing status."
            raise PaystackClientError(msg, response_body=raw)

        amount_kobo_raw = data.get("amount")
        amount_kobo: int | None
        if isinstance(amount_kobo_raw, int):
            amount_kobo = amount_kobo_raw
        elif isinstance(amount_kobo_raw, str) and amount_kobo_raw.isdigit():
            amount_kobo = int(amount_kobo_raw)
        else:
            amount_kobo = None

        paid_at = data.get("paid_at")
        if paid_at is not None and not isinstance(paid_at, str):
            msg = "Paystack verify response has invalid paid_at."
            raise PaystackClientError(msg, response_body=raw)

        return PaystackVerifyResult(
            reference=provider_reference,
            status=payment_status.strip().lower(),
            amount_kobo=amount_kobo,
            paid_at=paid_at,
            raw_payload=raw,
        )

    def _post_json(
        self,
        *,
        url: str,
        headers: dict[str, str],
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        req = request.Request(
            url=url,
            data=json.dumps(payload).encode("utf-8"),
            headers=headers,
            method="POST",
        )
        try:
            with request.urlopen(req, timeout=self.timeout_seconds) as response:
                body = response.read().decode("utf-8")
        except error.HTTPError as exc:
            raw = exc.read().decode("utf-8", errors="replace")
            parsed = _parse_json(raw)
            msg = _extract_error_message(parsed) or f"Paystack HTTP {exc.code}."
            logger.warning(
                "Paystack initialize request failed: status=%s message=%s payload=%s",
                exc.code,
                msg,
                parsed,
            )
            raise PaystackClientError(
                msg,
                status_code=exc.code,
                response_body=parsed,
            ) from exc
        except error.URLError as exc:
            msg = f"Could not reach Paystack: {exc.reason!s}"
            logger.warning("Paystack initialize request unreachable: reason=%s", exc.reason)
            raise PaystackClientError(msg) from exc

        parsed = _parse_json(body)
        if parsed is None:
            msg = "Paystack returned non-JSON payload."
            logger.warning("Paystack initialize returned non-JSON payload.")
            raise PaystackClientError(msg)
        return parsed

    def _get_json(
        self,
        *,
        url: str,
        headers: dict[str, str],
    ) -> dict[str, Any]:
        req = request.Request(
            url=url,
            headers=headers,
            method="GET",
        )
        try:
            with request.urlopen(req, timeout=self.timeout_seconds) as response:
                body = response.read().decode("utf-8")
        except error.HTTPError as exc:
            raw = exc.read().decode("utf-8", errors="replace")
            parsed = _parse_json(raw)
            msg = _extract_error_message(parsed) or f"Paystack HTTP {exc.code}."
            logger.warning(
                "Paystack verify request failed: status=%s message=%s payload=%s",
                exc.code,
                msg,
                parsed,
            )
            raise PaystackClientError(
                msg,
                status_code=exc.code,
                response_body=parsed,
            ) from exc
        except error.URLError as exc:
            msg = f"Could not reach Paystack: {exc.reason!s}"
            logger.warning("Paystack verify request unreachable: reason=%s", exc.reason)
            raise PaystackClientError(msg) from exc

        parsed = _parse_json(body)
        if parsed is None:
            msg = "Paystack returned non-JSON payload."
            logger.warning("Paystack verify returned non-JSON payload.")
            raise PaystackClientError(msg)
        return parsed


def _parse_json(raw: str) -> dict[str, Any] | None:
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return None
    return parsed if isinstance(parsed, dict) else None


def _extract_error_message(payload: dict[str, Any] | None) -> str | None:
    if payload is None:
        return None
    message = payload.get("message")
    return message if isinstance(message, str) and message.strip() else None
