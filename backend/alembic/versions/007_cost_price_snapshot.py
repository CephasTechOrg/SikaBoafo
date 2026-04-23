"""Add cost_price_snapshot to sale_items for real gross profit computation.

Revision ID: 007
Revises: 006
Create Date: 2026-04-22
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "007"
down_revision = "006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    cols = {c["name"] for c in inspector.get_columns("sale_items")}
    if "cost_price_snapshot" not in cols:
        op.add_column(
            "sale_items",
            sa.Column(
                "cost_price_snapshot",
                sa.Numeric(18, 2),
                nullable=True,
                comment="Cost price of the item at the time of sale. NULL for pre-M3 rows.",
            ),
        )


def downgrade() -> None:
    op.drop_column("sale_items", "cost_price_snapshot")
