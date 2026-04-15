"""API v1 routes."""

from fastapi import APIRouter

from app.api.v1 import auth, health

router = APIRouter()
router.include_router(health.router, tags=["health"])
router.include_router(auth.router)
