"""Inventory domain service: items, stock-in, and adjustments."""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.constants import (
    INVENTORY_MOVEMENT_ADJUSTMENT,
    INVENTORY_MOVEMENT_STOCK_IN,
)
from app.models.inventory import InventoryBalance, InventoryMovement
from app.models.item import Item
from app.models.store import Store
from app.schemas.inventory import ItemCreateIn, ItemUpdateIn
from app.services.audit_service import log_audit
from app.services.store_context import StoreContextError, get_merchant_and_store


class MerchantContextMissingError(Exception):
    """User does not have a merchant/default-store context yet."""


class InventoryItemNotFoundError(Exception):
    """Requested item does not exist for the resolved store context."""


class InvalidInventoryAdjustmentError(Exception):
    """Stock adjustment would break domain invariants."""


class InvalidItemArchiveError(Exception):
    """Item archive request would break inventory invariants."""


@dataclass(slots=True)
class InventoryItemSnapshot:
    item_id: UUID
    name: str
    default_price: Decimal
    cost_price: Decimal | None
    unit: str | None
    sku: str | None
    category: str | None
    low_stock_threshold: int | None
    is_active: bool
    quantity_on_hand: int


@dataclass(slots=True)
class InventoryMutationSnapshot:
    item: InventoryItemSnapshot
    movement_type: str
    movement_quantity: int


