"""Add otp_send_throttles table for OTP SMS rate limiting.

Revision ID: 021
Revises: 020
Create Date: 2026-05-25
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID as PGUUID

revision = "021"
down_revision = "020"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "otp_send_throttles" in inspector.get_table_names():
        return

    op.create_table(
        "otp_send_throttles",
        sa.Column("id", PGUUID(as_uuid=True), primary_key=True),
        sa.Column("phone_number", sa.String(length=32), nullable=False),
        sa.Column("window_started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("send_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint("phone_number", name="uq_otp_send_throttles_phone"),
    )
    op.create_index(
        "ix_otp_send_throttles_phone_number",
        "otp_send_throttles",
        ["phone_number"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_otp_send_throttles_phone_number", table_name="otp_send_throttles")
    op.drop_table("otp_send_throttles")
