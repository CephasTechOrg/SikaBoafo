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

# Sale.sale_status — lifecycle of the sale record itself.
SALE_STATUS_RECORDED: Final[str] = "recorded"
SALE_STATUS_VOIDED: Final[str] = "voided"

# Payment.status — Paystack row lifecycle (server is source of truth after webhooks).
PROVIDER_PAYMENT_PENDING: Final[str] = "pending"
PROVIDER_PAYMENT_SUCCEEDED: Final[str] = "succeeded"
PROVIDER_PAYMENT_FAILED: Final[str] = "failed"

# Receivable.status
RECEIVABLE_STATUS_OPEN: Final[str] = "open"
RECEIVABLE_STATUS_PARTIALLY_PAID: Final[str] = "partially_paid"
RECEIVABLE_STATUS_SETTLED: Final[str] = "settled"
RECEIVABLE_STATUS_CANCELLED: Final[str] = "cancelled"

# Digital rail identifier stored on payments.provider
PAYMENT_PROVIDER_PAYSTACK: Final[str] = "paystack"
PAYSTACK_MODE_TEST: Final[str] = "test"
PAYSTACK_MODE_LIVE: Final[str] = "live"

# users.role
USER_ROLE_MERCHANT_OWNER: Final[str] = "merchant_owner"
USER_ROLE_MANAGER: Final[str] = "manager"
USER_ROLE_CASHIER: Final[str] = "cashier"
USER_ROLE_STOCK_KEEPER: Final[str] = "stock_keeper"

# staff_invites.status
STAFF_INVITE_STATUS_PENDING: Final[str] = "pending"
STAFF_INVITE_STATUS_ACCEPTED: Final[str] = "accepted"
STAFF_INVITE_STATUS_EXPIRED: Final[str] = "expired"

# inventory movement_type
INVENTORY_MOVEMENT_STOCK_IN: Final[str] = "stock_in"
INVENTORY_MOVEMENT_ADJUSTMENT: Final[str] = "adjustment"
INVENTORY_MOVEMENT_SALE: Final[str] = "sale"

# sync apply status labels
SYNC_STATUS_APPLIED: Final[str] = "applied"
SYNC_STATUS_DUPLICATE: Final[str] = "duplicate"
SYNC_STATUS_CONFLICT: Final[str] = "conflict"
SYNC_STATUS_FAILED: Final[str] = "failed"
SYNC_STATUS_REJECTED: Final[str] = "rejected"

# Sale.payment_method_label (MVP)
PAYMENT_METHOD_CASH: Final[str] = "cash"
PAYMENT_METHOD_MOBILE_MONEY: Final[str] = "mobile_money"
PAYMENT_METHOD_BANK_TRANSFER: Final[str] = "bank_transfer"

# auth tokens
AUTH_TOKEN_TYPE_ACCESS: Final[str] = "access"
AUTH_TOKEN_TYPE_REFRESH: Final[str] = "refresh"
