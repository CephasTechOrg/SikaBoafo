"""Sales domain service: create sales and enforce stock invariants."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import ROUND_HALF_UP, Decimal
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.constants import (
    INVENTORY_MOVEMENT_ADJUSTMENT,
    INVENTORY_MOVEMENT_SALE,
    PAYMENT_STATUS_RECORDED,
    SALE_STATUS_RECORDED,
    SALE_STATUS_VOIDED,
)
from app.models.inventory import InventoryBalance, InventoryMovement
from app.models.item import Item
from app.models.sale import Sale, SaleItem
from app.models.store import Store
from app.schemas.sale import SaleCreateIn, SaleUpdateIn, SaleVoidIn
from app.services.audit_service import log_audit
from app.services.store_context import StoreContextError, get_merchant_and_store

_MONEY_SCALE = Decimal("0.01")


class SaleContextMissingError(Exception):
    """User does not have merchant/store context for recording sales."""


class SaleItemNotFoundError(Exception):
    """One or more sale lines reference invalid item IDs for this store."""


class InsufficientStockError(Exception):
    """Sale line quantity exceeds available stock."""


class SaleNotFoundError(Exception):
    """Sale does not exist for the user's default store."""


class SaleAlreadyVoidedError(Exception):
    """Sale has already been voided and cannot be edited."""


class SaleUpdateScopeError(Exception):
    """Requested sale edit includes unsupported line changes."""


@dataclass(slots=True)
class SaleLineSnapshot:
    sale_item_id: UUID
    item_id: UUID
    quantity: int
    unit_price: Decimal
    line_total: Decimal
    cost_price_snapshot: Decimal | None = None


@dataclass(slots=True)
class SaleSnapshot:
    sale_id: UUID
    total_amount: Decimal
    payment_method_label: str
    payment_status: str
    sale_status: str
    voided_at: datetime | None
    void_reason: str | None
    note: str | None
    created_at: datetime
    lines: list[SaleLineSnapshot]


