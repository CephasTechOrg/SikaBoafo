"""Add locally managed OTP code table.

Revision ID: 011
Revises: 010
Create Date: 2026-04-24
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID as PGUUID

revision = "011"
down_revision = "010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing_tables = inspector.get_table_names()

    if "otp_codes" not in existing_tables:
        op.create_table(
            "otp_codes",
            sa.Column("id", PGUUID(as_uuid=True), primary_key=True),
            sa.Column("phone_number", sa.String(length=32), nullable=False),
            sa.Column("code_hash", sa.String(length=255), nullable=False),
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("attempt_count", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("delivery_provider", sa.String(length=32), nullable=True),
            sa.Column("delivery_reference", sa.String(length=255), nullable=True),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.func.now(),
            ),
        )

    otp_indexes = {index["name"] for index in inspector.get_indexes("otp_codes")}
    if "ix_otp_codes_phone_number" not in otp_indexes:
        op.create_index("ix_otp_codes_phone_number", "otp_codes", ["phone_number"])
    if "ix_otp_codes_created_at" not in otp_indexes:
        op.create_index("ix_otp_codes_created_at", "otp_codes", ["created_at"])


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing_tables = inspector.get_table_names()
    if "otp_codes" not in existing_tables:
        return

    otp_indexes = {index["name"] for index in inspector.get_indexes("otp_codes")}
    if "ix_otp_codes_created_at" in otp_indexes:
        op.drop_index("ix_otp_codes_created_at", table_name="otp_codes")
    if "ix_otp_codes_phone_number" in otp_indexes:
        op.drop_index("ix_otp_codes_phone_number", table_name="otp_codes")
    op.drop_table("otp_codes")
