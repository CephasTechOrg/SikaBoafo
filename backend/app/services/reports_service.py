"""Reporting service for dashboard summary aggregates."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from decimal import ROUND_HALF_UP, Decimal
from uuid import UUID
from zoneinfo import ZoneInfo

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.constants import RECEIVABLE_STATUS_OPEN
from app.models.customer import Customer
from app.models.expense import Expense
from app.models.inventory import InventoryBalance
from app.models.item import Item
from app.models.merchant import Merchant
from app.models.receivable import Receivable, ReceivablePayment
from app.models.sale import Sale, SaleItem
from app.models.store import Store

_MONEY_SCALE = Decimal("0.01")


class ReportContextMissingError(Exception):
    """User does not have merchant/store context for reports."""


@dataclass(slots=True)
class ReportSummarySnapshot:
    timezone: str
    period_start_utc: datetime
    period_end_utc: datetime
    today_sales_total: Decimal
    today_expenses_total: Decimal
    today_estimated_profit: Decimal
    debt_outstanding_total: Decimal
    low_stock_count: int


@dataclass(slots=True)
class ReportActivitySnapshot:
    activity_type: str
    title: str
    detail: str
    amount: Decimal
    created_at: datetime


@dataclass(slots=True)
class ReportPeriodSnapshot:
    period_start_utc: datetime
    period_end_utc: datetime
    sales_total: Decimal
    expenses_total: Decimal
    estimated_profit: Decimal


@dataclass(slots=True)
class ReportPaymentBreakdownSnapshot:
    payment_method_label: str
    payment_method_display: str
    total_amount: Decimal
    sale_count: int


@dataclass(slots=True)
class ReportTopSellingItemSnapshot:
    item_id: UUID
    item_name: str
    quantity_sold: int
    sales_total: Decimal


@dataclass(slots=True)
class ReportInsightsSnapshot:
    timezone: str
    week: ReportPeriodSnapshot
    month: ReportPeriodSnapshot
    monthly_payment_breakdown: list[ReportPaymentBreakdownSnapshot]
    monthly_top_selling_items: list[ReportTopSellingItemSnapshot]


@dataclass(slots=True)
class ReportsService:
    db: Session

    def get_summary_for_user(
        self,
        *,
        user_id: UUID,
        as_of_utc: datetime | None = None,
    ) -> ReportSummarySnapshot:
        store = self._get_default_store_for_user(user_id=user_id)
        now_utc = self._normalize_utc(as_of_utc)
        period_start_utc, period_end_utc = self._today_utc_window(
            now_utc=now_utc,
            timezone_name=store.timezone,
        )

        sales_total = self._sum_sales(
            store_id=store.id,
            start_utc=period_start_utc,
            end_utc=period_end_utc,
        )
        expenses_total = self._sum_expenses(
            store_id=store.id,
            start_utc=period_start_utc,
            end_utc=period_end_utc,
        )
        profit = self._money(sales_total - expenses_total)
        debt_total = self._sum_debt_outstanding(store_id=store.id)
        low_stock_count = self._count_low_stock(store_id=store.id)

        return ReportSummarySnapshot(
            timezone=store.timezone,
            period_start_utc=period_start_utc,
            period_end_utc=period_end_utc,
            today_sales_total=sales_total,
            today_expenses_total=expenses_total,
            today_estimated_profit=profit,
            debt_outstanding_total=debt_total,
            low_stock_count=low_stock_count,
        )

    def list_recent_activity_for_user(
        self,
        *,
        user_id: UUID,
        limit: int = 8,
    ) -> list[ReportActivitySnapshot]:
        store = self._get_default_store_for_user(user_id=user_id)
        candidates = [
            *self._recent_sales(store_id=store.id, limit=limit),
            *self._recent_expenses(store_id=store.id, limit=limit),
            *self._recent_repayments(store_id=store.id, limit=limit),
        ]
        candidates.sort(key=lambda row: row.created_at, reverse=True)
        return candidates[:limit]

    def get_insights_for_user(
        self,
        *,
        user_id: UUID,
        as_of_utc: datetime | None = None,
        top_n: int = 5,
    ) -> ReportInsightsSnapshot:
        store = self._get_default_store_for_user(user_id=user_id)
        now_utc = self._normalize_utc(as_of_utc)
        week_start_utc, week_end_utc = self._period_utc_window(
            now_utc=now_utc,
            timezone_name=store.timezone,
            period="week",
        )
        month_start_utc, month_end_utc = self._period_utc_window(
            now_utc=now_utc,
            timezone_name=store.timezone,
            period="month",
        )

        week = self._period_snapshot(
            store_id=store.id,
            start_utc=week_start_utc,
            end_utc=week_end_utc,
        )
        month = self._period_snapshot(
            store_id=store.id,
            start_utc=month_start_utc,
            end_utc=month_end_utc,
        )

        return ReportInsightsSnapshot(
            timezone=store.timezone,
            week=week,
            month=month,
            monthly_payment_breakdown=self._payment_breakdown(
                store_id=store.id,
                start_utc=month_start_utc,
                end_utc=month_end_utc,
            ),
            monthly_top_selling_items=self._top_selling_items(
                store_id=store.id,
                start_utc=month_start_utc,
                end_utc=month_end_utc,
                limit=top_n,
            ),
        )

    def _get_default_store_for_user(self, *, user_id: UUID) -> Store:
        merchant = self.db.scalar(select(Merchant).where(Merchant.owner_user_id == user_id))
        if merchant is None:
            msg = "Merchant profile not found."
            raise ReportContextMissingError(msg)
        store = self.db.scalar(
            select(Store).where(
                Store.merchant_id == merchant.id,
                Store.is_default.is_(True),
            )
        )
        if store is None:
            msg = "Default store not found."
            raise ReportContextMissingError(msg)
        return store

    def _sum_sales(self, *, store_id: UUID, start_utc: datetime, end_utc: datetime) -> Decimal:
        value = self.db.scalar(
            select(func.coalesce(func.sum(Sale.total_amount), Decimal("0.00"))).where(
                Sale.store_id == store_id,
                Sale.created_at >= start_utc,
                Sale.created_at < end_utc,
            )
        )
        return self._money(value or Decimal("0.00"))

    def _sum_expenses(self, *, store_id: UUID, start_utc: datetime, end_utc: datetime) -> Decimal:
        value = self.db.scalar(
            select(func.coalesce(func.sum(Expense.amount), Decimal("0.00"))).where(
                Expense.store_id == store_id,
                Expense.created_at >= start_utc,
                Expense.created_at < end_utc,
            )
        )
        return self._money(value or Decimal("0.00"))

    def _sum_debt_outstanding(self, *, store_id: UUID) -> Decimal:
        value = self.db.scalar(
            select(func.coalesce(func.sum(Receivable.outstanding_amount), Decimal("0.00"))).where(
                Receivable.store_id == store_id,
                Receivable.status == RECEIVABLE_STATUS_OPEN,
            )
        )
        return self._money(value or Decimal("0.00"))

    def _count_low_stock(self, *, store_id: UUID) -> int:
        value = self.db.scalar(
            select(func.count(Item.id))
            .select_from(Item)
            .outerjoin(InventoryBalance, InventoryBalance.item_id == Item.id)
            .where(
                Item.store_id == store_id,
                Item.is_active.is_(True),
                Item.low_stock_threshold.is_not(None),
                func.coalesce(InventoryBalance.quantity_on_hand, 0) <= Item.low_stock_threshold,
            )
        )
        return int(value or 0)

    def _period_snapshot(
        self,
        *,
        store_id: UUID,
        start_utc: datetime,
        end_utc: datetime,
    ) -> ReportPeriodSnapshot:
        sales_total = self._sum_sales(store_id=store_id, start_utc=start_utc, end_utc=end_utc)
        expenses_total = self._sum_expenses(
            store_id=store_id,
            start_utc=start_utc,
            end_utc=end_utc,
        )
        return ReportPeriodSnapshot(
            period_start_utc=start_utc,
            period_end_utc=end_utc,
            sales_total=sales_total,
            expenses_total=expenses_total,
            estimated_profit=self._money(sales_total - expenses_total),
        )

    def _payment_breakdown(
        self,
        *,
        store_id: UUID,
        start_utc: datetime,
        end_utc: datetime,
    ) -> list[ReportPaymentBreakdownSnapshot]:
        rows = self.db.execute(
            select(
                Sale.payment_method_label,
                func.coalesce(func.sum(Sale.total_amount), Decimal("0.00")),
                func.count(Sale.id),
            )
            .where(
                Sale.store_id == store_id,
                Sale.created_at >= start_utc,
                Sale.created_at < end_utc,
            )
            .group_by(Sale.payment_method_label)
            .order_by(
                func.coalesce(func.sum(Sale.total_amount), Decimal("0.00")).desc(),
                func.count(Sale.id).desc(),
                Sale.payment_method_label.asc(),
            )
        ).all()
        return [
            ReportPaymentBreakdownSnapshot(
                payment_method_label=payment_method_label,
                payment_method_display=self._labelize_payment_method(payment_method_label),
                total_amount=self._money(total_amount),
                sale_count=int(sale_count or 0),
            )
            for payment_method_label, total_amount, sale_count in rows
        ]

    def _top_selling_items(
        self,
        *,
        store_id: UUID,
        start_utc: datetime,
        end_utc: datetime,
        limit: int,
    ) -> list[ReportTopSellingItemSnapshot]:
        rows = self.db.execute(
            select(
                Item.id,
                Item.name,
                func.coalesce(func.sum(SaleItem.quantity), 0),
                func.coalesce(func.sum(SaleItem.line_total), Decimal("0.00")),
            )
            .select_from(SaleItem)
            .join(Sale, Sale.id == SaleItem.sale_id)
            .join(Item, Item.id == SaleItem.item_id)
            .where(
                Sale.store_id == store_id,
                Sale.created_at >= start_utc,
                Sale.created_at < end_utc,
            )
            .group_by(Item.id, Item.name)
            .order_by(
                func.coalesce(func.sum(SaleItem.quantity), 0).desc(),
                func.coalesce(func.sum(SaleItem.line_total), Decimal("0.00")).desc(),
                Item.name.asc(),
            )
            .limit(limit)
        ).all()
        return [
            ReportTopSellingItemSnapshot(
                item_id=item_id,
                item_name=item_name,
                quantity_sold=int(quantity_sold or 0),
                sales_total=self._money(sales_total),
            )
            for item_id, item_name, quantity_sold, sales_total in rows
        ]

    def _recent_sales(self, *, store_id: UUID, limit: int) -> list[ReportActivitySnapshot]:
        rows = self.db.execute(
            select(Sale.total_amount, Sale.payment_method_label, Sale.created_at)
            .where(Sale.store_id == store_id)
            .order_by(Sale.created_at.desc())
            .limit(limit)
        ).all()
        return [
            ReportActivitySnapshot(
                activity_type="sale",
                title="Sale recorded",
                detail=self._labelize_payment_method(payment_method_label),
                amount=self._money(total_amount),
                created_at=created_at,
            )
            for total_amount, payment_method_label, created_at in rows
        ]

    def _recent_expenses(self, *, store_id: UUID, limit: int) -> list[ReportActivitySnapshot]:
        rows = self.db.execute(
            select(Expense.amount, Expense.category, Expense.note, Expense.created_at)
            .where(Expense.store_id == store_id)
            .order_by(Expense.created_at.desc())
            .limit(limit)
        ).all()
        return [
            ReportActivitySnapshot(
                activity_type="expense",
                title="Expense added",
                detail=self._labelize_expense(category, note),
                amount=self._money(amount),
                created_at=created_at,
            )
            for amount, category, note, created_at in rows
        ]

    def _recent_repayments(self, *, store_id: UUID, limit: int) -> list[ReportActivitySnapshot]:
        rows = self.db.execute(
            select(ReceivablePayment, Customer.name)
            .join(Receivable, Receivable.id == ReceivablePayment.receivable_id)
            .join(Customer, Customer.id == Receivable.customer_id)
            .where(Receivable.store_id == store_id)
            .order_by(ReceivablePayment.created_at.desc())
            .limit(limit)
        ).all()
        return [
            ReportActivitySnapshot(
                activity_type="repayment",
                title=f"{customer_name} paid",
                detail=self._labelize_payment_method(payment.payment_method_label),
                amount=self._money(payment.amount),
                created_at=payment.created_at,
            )
            for payment, customer_name in rows
        ]

    @staticmethod
    def _normalize_utc(as_of_utc: datetime | None) -> datetime:
        if as_of_utc is None:
            return datetime.now(tz=UTC)
        if as_of_utc.tzinfo is None:
            return as_of_utc.replace(tzinfo=UTC)
        return as_of_utc.astimezone(UTC)

    @staticmethod
    def _today_utc_window(*, now_utc: datetime, timezone_name: str) -> tuple[datetime, datetime]:
        return ReportsService._period_utc_window(
            now_utc=now_utc,
            timezone_name=timezone_name,
            period="day",
        )

    @staticmethod
    def _period_utc_window(
        *,
        now_utc: datetime,
        timezone_name: str,
        period: str,
    ) -> tuple[datetime, datetime]:
        tz = ZoneInfo(timezone_name)
        local_now = now_utc.astimezone(tz)
        local_date = date(local_now.year, local_now.month, local_now.day)

        if period == "day":
            start_date = local_date
            end_date = start_date + timedelta(days=1)
        elif period == "week":
            start_date = local_date - timedelta(days=local_date.weekday())
            end_date = start_date + timedelta(days=7)
        elif period == "month":
            start_date = date(local_date.year, local_date.month, 1)
            if local_date.month == 12:
                end_date = date(local_date.year + 1, 1, 1)
            else:
                end_date = date(local_date.year, local_date.month + 1, 1)
        else:  # pragma: no cover - internal misuse
            msg = f"Unsupported report period: {period}"
            raise ValueError(msg)

        local_start = datetime.combine(start_date, time.min, tzinfo=tz)
        local_end = datetime.combine(end_date, time.min, tzinfo=tz)
        return local_start.astimezone(UTC), local_end.astimezone(UTC)

    @staticmethod
    def _money(value: Decimal) -> Decimal:
        return value.quantize(_MONEY_SCALE, rounding=ROUND_HALF_UP)

    @staticmethod
    def _labelize_payment_method(value: str) -> str:
        normalized = value.strip().lower()
        if normalized == "mobile_money":
            return "Mobile Money"
        if normalized == "bank_transfer":
            return "Bank Transfer"
        return "Cash"

    @staticmethod
    def _labelize_expense(category: str, note: str | None) -> str:
        label = category.replace("_", " ").strip().title()
        if note is None or not note.strip():
            return label
        return f"{label} | {note.strip()}"
