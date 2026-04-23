"""Add invoice extension fields to receivables.

Revision ID: 008
Revises: 007
Create Date: 2026-04-23
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID as PGUUID

revision: str = "008"
down_revision: str | None = "007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    cols = {c["name"] for c in inspector.get_columns("receivables")}

    if "invoice_number" not in cols:
        op.add_column(
            "receivables",
            sa.Column("invoice_number", sa.String(32), nullable=True),
        )
        op.create_index(
            "ix_receivables_invoice_number",
            "receivables",
            ["invoice_number"],
            unique=True,
        )

    if "sale_id" not in cols:
        op.add_column(
            "receivables",
            sa.Column("sale_id", PGUUID(as_uuid=True), nullable=True),
        )

    if "created_by_user_id" not in cols:
        op.add_column(
            "receivables",
            sa.Column("created_by_user_id", PGUUID(as_uuid=True), nullable=True),
        )

    if "payment_link" not in cols:
        op.add_column(
            "receivables",
            sa.Column("payment_link", sa.String(500), nullable=True),
        )

    if "payment_provider_reference" not in cols:
        op.add_column(
            "receivables",
            sa.Column("payment_provider_reference", sa.String(255), nullable=True),
        )


def downgrade() -> None:
    op.drop_column("receivables", "payment_provider_reference")
    op.drop_column("receivables", "payment_link")
    op.drop_column("receivables", "created_by_user_id")
    op.drop_column("receivables", "sale_id")
    op.drop_index("ix_receivables_invoice_number", table_name="receivables")
    op.drop_column("receivables", "invoice_number")
