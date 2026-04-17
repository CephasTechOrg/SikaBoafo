"""Sync apply service (idempotent operation intake)."""

from __future__ import annotations

from dataclasses import dataclass
from uuid import UUID

from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.constants import (
    SYNC_STATUS_APPLIED,
    SYNC_STATUS_CONFLICT,
    SYNC_STATUS_DUPLICATE,
    SYNC_STATUS_FAILED,
    SYNC_STATUS_REJECTED,
)
from app.models.sync_operation import SyncOperation
from app.schemas.expense import ExpenseCreateIn, SyncExpenseCreateIn
from app.schemas.inventory import (
    ItemCreateIn,
    ItemUpdateIn,
    SyncItemUpdateIn,
    SyncStockAdjustIn,
    SyncStockInIn,
)
from app.schemas.receivable import (
    CustomerCreateIn,
    ReceivableCreateIn,
    ReceivablePaymentCreateIn,
    SyncCustomerCreateIn,
    SyncReceivableCreateIn,
    SyncReceivablePaymentCreateIn,
)
from app.schemas.sale import SaleCreateIn, SyncSaleCreateIn
from app.schemas.sync import SyncOperationIn
from app.services.expense_service import ExpenseContextMissingError, ExpenseService
from app.services.inventory_service import (
    InvalidInventoryAdjustmentError,
    InventoryItemNotFoundError,
    InventoryService,
    MerchantContextMissingError,
)
from app.services.receivables_service import (
    CustomerNotFoundError,
    InvalidRepaymentError,
    ReceivableContextMissingError,
    ReceivableNotFoundError,
    ReceivablesService,
)
from app.services.sales_service import (
    InsufficientStockError,
    SaleContextMissingError,
    SaleItemNotFoundError,
    SalesService,
)


class UnsupportedSyncOperationError(Exception):
    """Operation is not supported by current sync dispatcher."""


@dataclass(slots=True)
class SyncApplyResult:
    local_operation_id: str
    entity_type: str
    action_type: str
    status: str
    entity_id: UUID | None = None
    detail: str | None = None


