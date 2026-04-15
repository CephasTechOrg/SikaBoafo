"""App-wide constants — use these instead of raw strings in services and validators.

DB columns stay plain VARCHAR/ENUM-free for simple migrations; Python references
these names so payment/sync terminology does not drift across modules.
"""

from typing import Final

DEFAULT_STORE_TIMEZONE: Final[str] = "Africa/Accra"
DEFAULT_CURRENCY: Final[str] = "GHS"

# Sale.payment_status — payment stage 1 is label-only; stage 2 adds provider-driven states.
PAYMENT_STATUS_RECORDED: Final[str] = "recorded"
PAYMENT_STATUS_PENDING_PROVIDER: Final[str] = "pending_provider"
PAYMENT_STATUS_SUCCEEDED: Final[str] = "succeeded"
PAYMENT_STATUS_FAILED: Final[str] = "failed"

# Payment.status — Paystack row lifecycle (server is source of truth after webhooks).
PROVIDER_PAYMENT_PENDING: Final[str] = "pending"
PROVIDER_PAYMENT_SUCCEEDED: Final[str] = "succeeded"
PROVIDER_PAYMENT_FAILED: Final[str] = "failed"

# Receivable.status
RECEIVABLE_STATUS_OPEN: Final[str] = "open"
RECEIVABLE_STATUS_SETTLED: Final[str] = "settled"

# Digital rail identifier stored on payments.provider
PAYMENT_PROVIDER_PAYSTACK: Final[str] = "paystack"

# users.role (expand when staff/cashier exist)
USER_ROLE_MERCHANT_OWNER: Final[str] = "merchant_owner"

# auth tokens
AUTH_TOKEN_TYPE_ACCESS: Final[str] = "access"
AUTH_TOKEN_TYPE_REFRESH: Final[str] = "refresh"
