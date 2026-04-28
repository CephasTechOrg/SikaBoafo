"""Add image_url to items table for Supabase Storage integration.

Revision ID: 015
Revises: 014
Create Date: 2026-04-28
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "015"
down_revision = "014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    cols = {c["name"] for c in inspector.get_columns("items")}
    if "image_url" not in cols:
        op.add_column("items", sa.Column("image_url", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("items", "image_url")
