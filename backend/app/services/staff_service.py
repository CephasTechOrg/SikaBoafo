"""Staff management service: invite, list, update role, deactivate."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.constants import (
    STAFF_INVITE_STATUS_ACCEPTED,
    STAFF_INVITE_STATUS_PENDING,
    USER_ROLE_MERCHANT_OWNER,
)
from app.models.merchant import Merchant
from app.models.staff_invite import StaffInvite
from app.models.store import Store
from app.models.user import User
from app.schemas.staff import InviteStaffIn, StaffInviteOut, StaffMemberOut, UpdateRoleIn
from app.services.phone_number import normalize_phone_number

_ROLE_DISPLAY = {
    "manager": "Manager",
    "cashier": "Cashier",
    "stock_keeper": "Stock Keeper",
}

_INVITE_TTL_DAYS = 7


class StaffContextError(Exception):
    """Caller does not have a merchant context."""


class StaffNotFoundError(Exception):
    """Staff member does not exist for this merchant."""


class InviteConflictError(Exception):
    """A pending invite already exists for this phone number."""


@dataclass(slots=True)
class StaffService:
    db: Session

    def _get_merchant(self, *, owner_user_id: UUID) -> Merchant:
        merchant = self.db.scalar(
            select(Merchant).where(Merchant.owner_user_id == owner_user_id)
        )
        if merchant is None:
            msg = "Merchant profile not found."
            raise StaffContextError(msg)
        return merchant

    def list_staff(self, *, owner_user_id: UUID) -> list[StaffMemberOut]:
        merchant = self._get_merchant(owner_user_id=owner_user_id)
        members = self.db.scalars(
            select(User).where(
                User.merchant_id == merchant.id,
                User.role != USER_ROLE_MERCHANT_OWNER,
            )
        ).all()
        return [
            StaffMemberOut(
                user_id=m.id,
                phone_number=m.phone_number,
                full_name=m.full_name,
                role=m.role,
                role_display=_ROLE_DISPLAY.get(m.role, m.role),
                is_active=m.is_active,
            )
            for m in members
        ]

    def list_pending_invites(self, *, owner_user_id: UUID) -> list[StaffInviteOut]:
        merchant = self._get_merchant(owner_user_id=owner_user_id)
        invites = self.db.scalars(
            select(StaffInvite).where(
                StaffInvite.merchant_id == merchant.id,
                StaffInvite.status == STAFF_INVITE_STATUS_PENDING,
            )
        ).all()
        return [_to_invite_out(inv) for inv in invites]

    def invite_staff(
        self, *, owner_user_id: UUID, payload: InviteStaffIn
    ) -> StaffInviteOut:
        merchant = self._get_merchant(owner_user_id=owner_user_id)
        normalized = normalize_phone_number(payload.phone_number)

        existing_invite = self.db.scalar(
            select(StaffInvite).where(
                StaffInvite.merchant_id == merchant.id,
                StaffInvite.phone_number == normalized,
                StaffInvite.status == STAFF_INVITE_STATUS_PENDING,
            )
        )
        if existing_invite is not None:
            msg = "A pending invite already exists for this phone number."
            raise InviteConflictError(msg)

        invite = StaffInvite(
            merchant_id=merchant.id,
            phone_number=normalized,
            role=payload.role,
            invited_by_user_id=owner_user_id,
            status=STAFF_INVITE_STATUS_PENDING,
            expires_at=datetime.now(UTC) + timedelta(days=_INVITE_TTL_DAYS),
        )
        invite.id = uuid4()
        self.db.add(invite)
        self.db.commit()
        self.db.refresh(invite)
        return _to_invite_out(invite)

    def update_role(
        self, *, owner_user_id: UUID, staff_user_id: UUID, payload: UpdateRoleIn
    ) -> StaffMemberOut:
        merchant = self._get_merchant(owner_user_id=owner_user_id)
        member = self._get_staff_member(merchant_id=merchant.id, staff_user_id=staff_user_id)
        member.role = payload.role
        self.db.add(member)
        self.db.commit()
        self.db.refresh(member)
        return _to_member_out(member)

    def deactivate_staff(self, *, owner_user_id: UUID, staff_user_id: UUID) -> StaffMemberOut:
        merchant = self._get_merchant(owner_user_id=owner_user_id)
        member = self._get_staff_member(merchant_id=merchant.id, staff_user_id=staff_user_id)
        member.is_active = False
        self.db.add(member)
        self.db.commit()
        self.db.refresh(member)
        return _to_member_out(member)

    def _get_staff_member(self, *, merchant_id: UUID, staff_user_id: UUID) -> User:
        member = self.db.scalar(
            select(User).where(
                User.id == staff_user_id,
                User.merchant_id == merchant_id,
            )
        )
        if member is None:
            msg = "Staff member not found."
            raise StaffNotFoundError(msg)
        return member


def _to_member_out(m: User) -> StaffMemberOut:
    return StaffMemberOut(
        user_id=m.id,
        phone_number=m.phone_number,
        full_name=m.full_name,
        role=m.role,
        role_display=_ROLE_DISPLAY.get(m.role, m.role),
        is_active=m.is_active,
    )


def _to_invite_out(inv: StaffInvite) -> StaffInviteOut:
    return StaffInviteOut(
        invite_id=inv.id,
        phone_number=inv.phone_number,
        role=inv.role,
        role_display=_ROLE_DISPLAY.get(inv.role, inv.role),
        status=inv.status,
        expires_at=inv.expires_at,
    )
