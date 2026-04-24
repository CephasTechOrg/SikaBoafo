"""Arkesel OTP integration plus local-dev fallback mode."""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from urllib import error, request

from app.core.config import Settings

logger = logging.getLogger(__name__)


class OtpProviderError(RuntimeError):
    """Base exception for OTP provider failures."""


class OtpVerificationFailedError(OtpProviderError):
    """Raised when the provided OTP code is invalid."""


@dataclass(slots=True)
class GenerateOtpResult:
    provider_reference: str | None
    expires_in_minutes: int


class ArkeselOtpProvider:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def generate(self, *, phone_number: str) -> GenerateOtpResult:
        if self.settings.auth_mock_otp_code:
            logger.info("OTP generate: mode=mock phone=%s", phone_number)
            return GenerateOtpResult(
                provider_reference="mock-otp",
                expires_in_minutes=self.settings.arkesel_otp_expiry_minutes,
            )

        logger.info("OTP generate: mode=arkesel phone=%s", phone_number)
        payload = {
            "number": phone_number,
            "expiry": self.settings.arkesel_otp_expiry_minutes,
            "length": self.settings.arkesel_otp_length,
            "type": self.settings.arkesel_otp_type,
            "medium": self.settings.arkesel_otp_medium,
            "sender_id": self.settings.arkesel_sender_id,
            "message": "Your BizTrack code is %otp_code%. Expires in %expiry% minutes.",
        }
        response = self._post_json("/api/otp/generate", payload)
        reference = None
        if isinstance(response.get("data"), dict):
            reference = response["data"].get("id") or response["data"].get("reference")
        logger.info("OTP generate success: phone=%s provider_reference=%s", phone_number, reference)
        return GenerateOtpResult(
            provider_reference=reference,
            expires_in_minutes=self.settings.arkesel_otp_expiry_minutes,
        )

    def verify(self, *, phone_number: str, code: str) -> None:
        if self.settings.auth_mock_otp_code:
            logger.info("OTP verify: mode=mock phone=%s", phone_number)
            if code != self.settings.auth_mock_otp_code:
                raise OtpVerificationFailedError("Invalid verification code.")
            return

        logger.info("OTP verify: mode=arkesel phone=%s", phone_number)
        payload = {"number": phone_number, "code": code}
        try:
            self._post_json("/api/otp/verify", payload)
        except OtpProviderError as exc:
            # Arkesel commonly uses 4xx/422 for invalid code; collapse to auth failure.
            if "422" in str(exc) or "401" in str(exc):
                raise OtpVerificationFailedError("Invalid verification code.") from exc
            raise

    def _post_json(self, path: str, payload: dict[str, object]) -> dict[str, object]:
        if not self.settings.arkesel_api_key:
            msg = "ARKESEL_API_KEY is missing."
            raise OtpProviderError(msg)

        base = self.settings.arkesel_base_url.rstrip("/")
        endpoint = f"{base}{path}"
        raw_body = json.dumps(payload).encode("utf-8")
        req = request.Request(
            endpoint,
            data=raw_body,
            headers={
                "api-key": self.settings.arkesel_api_key,
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
            method="POST",
        )
        try:
            with request.urlopen(req, timeout=30) as resp:
                body = resp.read().decode("utf-8")
        except error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="ignore")
            logger.warning("Arkesel request failed: status=%s body=%s", exc.code, body)
            raise OtpProviderError(f"Provider request failed ({exc.code}).") from exc
        except error.URLError as exc:
            raise OtpProviderError("Unable to reach OTP provider.") from exc

        if not body:
            return {}
        try:
            return json.loads(body)
        except json.JSONDecodeError:
            logger.warning("Arkesel returned non-JSON response body.")
            return {}
