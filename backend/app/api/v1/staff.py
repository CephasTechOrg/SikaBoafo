"""Staff management routes (owner-only)."""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db, require_role
from app.core.constants import USER_ROLE_MERCHANT_OWNER
from app.models.user import User
from app.schemas.staff import InviteStaffIn, StaffInviteOut, StaffMemberOut, UpdateRoleIn
from app.services.staff_service import (
    InviteConflictError,
    StaffContextError,
    StaffNotFoundError,
    StaffService,
)

router = APIRouter(prefix="/staff", tags=["staff"])

_OwnerOnly = Annotated[User, Depends(require_role(USER_ROLE_MERCHANT_OWNER))]


@router.get("", response_model=list[StaffMemberOut])
def list_staff(
    db: Annotated[Session, Depends(get_db)],
    current_user: _OwnerOnly,
) -> list[StaffMemberOut]:
    service = StaffService(db=db)
    try:
        return service.list_staff(owner_user_id=current_user.id)
    except StaffContextError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.get("/invites", response_model=list[StaffInviteOut])
def list_pending_invites(
    db: Annotated[Session, Depends(get_db)],
    current_user: _OwnerOnly,
) -> list[StaffInviteOut]:
    service = StaffService(db=db)
    try:
        return service.list_pending_invites(owner_user_id=current_user.id)
    except StaffContextError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.post("/invite", response_model=StaffInviteOut, status_code=status.HTTP_201_CREATED)
def invite_staff(
    payload: InviteStaffIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: _OwnerOnly,
) -> StaffInviteOut:
    service = StaffService(db=db)
    try:
        return service.invite_staff(owner_user_id=current_user.id, payload=payload)
    except StaffContextError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except InviteConflictError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.patch("/{staff_user_id}/role", response_model=StaffMemberOut)
def update_role(
    staff_user_id: UUID,
    payload: UpdateRoleIn,
    db: Annotated[Session, Depends(get_db)],
    current_user: _OwnerOnly,
) -> StaffMemberOut:
    service = StaffService(db=db)
    try:
        return service.update_role(
            owner_user_id=current_user.id,
            staff_user_id=staff_user_id,
            payload=payload,
        )
    except StaffContextError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except StaffNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.patch("/{staff_user_id}/deactivate", response_model=StaffMemberOut)
def deactivate_staff(
    staff_user_id: UUID,
    db: Annotated[Session, Depends(get_db)],
    current_user: _OwnerOnly,
) -> StaffMemberOut:
    service = StaffService(db=db)
    try:
        return service.deactivate_staff(
            owner_user_id=current_user.id,
            staff_user_id=staff_user_id,
        )
    except StaffContextError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except StaffNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
