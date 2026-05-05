"""Add item_variants table and variant columns to sale_items.

Revision ID: 016
Revises: 015
Create Date: 2026-05-05
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision = "016"
down_revision = "015"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing_tables = inspector.get_table_names()

    if "item_variants" not in existing_tables:
        op.create_table(
            "item_variants",
            sa.Column("id", UUID(as_uuid=True), primary_key=True),
            sa.Column(
                "item_id",
                UUID(as_uuid=True),
                sa.ForeignKey("items.id", ondelete="CASCADE"),
                nullable=False,
                index=True,
            ),
            sa.Column("label", sa.String(64), nullable=False),
            sa.Column("price_override", sa.Numeric(18, 2), nullable=True),
            sa.Column("sort_order", sa.Integer, nullable=False, server_default="0"),
            sa.Column("is_active", sa.Boolean, nullable=False, server_default="true"),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                server_default=sa.func.now(),
                nullable=False,
            ),
        )

    sale_item_cols = {c["name"] for c in inspector.get_columns("sale_items")}
    if "variant_id" not in sale_item_cols:
        op.add_column(
            "sale_items",
            sa.Column(
                "variant_id",
                UUID(as_uuid=True),
                sa.ForeignKey("item_variants.id", ondelete="SET NULL"),
                nullable=True,
            ),
        )
        op.create_index("ix_sale_items_variant_id", "sale_items", ["variant_id"])
    if "variant_label" not in sale_item_cols:
        op.add_column(
            "sale_items",
            sa.Column("variant_label", sa.String(64), nullable=True),
        )


def downgrade() -> None:
    op.drop_index("ix_sale_items_variant_id", table_name="sale_items")
    op.drop_column("sale_items", "variant_label")
    op.drop_column("sale_items", "variant_id")
    op.drop_table("item_variants")
