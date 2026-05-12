"""Enforce one receivable settlement link per payment.

Revision ID: 018
Revises: 017
Create Date: 2026-05-12
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "018"
down_revision: str | None = "017"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_index(
        "uq_payments_receivable_payment_id",
        "payments",
        ["receivable_payment_id"],
        unique=True,
        postgresql_where=sa.text("receivable_payment_id IS NOT NULL"),
        sqlite_where=sa.text("receivable_payment_id IS NOT NULL"),
    )


def downgrade() -> None:
    op.drop_index("uq_payments_receivable_payment_id", table_name="payments")

