"""Reporting request and response schemas."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel


class ReportSummaryOut(BaseModel):
    timezone: str
    period_start_utc: datetime
    period_end_utc: datetime
    today_sales_total: Decimal
    today_expenses_total: Decimal
    today_estimated_profit: Decimal
    today_gross_profit: Decimal = Decimal("0.00")
    debt_outstanding_total: Decimal
    low_stock_count: int


class ReportActivityOut(BaseModel):
    activity_type: str
    title: str
    detail: str
    amount: Decimal
    created_at: datetime
    item_id: UUID | None = None
    item_name: str | None = None


class ReportPeriodOut(BaseModel):
    period_start_utc: datetime
    period_end_utc: datetime
    sales_total: Decimal
    expenses_total: Decimal
    estimated_profit: Decimal
    gross_profit: Decimal = Decimal("0.00")


class ReportPaymentBreakdownOut(BaseModel):
    payment_method_label: str
    payment_method_display: str
    total_amount: Decimal
    sale_count: int


class ReportTopSellingItemOut(BaseModel):
    item_id: UUID
    item_name: str
    quantity_sold: int
    sales_total: Decimal


class ReportInsightsOut(BaseModel):
    timezone: str
    week: ReportPeriodOut
    month: ReportPeriodOut
    monthly_payment_breakdown: list[ReportPaymentBreakdownOut]
    monthly_top_selling_items: list[ReportTopSellingItemOut]
