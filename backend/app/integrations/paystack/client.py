"""Paystack HTTP client (M4 Step 2: transaction initiation)."""

from __future__ import annotations

import json
import logging
import time
from dataclasses import dataclass
from typing import Any
from urllib import error, parse, request

logger = logging.getLogger(__name__)
_RETRYABLE_HTTP_CODES = {429, 500, 502, 503, 504}
_MAX_ATTEMPTS = 3
_BACKOFF_SECONDS = 0.35


def _amount_kobo_from_paystack_data(data: dict[str, Any]) -> int | None:
    """Parse Paystack ``data.amount`` (kobo/minor units) from verify or charge JSON.

    Paystack usually returns an integer; some gateways return a float or numeric
    string. Missing or invalid amounts return ``None``.
    """
    raw = data.get("amount")
    if raw is None or isinstance(raw, bool):
        return None
    if isinstance(raw, int):
        return raw
    if isinstance(raw, str) and raw.strip():
        s = raw.strip()
        if s.isdigit():
            return int(s)
        try:
            return int(float(s))
        except ValueError:
            return None
    if isinstance(raw, float):
        if raw != raw or raw in (float("inf"), float("-inf")):
            return None
        return int(raw)
    return None


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
class PaystackChargeResult:
    reference: str
    status: str
    display_text: str | None
    raw_payload: dict[str, Any]


_BASE_HEADERS: dict[str, str] = {
    "User-Agent": "BizTrackGh-Python/1.0 (+https://biztrackgh-api.onrender.com)",
    "Accept": "application/json",
    "Content-Type": "application/json",
}


