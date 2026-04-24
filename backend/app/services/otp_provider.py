"""Locally managed OTP generation/verification with Arkesel SMS delivery."""

from __future__ import annotations

import hashlib
import hmac
import json
import logging
import secrets
import string
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from urllib import error, parse, request

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.models.otp_code import OtpCode

logger = logging.getLogger(__name__)

_MAX_VERIFY_ATTEMPTS = 5


class OtpProviderError(RuntimeError):
    """Base exception for OTP provider failures."""


class OtpVerificationFailedError(OtpProviderError):
    """Raised when the provided OTP code is invalid."""


@dataclass(slots=True)
class GenerateOtpResult:
    provider_reference: str | None
    expires_in_minutes: int


class ArkeselOtpProvider:
    def __init__(self, *, db: Session, settings: Settings) -> None:
        self.db = db
        self.settings = settings

    def generate(self, *, phone_number: str) -> GenerateOtpResult:
        if self.settings.auth_mock_otp_code:
            logger.info("OTP generate: mode=mock phone=%s", phone_number)
            return GenerateOtpResult(
                provider_reference="mock-otp",
                expires_in_minutes=self.settings.arkesel_otp_expiry_minutes,
            )

        logger.info("OTP generate: mode=local+arkesel-sms phone=%s", phone_number)
        now = datetime.now(tz=UTC)
        self._invalidate_active_codes(phone_number=phone_number, now=now)

        code = self._generate_code()
        otp = OtpCode(
            phone_number=phone_number,
            code_hash=self._hash_code(phone_number=phone_number, code=code),
            expires_at=now + timedelta(minutes=self.settings.arkesel_otp_expiry_minutes),
            delivery_provider="arkesel",
        )
        self.db.add(otp)
        self.db.flush()

        message = (
            "Your BizTrack code is %otp_code%. Expires in %expiry% minutes."
            .replace("%otp_code%", code)
            .replace("%expiry%", str(self.settings.arkesel_otp_expiry_minutes))
        )
        reference = self._send_sms(phone_number=phone_number, message=message)
        otp.delivery_reference = reference
        self.db.add(otp)
        logger.info(
            "OTP generate success: phone=%s provider_reference=%s otp_id=%s",
            phone_number,
            reference,
            otp.id,
        )
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

        logger.info("OTP verify: mode=local-db phone=%s", phone_number)
        now = datetime.now(tz=UTC)
        otp = self.db.scalar(
            select(OtpCode)
            .where(
                OtpCode.phone_number == phone_number,
                OtpCode.used_at.is_(None),
            )
            .order_by(OtpCode.created_at.desc())
            .limit(1)
        )
        if otp is None:
            raise OtpVerificationFailedError("No active verification code found.")
        expires_at = self._as_utc(otp.expires_at)
        if expires_at <= now:
            otp.used_at = now
            self.db.add(otp)
            self.db.commit()
            raise OtpVerificationFailedError("Verification code has expired.")
        if otp.attempt_count >= _MAX_VERIFY_ATTEMPTS:
            otp.used_at = now
            self.db.add(otp)
            self.db.commit()
            raise OtpVerificationFailedError("Too many verification attempts.")

        otp.attempt_count += 1
        if not secrets.compare_digest(
            otp.code_hash,
            self._hash_code(phone_number=phone_number, code=code),
        ):
            self.db.add(otp)
            self.db.commit()
            raise OtpVerificationFailedError("Invalid verification code.")

        otp.used_at = now
        self.db.add(otp)

    def _send_sms(self, *, phone_number: str, message: str) -> str | None:
        if not self.settings.arkesel_api_key:
            msg = "ARKESEL_API_KEY is missing."
            raise OtpProviderError(msg)

        base = self.settings.arkesel_base_url.rstrip("/")
        query = parse.urlencode(
            {
                "action": "send-sms",
                "api_key": self.settings.arkesel_api_key,
            }
        )
        endpoint = f"{base}/sms/api?{query}"
        payload = {
            "action": "send-sms",
            "api_key": self.settings.arkesel_api_key,
            "to": phone_number,
            "from": self.settings.arkesel_sender_id,
            "sms": message,
        }
        response = self._post_json(endpoint=endpoint, payload=payload)
        logger.info("OTP SMS response: phone=%s payload=%s", phone_number, response)
        provider_code = str(response.get("code") or "").strip().lower()
        if provider_code != "ok":
            provider_message = str(response.get("message") or "SMS delivery failed.").strip()
            logger.warning(
                "OTP SMS provider returned failure: code=%s response=%s",
                provider_code or "<missing>",
                response,
            )
            raise OtpProviderError(
                f"{provider_message} [provider_code={provider_code or 'unknown'}]"
            )
        return self._extract_reference(response)

    def _post_json(self, *, endpoint: str, payload: dict[str, object]) -> dict[str, object]:
        raw_body = json.dumps(payload).encode("utf-8")
        req = request.Request(
            endpoint,
            data=raw_body,
            headers={
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
            raise OtpProviderError("Unable to reach SMS provider.") from exc

        if not body:
            return {}
        try:
            return json.loads(body)
        except json.JSONDecodeError:
            logger.warning("Arkesel returned non-JSON response body.")
            return {}

    def _invalidate_active_codes(self, *, phone_number: str, now: datetime) -> None:
        rows = self.db.scalars(
            select(OtpCode).where(
                OtpCode.phone_number == phone_number,
                OtpCode.used_at.is_(None),
            )
        ).all()
        for row in rows:
            row.used_at = now
            self.db.add(row)

    def _generate_code(self) -> str:
        length = self.settings.arkesel_otp_length
        otp_type = self.settings.arkesel_otp_type.strip().lower()
        alphabet = string.digits if otp_type == "numeric" else string.ascii_uppercase + string.digits
        return "".join(secrets.choice(alphabet) for _ in range(length))

    def _hash_code(self, *, phone_number: str, code: str) -> str:
        digest = hmac.new(
            self.settings.secret_key.encode("utf-8"),
            f"{phone_number}:{code}".encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        return digest

    @staticmethod
    def _extract_reference(response: dict[str, object]) -> str | None:
        if isinstance(response.get("data"), dict):
            nested = response["data"]
            return nested.get("id") or nested.get("reference")
        reference = response.get("reference")
        return str(reference) if reference is not None else None

    @staticmethod
    def _as_utc(value: datetime) -> datetime:
        return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)
