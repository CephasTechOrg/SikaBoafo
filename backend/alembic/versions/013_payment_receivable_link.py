"""Persist receivable linkage on payments for stable webhook settlement.

Revision ID: 013
Revises: 012
Create Date: 2026-04-25
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID as PGUUID

revision = "013"
down_revision = "012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    payment_columns = {column["name"] for column in inspector.get_columns("payments")}
    if "receivable_id" not in payment_columns:
        op.add_column(
            "payments",
            sa.Column("receivable_id", PGUUID(as_uuid=True), nullable=True),
        )
        op.create_foreign_key(
            "fk_payments_receivable_id",
            "payments",
            "receivables",
            ["receivable_id"],
            ["id"],
            ondelete="SET NULL",
        )

    payment_indexes = {index["name"] for index in inspector.get_indexes("payments")}
    if "ix_payments_receivable_id" not in payment_indexes:
        op.create_index("ix_payments_receivable_id", "payments", ["receivable_id"])

    op.execute(
        sa.text(
            """
            UPDATE payments
            SET receivable_id = receivables.id
            FROM receivables
            WHERE payments.receivable_id IS NULL
              AND payments.provider_reference IS NOT NULL
              AND receivables.payment_provider_reference = payments.provider_reference
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE payments
            SET receivable_id = receivable_payments.receivable_id
            FROM receivable_payments
            WHERE payments.receivable_id IS NULL
              AND payments.receivable_payment_id = receivable_payments.id
            """
        )
    )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    payment_indexes = {index["name"] for index in inspector.get_indexes("payments")}
    if "ix_payments_receivable_id" in payment_indexes:
        op.drop_index("ix_payments_receivable_id", table_name="payments")

    payment_columns = {column["name"] for column in inspector.get_columns("payments")}
    foreign_keys = {fk["name"] for fk in inspector.get_foreign_keys("payments")}
    if "fk_payments_receivable_id" in foreign_keys:
        op.drop_constraint("fk_payments_receivable_id", "payments", type_="foreignkey")
    if "receivable_id" in payment_columns:
        op.drop_column("payments", "receivable_id")
