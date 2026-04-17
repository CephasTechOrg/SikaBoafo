"""Add optional PIN hash on users (phone + PIN daily login).

Revision ID: 002
Revises: 001
Create Date: 2026-04-15
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "002"
down_revision: str | None = "001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # `001` uses `create_all` against current models, so fresh installs may already
    # include `pin_hash`. Only add the column when upgrading older databases.
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    columns = {c["name"] for c in inspector.get_columns("users")}
    if "pin_hash" not in columns:
        op.add_column("users", sa.Column("pin_hash", sa.String(length=255), nullable=True))


def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    columns = {c["name"] for c in inspector.get_columns("users")}
    if "pin_hash" in columns:
        op.drop_column("users", "pin_hash")
