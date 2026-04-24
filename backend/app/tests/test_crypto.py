"""Crypto helper tests for merchant-owned payment credentials."""

from __future__ import annotations

from cryptography.fernet import Fernet

from app.core.crypto import CryptoConfigError, decrypt_text, encrypt_text


def test_encrypt_decrypt_round_trip() -> None:
    key = Fernet.generate_key().decode("utf-8")
    ciphertext = encrypt_text(plaintext="sk_test_abcdef123456", key=key)
    assert ciphertext != "sk_test_abcdef123456"
    assert decrypt_text(ciphertext=ciphertext, key=key) == "sk_test_abcdef123456"


def test_encrypt_requires_valid_key() -> None:
    try:
        encrypt_text(plaintext="secret", key=None)
    except CryptoConfigError as exc:
        assert "PAYMENT_CONFIG_ENCRYPTION_KEY" in str(exc)
    else:  # pragma: no cover - safety branch
        raise AssertionError("Expected encryption config failure.")


def test_decrypt_rejects_wrong_key() -> None:
    good_key = Fernet.generate_key().decode("utf-8")
    bad_key = Fernet.generate_key().decode("utf-8")
    ciphertext = encrypt_text(plaintext="sk_test_abcdef123456", key=good_key)
    try:
        decrypt_text(ciphertext=ciphertext, key=bad_key)
    except CryptoConfigError as exc:
        assert "could not be decrypted" in str(exc).lower()
    else:  # pragma: no cover - safety branch
        raise AssertionError("Expected decryption failure.")
