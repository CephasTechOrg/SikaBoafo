"""API v1 routes."""

from fastapi import APIRouter

from app.api.v1 import (
    auth,
    expenses,
    health,
    items,
    merchants,
    payments,
    receivables,
    reports,
    sales,
    staff,
    stores,
    sync,
    webhooks,
)

router = APIRouter()
router.include_router(health.router, tags=["health"])
router.include_router(auth.router)
router.include_router(merchants.router)
router.include_router(stores.router)
router.include_router(items.router)
router.include_router(sales.router)
router.include_router(expenses.router)
router.include_router(payments.router)
router.include_router(receivables.router)
router.include_router(reports.router)
router.include_router(staff.router)
router.include_router(sync.router)
router.include_router(webhooks.router)