@dataclass(slots=True)
class PaystackClient:
    base_url: str = "https://api.paystack.co"
    timeout_seconds: float = 15.0

    def verify_secret_key(self, *, secret_key: str) -> None:
        """Verify a Paystack secret key via GET /transaction/verify/{ref}.

        We use a deliberately non-existent reference. A valid key returns 404
        (transaction not found — key accepted by Paystack). An invalid key returns
        401 before Paystack even looks up the reference. The /customer and /bank
        endpoints are blocked at CDN level for Render's IPs; the transaction
        endpoint is not.

        Raises PaystackClientError only for 401 (key rejected) or network errors.
        """
        url = f"{self.base_url.rstrip('/')}/transaction/verify/BTGH_key_check_probe"
        try:
            self._get_json(
                url=url,
                headers={
                    "Authorization": f"Bearer {secret_key}",
                    "Content-Type": "application/json",
                },
            )
        except PaystackClientError as exc:
            if exc.status_code in {400, 404}:
                # Paystack looked up the reference and found nothing — key is valid.
                # Paystack returns 400 (not 404) for non-existent transaction references.
                return
            if exc.status_code == 403:
                # Endpoint restricted at account level but key is recognised.
                return
            raise

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

    def charge_mobile_money(
        self,
        *,
        secret_key: str,
        email: str,
        amount_kobo: int,
        reference: str,
        currency: str,
        phone: str,
        provider: str,
        metadata: dict[str, Any] | None = None,
    ) -> PaystackChargeResult:
        """POST /charge — Ghana MoMo push (customer authorizes on their handset)."""
        url = f"{self.base_url.rstrip('/')}/charge"
        payload: dict[str, Any] = {
            "email": email,
            "amount": amount_kobo,
            "reference": reference,
            "currency": currency,
            "mobile_money": {
                "phone": phone,
                "provider": provider,
            },
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
        return _charge_result_from_raw(raw, fallback_reference=reference)

    def submit_charge_otp(
        self,
        *,
        secret_key: str,
        reference: str,
        otp: str,
    ) -> PaystackChargeResult:
        """POST /charge/submit_otp — complete MoMo flows that require OTP or voucher code."""
        url = f"{self.base_url.rstrip('/')}/charge/submit_otp"
        raw = self._post_json(
            url=url,
            headers={
                "Authorization": f"Bearer {secret_key}",
                "Content-Type": "application/json",
            },
            payload={"reference": reference, "otp": otp.strip()},
        )
        return _charge_result_from_raw(raw, fallback_reference=reference)

    def get_charge_transaction(
        self,
        *,
        secret_key: str,
        reference: str,
    ) -> PaystackVerifyResult:
        """GET /charge/{reference} for pending charge status (Paystack; e.g. MoMo)."""
        ref = str(reference).strip()
        safe = parse.quote(ref, safe="-._=")
        url = f"{self.base_url.rstrip('/')}/charge/{safe}"
        raw = self._get_json(
            url=url,
            headers={
                "Authorization": f"Bearer {secret_key}",
                "Content-Type": "application/json",
            },
        )
        data = raw.get("data")
        if raw.get("status") is not True or not isinstance(data, dict):
            msg = str(raw.get("message") or "Paystack charge lookup failed.")
            raise PaystackClientError(msg, response_body=raw)

        provider_reference = data.get("reference")
        if not isinstance(provider_reference, str) or not provider_reference.strip():
            provider_reference = ref

        payment_status = data.get("status")
        if not isinstance(payment_status, str) or not payment_status.strip():
            msg = "Paystack charge lookup response missing status."
            raise PaystackClientError(msg, response_body=raw)

        amount_kobo = _amount_kobo_from_paystack_data(data)

        paid_at_raw = data.get("paid_at") or data.get("paidAt")
        paid_at: str | None
        if paid_at_raw is None:
            paid_at = None
        elif isinstance(paid_at_raw, str):
            paid_at = paid_at_raw
        else:
            msg = "Paystack charge lookup response has invalid paid_at."
            raise PaystackClientError(msg, response_body=raw)

        return PaystackVerifyResult(
            reference=provider_reference.strip(),
            status=payment_status.strip().lower(),
            amount_kobo=amount_kobo,
            paid_at=paid_at,
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

        amount_kobo = _amount_kobo_from_paystack_data(data)

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
            headers={**_BASE_HEADERS, **headers},
            method="POST",
        )
        body: str | None = None
        for attempt in range(1, _MAX_ATTEMPTS + 1):
            try:
                with request.urlopen(req, timeout=self.timeout_seconds) as response:
                    body = response.read().decode("utf-8")
                    break
            except error.HTTPError as exc:
                raw = exc.read().decode("utf-8", errors="replace")
                parsed = _parse_json(raw)
                msg = _extract_error_message(parsed) or f"Paystack HTTP {exc.code}."
                retryable = exc.code in _RETRYABLE_HTTP_CODES and attempt < _MAX_ATTEMPTS
                logger.warning(
                    "Paystack POST failed endpoint=%s status=%s retryable=%s attempt=%s message=%s",
                    url,
                    exc.code,
                    retryable,
                    attempt,
                    msg,
                )
                if retryable:
                    time.sleep(_BACKOFF_SECONDS * attempt)
                    continue
                raise PaystackClientError(
                    msg,
                    status_code=exc.code,
                    response_body=parsed,
                ) from exc
            except error.URLError as exc:
                retryable = attempt < _MAX_ATTEMPTS
                logger.warning(
                    "Paystack POST unreachable endpoint=%s retryable=%s attempt=%s reason=%s",
                    url,
                    retryable,
                    attempt,
                    exc.reason,
                )
                if retryable:
                    time.sleep(_BACKOFF_SECONDS * attempt)
                    continue
                msg = f"Could not reach Paystack: {exc.reason!s}"
                raise PaystackClientError(msg) from exc

        parsed = _parse_json(body or "")
        if parsed is None:
            msg = "Paystack returned non-JSON payload."
            logger.warning("Paystack POST returned non-JSON payload: %.200s", body)
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
            headers={**_BASE_HEADERS, **headers},
            method="GET",
        )
        body: str | None = None
        for attempt in range(1, _MAX_ATTEMPTS + 1):
            try:
                with request.urlopen(req, timeout=self.timeout_seconds) as response:
                    body = response.read().decode("utf-8")
                    break
            except error.HTTPError as exc:
                raw = exc.read().decode("utf-8", errors="replace")
                parsed = _parse_json(raw)
                msg = _extract_error_message(parsed) or f"Paystack HTTP {exc.code}."
                retryable = exc.code in _RETRYABLE_HTTP_CODES and attempt < _MAX_ATTEMPTS
                logger.warning(
                    "Paystack GET failed endpoint=%s status=%s retryable=%s attempt=%s message=%s",
                    url,
                    exc.code,
                    retryable,
                    attempt,
                    msg,
                )
                if retryable:
                    time.sleep(_BACKOFF_SECONDS * attempt)
                    continue
                raise PaystackClientError(
                    msg,
                    status_code=exc.code,
                    response_body=parsed,
                ) from exc
            except error.URLError as exc:
                retryable = attempt < _MAX_ATTEMPTS
                logger.warning(
                    "Paystack GET unreachable endpoint=%s retryable=%s attempt=%s reason=%s",
                    url,
                    retryable,
                    attempt,
                    exc.reason,
                )
                if retryable:
                    time.sleep(_BACKOFF_SECONDS * attempt)
                    continue
                msg = f"Could not reach Paystack: {exc.reason!s}"
                raise PaystackClientError(msg) from exc

        parsed = _parse_json(body or "")
        if parsed is None:
            msg = "Paystack returned non-JSON payload."
            logger.warning("Paystack GET returned non-JSON payload: %.200s", body)
            raise PaystackClientError(msg)
        return parsed


def _charge_result_from_raw(
    raw: dict[str, Any],
    *,
    fallback_reference: str,
) -> PaystackChargeResult:
    data = raw.get("data")
    if raw.get("status") is not True or not isinstance(data, dict):
        msg = str(raw.get("message") or "Paystack charge response invalid.")
        raise PaystackClientError(msg, response_body=raw)

    provider_reference = data.get("reference")
    if not isinstance(provider_reference, str) or not provider_reference.strip():
        provider_reference = fallback_reference

    status_raw = data.get("status")
    status = (
        status_raw.strip().lower()
        if isinstance(status_raw, str) and status_raw.strip()
        else "pending"
    )

    display_text = data.get("display_text")
    if display_text is not None and not isinstance(display_text, str):
        display_text = None

    return PaystackChargeResult(
        reference=provider_reference,
        status=status,
        display_text=display_text,
        raw_payload=raw,
    )


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
