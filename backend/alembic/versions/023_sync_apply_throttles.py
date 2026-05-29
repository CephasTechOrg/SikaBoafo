"""Add sync_apply_throttles table for /sync/apply rate limiting.

Revision ID: 023
Revises: 022
Create Date: 2026-05-29
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID as PGUUID

revision = "023"
down_revision = "022"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "sync_apply_throttles" in inspector.get_table_names():
        return

    op.create_table(
        "sync_apply_throttles",
        sa.Column("id", PGUUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", PGUUID(as_uuid=True), nullable=False),
        sa.Column("window_started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("request_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("user_id", name="uq_sync_apply_throttles_user"),
    )
    op.create_index(
        "ix_sync_apply_throttles_user_id",
        "sync_apply_throttles",
        ["user_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_sync_apply_throttles_user_id", table_name="sync_apply_throttles")
    op.drop_table("sync_apply_throttles")
