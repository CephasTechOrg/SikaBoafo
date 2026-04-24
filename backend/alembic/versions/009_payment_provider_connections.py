"""Add payment_provider_connections table (M4 Step 1).

Revision ID: 009
Revises: 008
Create Date: 2026-04-23
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID as PGUUID

revision = "009"
down_revision = "008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing_tables = inspector.get_table_names()

    if "payment_provider_connections" not in existing_tables:
        op.create_table(
            "payment_provider_connections",
            sa.Column("id", PGUUID(as_uuid=True), primary_key=True),
            sa.Column("merchant_id", PGUUID(as_uuid=True), nullable=False),
            sa.Column(
                "provider",
                sa.String(length=32),
                nullable=False,
                server_default="paystack",
            ),
            sa.Column(
                "mode",
                sa.String(length=16),
                nullable=False,
                server_default="test",
            ),
            sa.Column("account_label", sa.String(length=120), nullable=True),
            sa.Column("public_key", sa.String(length=255), nullable=True),
            sa.Column(
                "is_connected",
                sa.Boolean(),
                nullable=False,
                server_default=sa.false(),
            ),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                server_default=sa.func.now(),
                nullable=False,
            ),
            sa.ForeignKeyConstraint(
                ["merchant_id"],
                ["merchants.id"],
                ondelete="CASCADE",
            ),
            sa.UniqueConstraint(
                "merchant_id",
                "provider",
                name="uq_payment_provider_connections_merchant_provider",
            ),
        )

    idxs = {i["name"] for i in inspector.get_indexes("payment_provider_connections")}
    if "ix_payment_provider_connections_merchant_id" not in idxs:
        op.create_index(
            "ix_payment_provider_connections_merchant_id",
            "payment_provider_connections",
            ["merchant_id"],
        )
    if "ix_payment_provider_connections_provider" not in idxs:
        op.create_index(
            "ix_payment_provider_connections_provider",
            "payment_provider_connections",
            ["provider"],
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing_tables = inspector.get_table_names()
    if "payment_provider_connections" not in existing_tables:
        return

    idxs = {i["name"] for i in inspector.get_indexes("payment_provider_connections")}
    if "ix_payment_provider_connections_provider" in idxs:
        op.drop_index(
            "ix_payment_provider_connections_provider",
            table_name="payment_provider_connections",
        )
    if "ix_payment_provider_connections_merchant_id" in idxs:
        op.drop_index(
            "ix_payment_provider_connections_merchant_id",
            table_name="payment_provider_connections",
        )
    op.drop_table("payment_provider_connections")