@dataclass(slots=True)
class SalesService:
    db: Session

    def get_sale_for_user(
        self,
        *,
        user_id: UUID,
        sale_id: UUID,
    ) -> SaleSnapshot:
        store = self._get_default_store_for_user(user_id=user_id)
        sale = self._load_sale_for_store(store_id=store.id, sale_id=sale_id)
        return self._to_sale_snapshot(sale=sale)

    def list_sales_for_user(
        self,
        *,
        user_id: UUID,
        limit: int = 50,
        include_voided: bool = False,
    ) -> list[SaleSnapshot]:
        store = self._get_default_store_for_user(user_id=user_id)
        query = (
            select(Sale)
            .options(selectinload(Sale.lines))
            .where(Sale.store_id == store.id)
        )
        if not include_voided:
            query = query.where(Sale.sale_status == SALE_STATUS_RECORDED)
        sales = self.db.scalars(query.order_by(Sale.created_at.desc()).limit(limit)).all()
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
        items = self._load_items_for_sale(store_id=store.id, item_ids=list(requested_quantities))
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
            cashier_id=user_id,
            total_amount=Decimal("0.00"),
            payment_method_label=payload.payment_method_label,
            payment_status=PAYMENT_STATUS_RECORDED,
            sale_status=SALE_STATUS_RECORDED,
            note=payload.note,
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

            cost_snapshot = items[line.item_id].cost_price
            sale_line = SaleItem(
                sale_id=sale.id,
                item_id=line.item_id,
                quantity=line.quantity,
                unit_price=unit_price,
                line_total=line_total,
                cost_price_snapshot=self._money(cost_snapshot) if cost_snapshot is not None else None,
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
                    cost_price_snapshot=sale_line.cost_price_snapshot,
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
        log_audit(
            db=self.db,
            actor_user_id=user_id,
            business_id=store.merchant_id,
            action="sale.created",
            entity_type="sale",
            entity_id=sale.id,
            meta={
                "total_amount": str(sale.total_amount),
                "payment_method": sale.payment_method_label,
            },
        )
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
            sale_status=sale.sale_status,
            voided_at=sale.voided_at,
            void_reason=sale.void_reason,
            note=sale.note,
            created_at=sale.created_at,
            lines=line_snapshots,
        )

    def update_sale(
        self,
        *,
        user_id: UUID,
        sale_id: UUID,
        payload: SaleUpdateIn,
        source_device_id: str | None = None,
        local_operation_id: str | None = None,
        commit: bool = True,
    ) -> SaleSnapshot:
        store = self._get_default_store_for_user(user_id=user_id)
        sale = self._load_sale_for_store(store_id=store.id, sale_id=sale_id)
        if sale.sale_status == SALE_STATUS_VOIDED:
            raise SaleAlreadyVoidedError(f"Sale {sale_id} is already voided.")

        if payload.payment_method_label is not None:
            sale.payment_method_label = payload.payment_method_label

        if payload.lines is not None:
            requested_quantities = self._aggregate_update_quantities(payload=payload)
            existing_by_item = {line.item_id: line for line in sale.lines}
            if set(requested_quantities) != set(existing_by_item):
                msg = (
                    "Sale edit can only update quantities for existing lines; "
                    "adding or removing items is not allowed."
                )
                raise SaleUpdateScopeError(msg)

            balances = self._load_balances(item_ids=list(existing_by_item))
            deltas_by_item: dict[UUID, int] = {}
            for item_id, new_qty in requested_quantities.items():
                old_qty = existing_by_item[item_id].quantity
                delta = new_qty - old_qty
                deltas_by_item[item_id] = delta
                if delta <= 0:
                    continue
                available = balances.get(item_id).quantity_on_hand if item_id in balances else 0
                if available < delta:
                    msg = (
                        f"Insufficient stock for item {item_id}: "
                        f"available={available}, requested_extra={delta}."
                    )
                    raise InsufficientStockError(msg)

            total_amount = Decimal("0.00")
            for sale_line in sale.lines:
                next_qty = requested_quantities[sale_line.item_id]
                sale_line.quantity = next_qty
                sale_line.line_total = self._money(sale_line.unit_price * next_qty)
                total_amount += sale_line.line_total
                self.db.add(sale_line)

            for item_id, delta in deltas_by_item.items():
                if delta == 0:
                    continue
                balance = balances.get(item_id)
                if balance is None:
                    balance = InventoryBalance(item_id=item_id, quantity_on_hand=0)
                    self.db.add(balance)
                    self.db.flush()
                balance.quantity_on_hand -= delta
                self.db.add(balance)
                self.db.add(
                    InventoryMovement(
                        item_id=item_id,
                        store_id=store.id,
                        movement_type=INVENTORY_MOVEMENT_ADJUSTMENT,
                        quantity=-delta,
                        reason="sale updated",
                        reference_type="sale",
                        reference_id=sale.id,
                    )
                )

            sale.total_amount = self._money(total_amount)

        if source_device_id is not None:
            sale.source_device_id = source_device_id
        if local_operation_id is not None:
            sale.local_operation_id = local_operation_id

        self.db.add(sale)
        log_audit(
            db=self.db,
            actor_user_id=user_id,
            business_id=store.merchant_id,
            action="sale.updated",
            entity_type="sale",
            entity_id=sale.id,
        )
        if commit:
            self.db.commit()
            self.db.refresh(sale)
        else:
            self.db.flush()

        return self._to_sale_snapshot(sale=sale)

    def void_sale(
        self,
        *,
        user_id: UUID,
        sale_id: UUID,
        payload: SaleVoidIn,
        source_device_id: str | None = None,
        local_operation_id: str | None = None,
        commit: bool = True,
    ) -> SaleSnapshot:
        store = self._get_default_store_for_user(user_id=user_id)
        sale = self._load_sale_for_store(store_id=store.id, sale_id=sale_id)
        if sale.sale_status == SALE_STATUS_VOIDED:
            raise SaleAlreadyVoidedError(f"Sale {sale_id} is already voided.")

        balances = self._load_balances(item_ids=[line.item_id for line in sale.lines])
        movement_reason = payload.reason or "sale voided"
        for sale_line in sale.lines:
            balance = balances.get(sale_line.item_id)
            if balance is None:
                balance = InventoryBalance(item_id=sale_line.item_id, quantity_on_hand=0)
                self.db.add(balance)
                self.db.flush()
            balance.quantity_on_hand += sale_line.quantity
            self.db.add(balance)
            self.db.add(
                InventoryMovement(
                    item_id=sale_line.item_id,
                    store_id=store.id,
                    movement_type=INVENTORY_MOVEMENT_ADJUSTMENT,
                    quantity=sale_line.quantity,
                    reason=movement_reason,
                    reference_type="sale",
                    reference_id=sale.id,
                )
            )

        sale.sale_status = SALE_STATUS_VOIDED
        sale.voided_at = datetime.now(tz=UTC)
        sale.void_reason = payload.reason
        if source_device_id is not None:
            sale.source_device_id = source_device_id
        if local_operation_id is not None:
            sale.local_operation_id = local_operation_id

        self.db.add(sale)
        log_audit(
            db=self.db,
            actor_user_id=user_id,
            business_id=store.merchant_id,
            action="sale.voided",
            entity_type="sale",
            entity_id=sale.id,
            meta={"reason": payload.reason},
        )
        if commit:
            self.db.commit()
            self.db.refresh(sale)
        else:
            self.db.flush()

        return self._to_sale_snapshot(sale=sale)

    def _get_default_store_for_user(self, *, user_id: UUID) -> Store:
        try:
            _, store = get_merchant_and_store(user_id=user_id, db=self.db)
        except StoreContextError as exc:
            raise SaleContextMissingError(str(exc)) from exc
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

    def _load_sale_for_store(self, *, store_id: UUID, sale_id: UUID) -> Sale:
        sale = self.db.scalar(
            select(Sale)
            .options(selectinload(Sale.lines))
            .where(
                Sale.store_id == store_id,
                Sale.id == sale_id,
            )
        )
        if sale is None:
            raise SaleNotFoundError(f"Sale {sale_id} not found.")
        return sale

    @staticmethod
    def _aggregate_quantities(*, payload: SaleCreateIn) -> dict[UUID, int]:
        quantities: dict[UUID, int] = {}
        for line in payload.lines:
            quantities[line.item_id] = quantities.get(line.item_id, 0) + line.quantity
        return quantities

    @staticmethod
    def _aggregate_update_quantities(*, payload: SaleUpdateIn) -> dict[UUID, int]:
        quantities: dict[UUID, int] = {}
        if payload.lines is None:
            return quantities
        for line in payload.lines:
            if line.item_id in quantities:
                msg = f"Duplicate item_id in sale update: {line.item_id}"
                raise ValueError(msg)
            quantities[line.item_id] = line.quantity
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
            sale_status=sale.sale_status,
            voided_at=sale.voided_at,
            void_reason=sale.void_reason,
            note=sale.note,
            created_at=sale.created_at,
            lines=[
                SaleLineSnapshot(
                    sale_item_id=line.id,
                    item_id=line.item_id,
                    quantity=line.quantity,
                    unit_price=line.unit_price,
                    line_total=line.line_total,
                    cost_price_snapshot=line.cost_price_snapshot,
                )
                for line in sale.lines
            ],
        )
