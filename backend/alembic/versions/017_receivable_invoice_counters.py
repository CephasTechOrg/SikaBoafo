"""Add invoice counters for receivables.

Revision ID: 017
Revises: 016
Create Date: 2026-05-06

This introduces a per-store, per-year counter to allocate receivable invoice numbers
without collisions under concurrent sync bursts.
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID as PGUUID

revision: str = "017"
down_revision: str | None = "016"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "receivable_invoice_counters",
        sa.Column("store_id", PGUUID(as_uuid=True), nullable=False),
        sa.Column("year", sa.Integer(), nullable=False),
        sa.Column("next_number", sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint("store_id", "year"),
    )


def downgrade() -> None:
    op.drop_table("receivable_invoice_counters")

