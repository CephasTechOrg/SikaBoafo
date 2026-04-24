"""Add webhook event idempotency table and unique payment references.

Revision ID: 010
Revises: 009
Create Date: 2026-04-24
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PGUUID

revision = "010"
down_revision = "009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing_tables = inspector.get_table_names()

    if "payment_webhook_events" not in existing_tables:
        op.create_table(
            "payment_webhook_events",
            sa.Column("id", PGUUID(as_uuid=True), primary_key=True),
            sa.Column("provider", sa.String(length=32), nullable=False, server_default="paystack"),
            sa.Column("event_key", sa.String(length=255), nullable=False),
            sa.Column("provider_reference", sa.String(length=255), nullable=True),
            sa.Column("payment_id", PGUUID(as_uuid=True), nullable=True),
            sa.Column("result_status", sa.String(length=32), nullable=False, server_default="processed"),
            sa.Column("payload", JSONB, nullable=True),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.func.now(),
            ),
            sa.Column("processed_at", sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(["payment_id"], ["payments.id"], ondelete="SET NULL"),
            sa.UniqueConstraint(
                "provider",
                "event_key",
                name="uq_payment_webhook_events_provider_event_key",
            ),
        )

    webhook_idxs = {i["name"] for i in inspector.get_indexes("payment_webhook_events")}
    if "ix_payment_webhook_events_provider" not in webhook_idxs:
        op.create_index(
            "ix_payment_webhook_events_provider",
            "payment_webhook_events",
            ["provider"],
        )
    if "ix_payment_webhook_events_provider_reference" not in webhook_idxs:
        op.create_index(
            "ix_payment_webhook_events_provider_reference",
            "payment_webhook_events",
            ["provider_reference"],
        )
    if "ix_payment_webhook_events_payment_id" not in webhook_idxs:
        op.create_index(
            "ix_payment_webhook_events_payment_id",
            "payment_webhook_events",
            ["payment_id"],
        )

    payment_idxs = {i["name"] for i in inspector.get_indexes("payments")}
    if "uq_payments_provider_reference" not in payment_idxs:
        op.create_index(
            "uq_payments_provider_reference",
            "payments",
            ["provider_reference"],
            unique=True,
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    payment_idxs = {i["name"] for i in inspector.get_indexes("payments")}
    if "uq_payments_provider_reference" in payment_idxs:
        op.drop_index("uq_payments_provider_reference", table_name="payments")

    existing_tables = inspector.get_table_names()
    if "payment_webhook_events" not in existing_tables:
        return

    webhook_idxs = {i["name"] for i in inspector.get_indexes("payment_webhook_events")}
    if "ix_payment_webhook_events_payment_id" in webhook_idxs:
        op.drop_index("ix_payment_webhook_events_payment_id", table_name="payment_webhook_events")
    if "ix_payment_webhook_events_provider_reference" in webhook_idxs:
        op.drop_index(
            "ix_payment_webhook_events_provider_reference",
            table_name="payment_webhook_events",
        )
    if "ix_payment_webhook_events_provider" in webhook_idxs:
        op.drop_index("ix_payment_webhook_events_provider", table_name="payment_webhook_events")
    op.drop_table("payment_webhook_events")

