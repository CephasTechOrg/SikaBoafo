"""Role-based access control: permission matrix shared by API dependencies.

Roles (see ``app.core.constants``):
- ``merchant_owner`` — full access (also the legacy default when ``role`` is NULL)
- ``manager``        — all daily operations + destructive ops (void/cancel/delete),
                       but NOT business configuration (staff, store, payment provider,
                       audit logs, account deletion)
- ``cashier``        — daily money movement: sales, receivables, expenses; read-only
                       on inventory
- ``stock_keeper``   — inventory management only; no money movement

Reads of operational data (lists/details) remain open to any authenticated staff;
this matrix governs mutating and destructive actions.
"""

from __future__ import annotations

from typing import Final

from app.core.constants import (
    USER_ROLE_CASHIER,
    USER_ROLE_MANAGER,
    USER_ROLE_MERCHANT_OWNER,
    USER_ROLE_STOCK_KEEPER,
)
from app.models.user import User

# --- Permissions -----------------------------------------------------------
PERM_INVENTORY_WRITE: Final[str] = "inventory:write"
PERM_INVENTORY_DELETE: Final[str] = "inventory:delete"
PERM_SALES_WRITE: Final[str] = "sales:write"
PERM_SALES_VOID: Final[str] = "sales:void"
PERM_RECEIVABLES_WRITE: Final[str] = "receivables:write"
PERM_RECEIVABLES_CANCEL: Final[str] = "receivables:cancel"
PERM_EXPENSES_WRITE: Final[str] = "expenses:write"

# Owner-exclusive business configuration. Enforced via get_merchant_owner today;
# listed here for documentation completeness.
PERM_STORE_MANAGE: Final[str] = "store:manage"
PERM_STAFF_MANAGE: Final[str] = "staff:manage"
PERM_PAYMENTS_CONFIG: Final[str] = "payments:config"
PERM_AUDIT_READ: Final[str] = "audit:read"
PERM_ACCOUNT_DELETE: Final[str] = "account:delete"

_OWNER_ONLY: Final[frozenset[str]] = frozenset(
    {
        PERM_STORE_MANAGE,
        PERM_STAFF_MANAGE,
        PERM_PAYMENTS_CONFIG,
        PERM_AUDIT_READ,
        PERM_ACCOUNT_DELETE,
    }
)

_MANAGER_PERMISSIONS: Final[frozenset[str]] = frozenset(
    {
        PERM_INVENTORY_WRITE,
        PERM_INVENTORY_DELETE,
        PERM_SALES_WRITE,
        PERM_SALES_VOID,
        PERM_RECEIVABLES_WRITE,
        PERM_RECEIVABLES_CANCEL,
        PERM_EXPENSES_WRITE,
    }
)

_CASHIER_PERMISSIONS: Final[frozenset[str]] = frozenset(
    {
        PERM_SALES_WRITE,
        PERM_RECEIVABLES_WRITE,
        PERM_EXPENSES_WRITE,
    }
)

_STOCK_KEEPER_PERMISSIONS: Final[frozenset[str]] = frozenset(
    {
        PERM_INVENTORY_WRITE,
    }
)

ROLE_PERMISSIONS: Final[dict[str, frozenset[str]]] = {
    USER_ROLE_MANAGER: _MANAGER_PERMISSIONS,
    USER_ROLE_CASHIER: _CASHIER_PERMISSIONS,
    USER_ROLE_STOCK_KEEPER: _STOCK_KEEPER_PERMISSIONS,
}


def is_merchant_owner(user: User) -> bool:
    """Legacy users without a persisted role are treated as owners."""
    return user.role in (None, USER_ROLE_MERCHANT_OWNER)


def has_permission(user: User, permission: str) -> bool:
    """Return True if the user's role grants ``permission``.

    Owners (and legacy NULL-role users) implicitly have every permission.
    """
    if is_merchant_owner(user):
        return True
    return permission in ROLE_PERMISSIONS.get(user.role or "", frozenset())


__all__ = [
    "PERM_ACCOUNT_DELETE",
    "PERM_AUDIT_READ",
    "PERM_EXPENSES_WRITE",
    "PERM_INVENTORY_DELETE",
    "PERM_INVENTORY_WRITE",
    "PERM_PAYMENTS_CONFIG",
    "PERM_RECEIVABLES_CANCEL",
    "PERM_RECEIVABLES_WRITE",
    "PERM_SALES_VOID",
    "PERM_SALES_WRITE",
    "PERM_STAFF_MANAGE",
    "PERM_STORE_MANAGE",
    "ROLE_PERMISSIONS",
    "has_permission",
    "is_merchant_owner",
]
