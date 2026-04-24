"""Encryption helpers for merchant-owned payment configuration."""

from __future__ import annotations

from cryptography.fernet import Fernet, InvalidToken


class CryptoConfigError(RuntimeError):
    """Required encryption configuration is missing or invalid."""


def encrypt_text(*, plaintext: str, key: str | None) -> str:
    fernet = _fernet(key=key)
    return fernet.encrypt(plaintext.encode("utf-8")).decode("utf-8")


def decrypt_text(*, ciphertext: str, key: str | None) -> str:
    fernet = _fernet(key=key)
    try:
        return fernet.decrypt(ciphertext.encode("utf-8")).decode("utf-8")
    except InvalidToken as exc:  # pragma: no cover - branch covered via tests
        raise CryptoConfigError("Stored payment credential could not be decrypted.") from exc


def _fernet(*, key: str | None) -> Fernet:
    normalized = (key or "").strip()
    if not normalized:
        raise CryptoConfigError("PAYMENT_CONFIG_ENCRYPTION_KEY is missing.")
    try:
        return Fernet(normalized.encode("utf-8"))
    except (ValueError, TypeError) as exc:
        raise CryptoConfigError("PAYMENT_CONFIG_ENCRYPTION_KEY is invalid.") from exc
