"""Merchant-owned Paystack credentials and payment snapshots.

Revision ID: 012
Revises: 011
Create Date: 2026-04-24
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID as PGUUID

revision = "012"
down_revision = "011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    connection_columns = {
        column["name"] for column in inspector.get_columns("payment_provider_connections")
    }
    if "test_public_key" not in connection_columns:
        op.add_column(
            "payment_provider_connections",
            sa.Column("test_public_key", sa.String(length=255), nullable=True),
        )
    if "live_public_key" not in connection_columns:
        op.add_column(
            "payment_provider_connections",
            sa.Column("live_public_key", sa.String(length=255), nullable=True),
        )
    if "test_secret_key_encrypted" not in connection_columns:
        op.add_column(
            "payment_provider_connections",
            sa.Column("test_secret_key_encrypted", sa.String(length=1024), nullable=True),
        )
    if "live_secret_key_encrypted" not in connection_columns:
        op.add_column(
            "payment_provider_connections",
            sa.Column("live_secret_key_encrypted", sa.String(length=1024), nullable=True),
        )
    if "test_secret_key_last4" not in connection_columns:
        op.add_column(
            "payment_provider_connections",
            sa.Column("test_secret_key_last4", sa.String(length=4), nullable=True),
        )
    if "live_secret_key_last4" not in connection_columns:
        op.add_column(
            "payment_provider_connections",
            sa.Column("live_secret_key_last4", sa.String(length=4), nullable=True),
        )
    if "test_verified_at" not in connection_columns:
        op.add_column(
            "payment_provider_connections",
            sa.Column("test_verified_at", sa.DateTime(timezone=True), nullable=True),
        )
    if "live_verified_at" not in connection_columns:
        op.add_column(
            "payment_provider_connections",
            sa.Column("live_verified_at", sa.DateTime(timezone=True), nullable=True),
        )

    if "public_key" in connection_columns:
        op.execute(
            sa.text(
                """
                UPDATE payment_provider_connections
                SET test_public_key = public_key
                WHERE mode = 'test' AND public_key IS NOT NULL AND test_public_key IS NULL
                """
            )
        )
        op.execute(
            sa.text(
                """
                UPDATE payment_provider_connections
                SET live_public_key = public_key
                WHERE mode = 'live' AND public_key IS NOT NULL AND live_public_key IS NULL
                """
            )
        )
    op.execute(sa.text("UPDATE payment_provider_connections SET is_connected = false"))

    payment_columns = {column["name"] for column in inspector.get_columns("payments")}
    if "merchant_id" not in payment_columns:
        op.add_column(
            "payments",
            sa.Column("merchant_id", PGUUID(as_uuid=True), nullable=True),
        )
        op.create_foreign_key(
            "fk_payments_merchant_id",
            "payments",
            "merchants",
            ["merchant_id"],
            ["id"],
            ondelete="SET NULL",
        )
    if "internal_reference" not in payment_columns:
        op.add_column(
            "payments",
            sa.Column("internal_reference", sa.String(length=255), nullable=True),
        )
    if "provider_mode" not in payment_columns:
        op.add_column(
            "payments",
            sa.Column("provider_mode", sa.String(length=16), nullable=True),
        )

    payment_indexes = {index["name"] for index in inspector.get_indexes("payments")}
    if "ix_payments_merchant_id" not in payment_indexes:
        op.create_index("ix_payments_merchant_id", "payments", ["merchant_id"])
    if "ix_payments_internal_reference" not in payment_indexes:
        op.create_index("ix_payments_internal_reference", "payments", ["internal_reference"])

    op.execute(
        sa.text(
            """
            UPDATE payments
            SET internal_reference = provider_reference
            WHERE internal_reference IS NULL AND provider_reference IS NOT NULL
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE payments
            SET merchant_id = (
                SELECT stores.merchant_id
                FROM sales
                JOIN stores ON stores.id = sales.store_id
                WHERE sales.id = payments.sale_id
            )
            WHERE merchant_id IS NULL AND sale_id IS NOT NULL
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE payments
            SET merchant_id = (
                SELECT stores.merchant_id
                FROM receivables
                JOIN stores ON stores.id = receivables.store_id
                WHERE receivables.payment_provider_reference = payments.provider_reference
            )
            WHERE merchant_id IS NULL AND provider_reference IS NOT NULL
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE payments
            SET provider_mode = (
                SELECT payment_provider_connections.mode
                FROM payment_provider_connections
                WHERE payment_provider_connections.merchant_id = payments.merchant_id
                  AND payment_provider_connections.provider = payments.provider
            )
            WHERE provider_mode IS NULL AND merchant_id IS NOT NULL
            """
        )
    )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    payment_indexes = {index["name"] for index in inspector.get_indexes("payments")}
    if "ix_payments_internal_reference" in payment_indexes:
        op.drop_index("ix_payments_internal_reference", table_name="payments")
    if "ix_payments_merchant_id" in payment_indexes:
        op.drop_index("ix_payments_merchant_id", table_name="payments")

    payment_columns = {column["name"] for column in inspector.get_columns("payments")}
    foreign_keys = {fk["name"] for fk in inspector.get_foreign_keys("payments")}
    if "fk_payments_merchant_id" in foreign_keys:
        op.drop_constraint("fk_payments_merchant_id", "payments", type_="foreignkey")
    if "provider_mode" in payment_columns:
        op.drop_column("payments", "provider_mode")
    if "internal_reference" in payment_columns:
        op.drop_column("payments", "internal_reference")
    if "merchant_id" in payment_columns:
        op.drop_column("payments", "merchant_id")

    connection_columns = {
        column["name"] for column in inspector.get_columns("payment_provider_connections")
    }
    for column_name in (
        "live_verified_at",
        "test_verified_at",
        "live_secret_key_last4",
        "test_secret_key_last4",
        "live_secret_key_encrypted",
        "test_secret_key_encrypted",
        "live_public_key",
        "test_public_key",
    ):
        if column_name in connection_columns:
            op.drop_column("payment_provider_connections", column_name)
