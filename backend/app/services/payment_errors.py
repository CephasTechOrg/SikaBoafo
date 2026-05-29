"""Exception types raised by the payments service.

Extracted from ``payment_service`` (PAY-01) to keep that module focused on
orchestration. Re-exported from ``payment_service`` for backward compatibility.
"""

from __future__ import annotations


class PaymentInitiationContextError(Exception):
    """Caller has no merchant/store context."""


class PaymentInitiationTargetNotFoundError(Exception):
    """Requested payment target does not exist in caller scope."""


class PaymentInitiationStateError(Exception):
    """Receivable target exists but is not payable."""


class PaystackConnectionMissingError(Exception):
    """Merchant has no active Paystack connection."""


class PaystackSecretKeyMissingError(Exception):
    """Server-side Paystack secret key is not configured for selected mode."""


class PaymentGatewayError(Exception):
    """Downstream payment provider rejected the initiation request."""


class PaystackWebhookSignatureError(Exception):
    """Webhook signature failed validation."""


class PaystackWebhookPayloadError(Exception):
    """Webhook payload is malformed."""


__all__ = [
    "PaymentGatewayError",
    "PaymentInitiationContextError",
    "PaymentInitiationStateError",
    "PaymentInitiationTargetNotFoundError",
    "PaystackConnectionMissingError",
    "PaystackSecretKeyMissingError",
    "PaystackWebhookPayloadError",
    "PaystackWebhookSignatureError",
]
