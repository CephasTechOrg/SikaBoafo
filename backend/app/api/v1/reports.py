"""Reporting routes."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.models.user import User
from app.schemas.report import ReportActivityOut, ReportInsightsOut, ReportSummaryOut
from app.services.reports_service import ReportContextMissingError, ReportsService

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/summary", response_model=ReportSummaryOut)
def get_summary(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    as_of_utc: Annotated[datetime | None, Query()] = None,
) -> ReportSummaryOut:
    service = ReportsService(db=db)
    try:
        summary = service.get_summary_for_user(user_id=current_user.id, as_of_utc=as_of_utc)
    except ReportContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return ReportSummaryOut(
        timezone=summary.timezone,
        period_start_utc=summary.period_start_utc,
        period_end_utc=summary.period_end_utc,
        today_sales_total=summary.today_sales_total,
        today_expenses_total=summary.today_expenses_total,
        today_estimated_profit=summary.today_estimated_profit,
        today_gross_profit=summary.today_gross_profit,
        debt_outstanding_total=summary.debt_outstanding_total,
        low_stock_count=summary.low_stock_count,
    )


@router.get("/recent-activity", response_model=list[ReportActivityOut])
def list_recent_activity(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    limit: Annotated[int, Query(ge=1, le=20)] = 8,
) -> list[ReportActivityOut]:
    service = ReportsService(db=db)
    try:
        rows = service.list_recent_activity_for_user(user_id=current_user.id, limit=limit)
    except ReportContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return [
        ReportActivityOut(
            activity_type=row.activity_type,
            title=row.title,
            detail=row.detail,
            amount=row.amount,
            created_at=row.created_at,
            item_id=row.item_id,
            item_name=row.item_name,
        )
        for row in rows
    ]


@router.get("/insights", response_model=ReportInsightsOut)
def get_insights(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    as_of_utc: Annotated[datetime | None, Query()] = None,
    top_n: Annotated[int, Query(ge=1, le=10)] = 5,
) -> ReportInsightsOut:
    service = ReportsService(db=db)
    try:
        insights = service.get_insights_for_user(
            user_id=current_user.id,
            as_of_utc=as_of_utc,
            top_n=top_n,
        )
    except ReportContextMissingError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return ReportInsightsOut(
        timezone=insights.timezone,
        week={
            "period_start_utc": insights.week.period_start_utc,
            "period_end_utc": insights.week.period_end_utc,
            "sales_total": insights.week.sales_total,
            "expenses_total": insights.week.expenses_total,
            "estimated_profit": insights.week.estimated_profit,
            "gross_profit": insights.week.gross_profit,
        },
        month={
            "period_start_utc": insights.month.period_start_utc,
            "period_end_utc": insights.month.period_end_utc,
            "sales_total": insights.month.sales_total,
            "expenses_total": insights.month.expenses_total,
            "estimated_profit": insights.month.estimated_profit,
            "gross_profit": insights.month.gross_profit,
        },
        monthly_payment_breakdown=[
            {
                "payment_method_label": row.payment_method_label,
                "payment_method_display": row.payment_method_display,
                "total_amount": row.total_amount,
                "sale_count": row.sale_count,
            }
            for row in insights.monthly_payment_breakdown
        ],
        monthly_top_selling_items=[
            {
                "item_id": row.item_id,
                "item_name": row.item_name,
                "quantity_sold": row.quantity_sold,
                "sales_total": row.sales_total,
            }
            for row in insights.monthly_top_selling_items
        ],
    )