@dataclass(slots=True)
class InventoryService:
    db: Session

    def list_items_for_user(self, *, user_id: UUID) -> list[InventoryItemSnapshot]:
        store = self._get_default_store_for_user(user_id=user_id)
        rows = self.db.execute(
            select(Item, InventoryBalance.quantity_on_hand)
            .outerjoin(InventoryBalance, InventoryBalance.item_id == Item.id)
            .where(Item.store_id == store.id)
            .order_by(Item.name.asc())
        ).all()
        return [
            self._to_item_snapshot(item=item, quantity_on_hand=quantity)
            for item, quantity in rows
        ]

    def create_item(
        self,
        *,
        user_id: UUID,
        payload: ItemCreateIn,
        source_device_id: str | None = None,
        local_operation_id: str | None = None,
        commit: bool = True,
    ) -> InventoryItemSnapshot:
        store = self._get_default_store_for_user(user_id=user_id)
        item = Item(
            store_id=store.id,
            name=payload.name.strip(),
            default_price=payload.default_price,
            cost_price=payload.cost_price,
            unit=self._clean_optional(payload.unit),
            sku=self._clean_optional(payload.sku),
            category=self._clean_optional(payload.category),
            low_stock_threshold=payload.low_stock_threshold,
            is_active=True,
            source_device_id=source_device_id,
            local_operation_id=local_operation_id,
        )
        if payload.item_id is not None:
            item.id = payload.item_id
        self.db.add(item)
        self.db.flush()

        balance = InventoryBalance(item_id=item.id, quantity_on_hand=0)
        self.db.add(balance)
        log_audit(
            db=self.db,
            actor_user_id=user_id,
            business_id=store.merchant_id,
            action="item.created",
            entity_type="item",
            entity_id=item.id,
            meta={"name": item.name, "default_price": str(item.default_price)},
        )
        self._finalize(item=item, balance=balance, commit=commit)
        return self._to_item_snapshot(item=item, quantity_on_hand=balance.quantity_on_hand)

    def update_item(
        self,
        *,
        user_id: UUID,
        item_id: UUID,
        payload: ItemUpdateIn,
        source_device_id: str | None = None,
        local_operation_id: str | None = None,
        commit: bool = True,
    ) -> InventoryItemSnapshot:
        store = self._get_default_store_for_user(user_id=user_id)
        item = self._get_item_for_store(store_id=store.id, item_id=item_id)
        balance = self._get_or_create_balance(item_id=item.id)
        if payload.name is not None:
            item.name = payload.name.strip()
        if payload.default_price is not None:
            item.default_price = payload.default_price
        if payload.cost_price is not None:
            item.cost_price = payload.cost_price
        if payload.unit is not None:
            item.unit = self._clean_optional(payload.unit)
        if payload.sku is not None:
            item.sku = self._clean_optional(payload.sku)
        if payload.category is not None:
            item.category = self._clean_optional(payload.category)
        if payload.low_stock_threshold is not None:
            item.low_stock_threshold = payload.low_stock_threshold
        if payload.is_active is not None:
            if (
                payload.is_active is False
                and item.is_active
                and balance.quantity_on_hand > 0
            ):
                msg = "Adjust stock to 0 before archiving this item."
                raise InvalidItemArchiveError(msg)
            item.is_active = payload.is_active
        if source_device_id is not None:
            item.source_device_id = source_device_id
        if local_operation_id is not None:
            item.local_operation_id = local_operation_id

        log_audit(
            db=self.db,
            actor_user_id=user_id,
            business_id=store.merchant_id,
            action="item.updated",
            entity_type="item",
            entity_id=item.id,
        )
        self._finalize(item=item, balance=balance, commit=commit)
        return self._to_item_snapshot(item=item, quantity_on_hand=balance.quantity_on_hand)

    def stock_in(
        self,
        *,
        user_id: UUID,
        item_id: UUID,
        quantity: int,
        reason: str | None = None,
        commit: bool = True,
    ) -> InventoryMutationSnapshot:
        store = self._get_default_store_for_user(user_id=user_id)
        item = self._get_item_for_store(store_id=store.id, item_id=item_id)
        balance = self._get_or_create_balance(item_id=item.id)
        balance.quantity_on_hand += quantity

        movement = InventoryMovement(
            item_id=item.id,
            store_id=store.id,
            user_id=user_id,
            movement_type=INVENTORY_MOVEMENT_STOCK_IN,
            quantity=quantity,
            reason=self._clean_optional(reason),
        )
        self.db.add(movement)
        log_audit(
            db=self.db,
            actor_user_id=user_id,
            business_id=store.merchant_id,
            action="inventory.stock_in",
            entity_type="item",
            entity_id=item.id,
            meta={"quantity": quantity, "reason": reason},
        )
        self._finalize(item=item, balance=balance, commit=commit)
        return InventoryMutationSnapshot(
            item=self._to_item_snapshot(item=item, quantity_on_hand=balance.quantity_on_hand),
            movement_type=movement.movement_type,
            movement_quantity=movement.quantity,
        )

    def adjust_stock(
        self,
        *,
        user_id: UUID,
        item_id: UUID,
        quantity_delta: int,
        reason: str | None = None,
        commit: bool = True,
    ) -> InventoryMutationSnapshot:
        store = self._get_default_store_for_user(user_id=user_id)
        item = self._get_item_for_store(store_id=store.id, item_id=item_id)
        balance = self._get_or_create_balance(item_id=item.id)

        updated_quantity = balance.quantity_on_hand + quantity_delta
        if updated_quantity < 0:
            msg = "Stock adjustment would make quantity negative."
            raise InvalidInventoryAdjustmentError(msg)
        balance.quantity_on_hand = updated_quantity

        movement = InventoryMovement(
            item_id=item.id,
            store_id=store.id,
            user_id=user_id,
            movement_type=INVENTORY_MOVEMENT_ADJUSTMENT,
            quantity=quantity_delta,
            reason=self._clean_optional(reason),
        )
        self.db.add(movement)
        log_audit(
            db=self.db,
            actor_user_id=user_id,
            business_id=store.merchant_id,
            action="inventory.adjusted",
            entity_type="item",
            entity_id=item.id,
            meta={"delta": quantity_delta, "reason": reason},
        )
        self._finalize(item=item, balance=balance, commit=commit)
        return InventoryMutationSnapshot(
            item=self._to_item_snapshot(item=item, quantity_on_hand=balance.quantity_on_hand),
            movement_type=movement.movement_type,
            movement_quantity=movement.quantity,
        )

    def _get_default_store_for_user(self, *, user_id: UUID) -> Store:
        try:
            _, store = get_merchant_and_store(user_id=user_id, db=self.db)
        except StoreContextError as exc:
            raise MerchantContextMissingError(str(exc)) from exc
        return store

    def _get_item_for_store(self, *, store_id: UUID, item_id: UUID) -> Item:
        item = self.db.scalar(
            select(Item).where(
                Item.id == item_id,
                Item.store_id == store_id,
            )
        )
        if item is None:
            msg = "Item not found."
            raise InventoryItemNotFoundError(msg)
        return item

    def _get_or_create_balance(self, *, item_id: UUID) -> InventoryBalance:
        balance = self.db.scalar(
            select(InventoryBalance).where(InventoryBalance.item_id == item_id)
        )
        if balance is None:
            balance = InventoryBalance(item_id=item_id, quantity_on_hand=0)
            self.db.add(balance)
            self.db.flush()
        return balance

    def _finalize(self, *, item: Item, balance: InventoryBalance, commit: bool) -> None:
        if commit:
            self.db.commit()
            self.db.refresh(item)
            self.db.refresh(balance)
            return
        self.db.flush()

    @staticmethod
    def _to_item_snapshot(
        *,
        item: Item,
        quantity_on_hand: int | None,
    ) -> InventoryItemSnapshot:
        return InventoryItemSnapshot(
            item_id=item.id,
            name=item.name,
            default_price=item.default_price,
            cost_price=item.cost_price,
            unit=item.unit,
            sku=item.sku,
            category=item.category,
            low_stock_threshold=item.low_stock_threshold,
            is_active=item.is_active,
            quantity_on_hand=int(quantity_on_hand or 0),
        )

    @staticmethod
    def _clean_optional(value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None
