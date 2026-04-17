"""Add sale soft-void lifecycle columns.

Revision ID: 003
Revises: 002
Create Date: 2026-04-17
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "003"
down_revision: str | None = "002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    columns = {c["name"] for c in inspector.get_columns("sales")}

    if "sale_status" not in columns:
        op.add_column(
            "sales",
            sa.Column(
                "sale_status",
                sa.String(length=32),
                nullable=False,
                server_default="recorded",
            ),
        )

    if "voided_at" not in columns:
        op.add_column(
            "sales",
            sa.Column("voided_at", sa.DateTime(timezone=True), nullable=True),
        )

    if "void_reason" not in columns:
        op.add_column(
            "sales",
            sa.Column("void_reason", sa.String(length=255), nullable=True),
        )


def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    columns = {c["name"] for c in inspector.get_columns("sales")}

    if "void_reason" in columns:
        op.drop_column("sales", "void_reason")
    if "voided_at" in columns:
        op.drop_column("sales", "voided_at")
    if "sale_status" in columns:
        op.drop_column("sales", "sale_status")
