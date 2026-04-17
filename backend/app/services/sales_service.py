"""Sales domain service: create sales and enforce stock invariants."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from decimal import ROUND_HALF_UP, Decimal
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.constants import INVENTORY_MOVEMENT_SALE, PAYMENT_STATUS_RECORDED
from app.models.inventory import InventoryBalance, InventoryMovement
from app.models.item import Item
from app.models.merchant import Merchant
from app.models.sale import Sale, SaleItem
from app.models.store import Store
from app.schemas.sale import SaleCreateIn

_MONEY_SCALE = Decimal("0.01")


class SaleContextMissingError(Exception):
    """User does not have merchant/store context for recording sales."""


class SaleItemNotFoundError(Exception):
    """One or more sale lines reference invalid item IDs for this store."""


class InsufficientStockError(Exception):
    """Sale line quantity exceeds available stock."""


@dataclass(slots=True)
class SaleLineSnapshot:
    sale_item_id: UUID
    item_id: UUID
    quantity: int
    unit_price: Decimal
    line_total: Decimal


@dataclass(slots=True)
class SaleSnapshot:
    sale_id: UUID
    total_amount: Decimal
    payment_method_label: str
    payment_status: str
    created_at: datetime
    lines: list[SaleLineSnapshot]


@dataclass(slots=True)
class SalesService:
    db: Session

    def list_sales_for_user(self, *, user_id: UUID, limit: int = 50) -> list[SaleSnapshot]:
        store = self._get_default_store_for_user(user_id=user_id)
        sales = self.db.scalars(
            select(Sale)
            .options(selectinload(Sale.lines))
            .where(Sale.store_id == store.id)
            .order_by(Sale.created_at.desc())
            .limit(limit)
        ).all()
        return [self._to_sale_snapshot(sale=sale) for sale in sales]

    def create_sale(
        self,
        *,
        user_id: UUID,
        payload: SaleCreateIn,
        source_device_id: str | None = None,
        local_operation_id: str | None = None,
        commit: bool = True,
    ) -> SaleSnapshot:
        store = self._get_default_store_for_user(user_id=user_id)
        requested_quantities = self._aggregate_quantities(payload=payload)
        self._load_items_for_sale(store_id=store.id, item_ids=list(requested_quantities))
        balances = self._load_balances(item_ids=list(requested_quantities))

        for item_id, requested_qty in requested_quantities.items():
            available = balances.get(item_id).quantity_on_hand if item_id in balances else 0
            if available < requested_qty:
                msg = (
                    f"Insufficient stock for item {item_id}: "
                    f"available={available}, requested={requested_qty}."
                )
                raise InsufficientStockError(msg)

        sale = Sale(
            store_id=store.id,
            total_amount=Decimal("0.00"),
            payment_method_label=payload.payment_method_label,
            payment_status=PAYMENT_STATUS_RECORDED,
            source_device_id=source_device_id,
            local_operation_id=local_operation_id,
        )
        if payload.sale_id is not None:
            sale.id = payload.sale_id
        self.db.add(sale)
        self.db.flush()

        total_amount = Decimal("0.00")
        line_snapshots: list[SaleLineSnapshot] = []
        for line in payload.lines:
            unit_price = self._money(line.unit_price)
            line_total = self._money(unit_price * line.quantity)
            total_amount += line_total

            sale_line = SaleItem(
                sale_id=sale.id,
                item_id=line.item_id,
                quantity=line.quantity,
                unit_price=unit_price,
                line_total=line_total,
            )
            self.db.add(sale_line)
            self.db.flush()
            line_snapshots.append(
                SaleLineSnapshot(
                    sale_item_id=sale_line.id,
                    item_id=sale_line.item_id,
                    quantity=sale_line.quantity,
                    unit_price=sale_line.unit_price,
                    line_total=sale_line.line_total,
                )
            )

        for item_id, requested_qty in requested_quantities.items():
            balance = balances.get(item_id)
            if balance is None:
                balance = InventoryBalance(item_id=item_id, quantity_on_hand=0)
                self.db.add(balance)
                self.db.flush()
            balance.quantity_on_hand -= requested_qty
            self.db.add(
                InventoryMovement(
                    item_id=item_id,
                    store_id=store.id,
                    movement_type=INVENTORY_MOVEMENT_SALE,
                    quantity=-requested_qty,
                    reason="sale recorded",
                    reference_type="sale",
                    reference_id=sale.id,
                )
            )

        sale.total_amount = self._money(total_amount)
        if commit:
            self.db.commit()
            self.db.refresh(sale)
        else:
            self.db.flush()

        return SaleSnapshot(
            sale_id=sale.id,
            total_amount=sale.total_amount,
            payment_method_label=sale.payment_method_label,
            payment_status=sale.payment_status,
            created_at=sale.created_at,
            lines=line_snapshots,
        )

    def _get_default_store_for_user(self, *, user_id: UUID) -> Store:
        merchant = self.db.scalar(select(Merchant).where(Merchant.owner_user_id == user_id))
        if merchant is None:
            msg = "Merchant profile not found."
            raise SaleContextMissingError(msg)
        store = self.db.scalar(
            select(Store).where(
                Store.merchant_id == merchant.id,
                Store.is_default.is_(True),
            )
        )
        if store is None:
            msg = "Default store not found."
            raise SaleContextMissingError(msg)
        return store

    def _load_items_for_sale(self, *, store_id: UUID, item_ids: list[UUID]) -> dict[UUID, Item]:
        loaded = self.db.scalars(
            select(Item).where(
                Item.store_id == store_id,
                Item.id.in_(item_ids),
            )
        ).all()
        items = {item.id: item for item in loaded}
        missing = [item_id for item_id in item_ids if item_id not in items]
        if missing:
            msg = f"Item not found for store: {missing[0]}"
            raise SaleItemNotFoundError(msg)
        return items

    def _load_balances(self, *, item_ids: list[UUID]) -> dict[UUID, InventoryBalance]:
        balances = self.db.scalars(
            select(InventoryBalance).where(InventoryBalance.item_id.in_(item_ids))
        ).all()
        return {balance.item_id: balance for balance in balances}

    @staticmethod
    def _aggregate_quantities(*, payload: SaleCreateIn) -> dict[UUID, int]:
        quantities: dict[UUID, int] = {}
        for line in payload.lines:
            quantities[line.item_id] = quantities.get(line.item_id, 0) + line.quantity
        return quantities

    @staticmethod
    def _money(value: Decimal) -> Decimal:
        return value.quantize(_MONEY_SCALE, rounding=ROUND_HALF_UP)

    @staticmethod
    def _to_sale_snapshot(*, sale: Sale) -> SaleSnapshot:
        return SaleSnapshot(
            sale_id=sale.id,
            total_amount=sale.total_amount,
            payment_method_label=sale.payment_method_label,
            payment_status=sale.payment_status,
            created_at=sale.created_at,
            lines=[
                SaleLineSnapshot(
                    sale_item_id=line.id,
                    item_id=line.item_id,
                    quantity=line.quantity,
                    unit_price=line.unit_price,
                    line_total=line.line_total,
                )
                for line in sale.lines
            ],
        )