@dataclass(slots=True)
class SyncService:
    db: Session

    def apply_operations(
        self,
        *,
        user_id: UUID,
        device_id: str,
        operations: list[SyncOperationIn],
    ) -> list[SyncApplyResult]:
        inventory_service = InventoryService(db=self.db)
        expense_service = ExpenseService(db=self.db)
        receivables_service = ReceivablesService(db=self.db)
        sales_service = SalesService(db=self.db)
        results: list[SyncApplyResult] = []

        for operation in operations:
            duplicate = self.db.scalar(
                select(SyncOperation).where(
                    SyncOperation.device_id == device_id,
                    SyncOperation.local_operation_id == operation.local_operation_id,
                )
            )
            if duplicate is not None:
                results.append(
                    SyncApplyResult(
                        local_operation_id=operation.local_operation_id,
                        entity_type=operation.entity_type,
                        action_type=operation.action_type,
                        status=SYNC_STATUS_DUPLICATE,
                        entity_id=duplicate.entity_id,
                        detail="Already applied.",
                    )
                )
                continue

            try:
                entity_id = self._dispatch_operation(
                    inventory_service=inventory_service,
                    expense_service=expense_service,
                    receivables_service=receivables_service,
                    sales_service=sales_service,
                    user_id=user_id,
                    device_id=device_id,
                    operation=operation,
                )
                self.db.add(
                    SyncOperation(
                        device_id=device_id,
                        local_operation_id=operation.local_operation_id,
                        entity_type=operation.entity_type,
                        entity_id=entity_id,
                        action_type=operation.action_type,
                        status=SYNC_STATUS_APPLIED,
                    )
                )
                self.db.commit()
                results.append(
                    SyncApplyResult(
                        local_operation_id=operation.local_operation_id,
                        entity_type=operation.entity_type,
                        action_type=operation.action_type,
                        status=SYNC_STATUS_APPLIED,
                        entity_id=entity_id,
                    )
                )
            except (
                ValidationError,
                UnsupportedSyncOperationError,
                MerchantContextMissingError,
                ExpenseContextMissingError,
                ReceivableContextMissingError,
                SaleContextMissingError,
                ValueError,
            ) as exc:
                self.db.rollback()
                results.append(
                    SyncApplyResult(
                        local_operation_id=operation.local_operation_id,
                        entity_type=operation.entity_type,
                        action_type=operation.action_type,
                        status=SYNC_STATUS_REJECTED,
                        detail=str(exc),
                    )
                )
            except (
                InventoryItemNotFoundError,
                InvalidInventoryAdjustmentError,
                CustomerNotFoundError,
                ReceivableNotFoundError,
                InvalidRepaymentError,
                SaleItemNotFoundError,
                InsufficientStockError,
            ) as exc:
                self.db.rollback()
                results.append(
                    SyncApplyResult(
                        local_operation_id=operation.local_operation_id,
                        entity_type=operation.entity_type,
                        action_type=operation.action_type,
                        status=SYNC_STATUS_CONFLICT,
                        detail=str(exc),
                    )
                )
            except Exception as exc:  # pragma: no cover - safety net for unexpected failures
                self.db.rollback()
                results.append(
                    SyncApplyResult(
                        local_operation_id=operation.local_operation_id,
                        entity_type=operation.entity_type,
                        action_type=operation.action_type,
                        status=SYNC_STATUS_FAILED,
                        detail=str(exc),
                    )
                )

        return results

    @staticmethod
    def _dispatch_operation(
        *,
        inventory_service: InventoryService,
        expense_service: ExpenseService,
        receivables_service: ReceivablesService,
        sales_service: SalesService,
        user_id: UUID,
        device_id: str,
        operation: SyncOperationIn,
    ) -> UUID:
        entity_type = operation.entity_type.strip().lower()
        action_type = operation.action_type.strip().lower()

        if entity_type == "item" and action_type == "create":
            payload = ItemCreateIn.model_validate(operation.payload)
            item = inventory_service.create_item(
                user_id=user_id,
                payload=payload,
                source_device_id=device_id,
                local_operation_id=operation.local_operation_id,
                commit=False,
            )
            return item.item_id

        if entity_type == "item" and action_type == "update":
            payload = SyncItemUpdateIn.model_validate(operation.payload)
            update_payload = ItemUpdateIn.model_validate(payload.model_dump(exclude={"item_id"}))
            item = inventory_service.update_item(
                user_id=user_id,
                item_id=payload.item_id,
                payload=update_payload,
                source_device_id=device_id,
                local_operation_id=operation.local_operation_id,
                commit=False,
            )
            return item.item_id

        if entity_type == "inventory" and action_type == "stock_in":
            payload = SyncStockInIn.model_validate(operation.payload)
            mutation = inventory_service.stock_in(
                user_id=user_id,
                item_id=payload.item_id,
                quantity=payload.quantity,
                reason=payload.reason,
                commit=False,
            )
            return mutation.item.item_id

        if entity_type == "inventory" and action_type == "adjust":
            payload = SyncStockAdjustIn.model_validate(operation.payload)
            mutation = inventory_service.adjust_stock(
                user_id=user_id,
                item_id=payload.item_id,
                quantity_delta=payload.quantity_delta,
                reason=payload.reason,
                commit=False,
            )
            return mutation.item.item_id

        if entity_type == "sale" and action_type == "create":
            payload = SyncSaleCreateIn.model_validate(operation.payload)
            sale_payload = SaleCreateIn.model_validate(payload.model_dump())
            sale = sales_service.create_sale(
                user_id=user_id,
                payload=sale_payload,
                source_device_id=device_id,
                local_operation_id=operation.local_operation_id,
                commit=False,
            )
            return sale.sale_id

        if entity_type == "expense" and action_type == "create":
            payload = SyncExpenseCreateIn.model_validate(operation.payload)
            expense_payload = ExpenseCreateIn.model_validate(payload.model_dump())
            expense = expense_service.create_expense(
                user_id=user_id,
                payload=expense_payload,
                source_device_id=device_id,
                local_operation_id=operation.local_operation_id,
                commit=False,
            )
            return expense.expense_id

        if entity_type == "customer" and action_type == "create":
            payload = SyncCustomerCreateIn.model_validate(operation.payload)
            customer_payload = CustomerCreateIn.model_validate(payload.model_dump())
            customer = receivables_service.create_customer(
                user_id=user_id,
                payload=customer_payload,
                source_device_id=device_id,
                local_operation_id=operation.local_operation_id,
                commit=False,
            )
            return customer.customer_id

        if entity_type == "receivable" and action_type == "create":
            payload = SyncReceivableCreateIn.model_validate(operation.payload)
            receivable_payload = ReceivableCreateIn.model_validate(payload.model_dump())
            receivable = receivables_service.create_receivable(
                user_id=user_id,
                payload=receivable_payload,
                source_device_id=device_id,
                local_operation_id=operation.local_operation_id,
                commit=False,
            )
            return receivable.receivable_id

        if entity_type == "receivable_payment" and action_type == "create":
            payload = SyncReceivablePaymentCreateIn.model_validate(operation.payload)
            repayment_payload = ReceivablePaymentCreateIn.model_validate(payload.model_dump())
            repayment = receivables_service.record_repayment(
                user_id=user_id,
                payload=repayment_payload,
                source_device_id=device_id,
                local_operation_id=operation.local_operation_id,
                commit=False,
            )
            return repayment.payment_id

        msg = f"Unsupported operation: {entity_type}:{action_type}"
        raise UnsupportedSyncOperationError(msg)
