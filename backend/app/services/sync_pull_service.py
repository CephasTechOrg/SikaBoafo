"""Cursor-based incremental pull for mobile snapshot refresh (SYNC-01)."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, noload, selectinload

from app.models.customer import Customer
from app.models.inventory import InventoryBalance
from app.models.item import Item
from app.models.receivable import Receivable
from app.services.inventory_service import InventoryItemSnapshot, InventoryService
from app.services.receivables_service import (
    CustomerSnapshot,
    ReceivableContextMissingError,
    ReceivableSnapshot,
    ReceivablesService,
)


@dataclass(slots=True)
class SyncPullResult:
    cursor: datetime
    full_refresh: bool
    inventory: list[InventoryItemSnapshot]
    customers: list[CustomerSnapshot]
    receivables: list[ReceivableSnapshot]


@dataclass(slots=True)
class SyncPullService:
    db: Session

    def pull_for_user(
        self,
        *,
        user_id: UUID,
        since: datetime | None,
        include_inventory: bool = True,
        include_debts: bool = True,
        limit: int = 500,
    ) -> SyncPullResult:
        inventory_service = InventoryService(db=self.db)
        receivables_service = ReceivablesService(db=self.db)
        cursor = datetime.now(tz=UTC)

        if since is None:
            inventory = (
                inventory_service.list_items_for_user(user_id=user_id)
                if include_inventory
                else []
            )
            customers = (
                receivables_service.list_customers_for_user(user_id=user_id, limit=limit)
                if include_debts
                else []
            )
            receivables = (
                receivables_service.list_receivables_for_user(user_id=user_id, limit=limit)
                if include_debts
                else []
            )
            return SyncPullResult(
                cursor=cursor,
                full_refresh=True,
                inventory=inventory,
                customers=customers,
                receivables=receivables,
            )

        since_utc = since.astimezone(UTC)
        store = receivables_service._get_default_store_for_user(user_id=user_id)  # noqa: SLF001

        inventory: list[InventoryItemSnapshot] = []
        if include_inventory:
            inventory = self._list_inventory_changed_since(
                inventory_service=inventory_service,
                store_id=store.id,
                since=since_utc,
                limit=limit,
            )

        receivables: list[ReceivableSnapshot] = []
        customers: list[CustomerSnapshot] = []
        if include_debts:
            receivables = self._list_receivables_changed_since(
                receivables_service=receivables_service,
                store_id=store.id,
                since=since_utc,
                limit=limit,
            )
            customers = self._list_customers_changed_since(
                receivables_service=receivables_service,
                store_id=store.id,
                since=since_utc,
                limit=limit,
            )

        return SyncPullResult(
            cursor=cursor,
            full_refresh=False,
            inventory=inventory,
            customers=customers,
            receivables=receivables,
        )

    def _list_inventory_changed_since(
        self,
        *,
        inventory_service: InventoryService,
        store_id: UUID,
        since: datetime,
        limit: int,
    ) -> list[InventoryItemSnapshot]:
        rows = self.db.execute(
            select(Item, InventoryBalance.quantity_on_hand)
            .outerjoin(InventoryBalance, InventoryBalance.item_id == Item.id)
            .where(
                Item.store_id == store_id,
                or_(
                    Item.updated_at >= since,
                    InventoryBalance.updated_at >= since,
                ),
            )
            .order_by(Item.name.asc())
            .limit(limit)
        ).all()
        return [
            inventory_service._to_item_snapshot(  # noqa: SLF001
                item=item,
                quantity_on_hand=quantity,
            )
            for item, quantity in rows
        ]

    def _list_receivables_changed_since(
        self,
        *,
        receivables_service: ReceivablesService,
        store_id: UUID,
        since: datetime,
        limit: int,
    ) -> list[ReceivableSnapshot]:
        receivables = self.db.scalars(
            select(Receivable)
            .options(selectinload(Receivable.customer))
            .where(
                Receivable.store_id == store_id,
                Receivable.updated_at >= since,
            )
            .order_by(Receivable.updated_at.desc())
            .limit(limit)
        ).all()
        return [
            receivables_service._to_receivable_snapshot(receivable=r)  # noqa: SLF001
            for r in receivables
        ]

    def _list_customers_changed_since(
        self,
        *,
        receivables_service: ReceivablesService,
        store_id: UUID,
        since: datetime,
        limit: int,
    ) -> list[CustomerSnapshot]:
        rows = self.db.execute(
            select(
                Customer,
                func.coalesce(
                    func.sum(Receivable.outstanding_amount),
                    0,
                ).label("total_outstanding"),
            )
            .outerjoin(Receivable, Receivable.customer_id == Customer.id)
            .options(noload(Customer.store))
            .where(
                Customer.store_id == store_id,
                or_(
                    Customer.updated_at >= since,
                    Receivable.updated_at >= since,
                ),
            )
            .group_by(Customer.id)
            .order_by(Customer.name.asc())
            .limit(limit)
        ).all()
        return [
            receivables_service._to_customer_snapshot(  # noqa: SLF001
                customer=row[0],
                total_outstanding=receivables_service._money(row[1]),  # noqa: SLF001
            )
            for row in rows
        ]


__all__ = [
    "ReceivableContextMissingError",
    "SyncPullResult",
    "SyncPullService",
]
