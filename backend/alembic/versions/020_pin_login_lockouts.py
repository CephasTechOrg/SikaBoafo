"""Add pin_login_lockouts table for PIN brute-force protection.

Revision ID: 020
Revises: 019
Create Date: 2026-05-25
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID as PGUUID

revision = "020"
down_revision = "019"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "pin_login_lockouts" in inspector.get_table_names():
        return

    op.create_table(
        "pin_login_lockouts",
        sa.Column("id", PGUUID(as_uuid=True), primary_key=True),
        sa.Column("phone_number", sa.String(length=32), nullable=False),
        sa.Column("failed_attempt_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("locked_until", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint("phone_number", name="uq_pin_login_lockouts_phone"),
    )
    op.create_index(
        "ix_pin_login_lockouts_phone_number",
        "pin_login_lockouts",
        ["phone_number"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_pin_login_lockouts_phone_number", table_name="pin_login_lockouts")
    op.drop_table("pin_login_lockouts")
