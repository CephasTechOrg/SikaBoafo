"""Add version columns to items and inventory_balances for optimistic locking.

Revision ID: 014
Revises: 013
Create Date: 2026-04-27
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "014"
down_revision = "013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    item_cols = {c["name"] for c in inspector.get_columns("items")}
    if "version" not in item_cols:
        op.add_column("items", sa.Column("version", sa.Integer, nullable=True))
        op.execute(sa.text("UPDATE items SET version = 1"))
        op.alter_column("items", "version", nullable=False)

    balance_cols = {c["name"] for c in inspector.get_columns("inventory_balances")}
    if "version" not in balance_cols:
        op.add_column(
            "inventory_balances", sa.Column("version", sa.Integer, nullable=True)
        )
        op.execute(sa.text("UPDATE inventory_balances SET version = 1"))
        op.alter_column("inventory_balances", "version", nullable=False)


def downgrade() -> None:
    op.drop_column("inventory_balances", "version")
    op.drop_column("items", "version")
