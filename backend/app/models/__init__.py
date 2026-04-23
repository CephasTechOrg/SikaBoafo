"""Import all ORM modules so ``Base.metadata`` is complete for Alembic and ``init_db``.

Order does not matter for registration; list stays explicit so new models are a conscious add.
"""

from app.models.audit_log import AuditLog
from app.models.customer import Customer
from app.models.expense import Expense
from app.models.inventory import InventoryBalance, InventoryMovement
from app.models.item import Item
from app.models.merchant import Merchant
from app.models.payment import Payment
from app.models.receivable import Receivable, ReceivablePayment
from app.models.sale import Sale, SaleItem
from app.models.staff_invite import StaffInvite
from app.models.store import Store
from app.models.sync_operation import SyncOperation
from app.models.user import User

__all__ = [
    "AuditLog",
    "Customer",
    "Expense",
    "InventoryBalance",
    "InventoryMovement",
    "Item",
    "Merchant",
    "Payment",
    "Receivable",
    "ReceivablePayment",
    "Sale",
    "SaleItem",
    "StaffInvite",
    "Store",
    "SyncOperation",
    "User",
]
