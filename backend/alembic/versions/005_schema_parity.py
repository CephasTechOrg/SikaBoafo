"""Schema parity: extend merchants, users, customers, items, sales, audit_logs; composite indexes.

Revision ID: 005
Revises: 004
Create Date: 2026-04-22
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID as PGUUID

revision: str = "005"
down_revision: str | None = "004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)

    # --- merchants ---
    cols = {c["name"] for c in inspector.get_columns("merchants")}
    if "phone" not in cols:
        op.add_column("merchants", sa.Column("phone", sa.String(32), nullable=True))
    if "whatsapp_number" not in cols:
        op.add_column("merchants", sa.Column("whatsapp_number", sa.String(32), nullable=True))
    if "email" not in cols:
        op.add_column("merchants", sa.Column("email", sa.String(255), nullable=True))
    if "address" not in cols:
        op.add_column("merchants", sa.Column("address", sa.String(500), nullable=True))
    if "city" not in cols:
        op.add_column("merchants", sa.Column("city", sa.String(128), nullable=True))
    if "region" not in cols:
        op.add_column("merchants", sa.Column("region", sa.String(128), nullable=True))
    if "country" not in cols:
        op.add_column(
            "merchants",
            sa.Column("country", sa.String(8), nullable=True, server_default="GH"),
        )
    if "currency_code" not in cols:
        op.add_column(
            "merchants",
            sa.Column("currency_code", sa.String(8), nullable=True, server_default="GHS"),
        )

    # --- users ---
    cols = {c["name"] for c in inspector.get_columns("users")}
    if "full_name" not in cols:
        op.add_column("users", sa.Column("full_name", sa.String(255), nullable=True))
    if "email" not in cols:
        op.add_column("users", sa.Column("email", sa.String(255), nullable=True))
    if "last_login_at" not in cols:
        op.add_column(
            "users",
            sa.Column("last_login_at", sa.DateTime(timezone=True), nullable=True),
        )

    # --- customers ---
    cols = {c["name"] for c in inspector.get_columns("customers")}
    if "whatsapp_number" not in cols:
        op.add_column("customers", sa.Column("whatsapp_number", sa.String(32), nullable=True))
    if "email" not in cols:
        op.add_column("customers", sa.Column("email", sa.String(255), nullable=True))
    if "address" not in cols:
        op.add_column("customers", sa.Column("address", sa.String(500), nullable=True))
    if "notes" not in cols:
        op.add_column("customers", sa.Column("notes", sa.Text(), nullable=True))
    if "preferred_contact_channel" not in cols:
        op.add_column(
            "customers",
            sa.Column("preferred_contact_channel", sa.String(32), nullable=True),
        )
    if "is_active" not in cols:
        op.add_column(
            "customers",
            sa.Column("is_active", sa.Boolean(), nullable=True, server_default="true"),
        )

    # --- items ---
    cols = {c["name"] for c in inspector.get_columns("items")}
    if "cost_price" not in cols:
        op.add_column("items", sa.Column("cost_price", sa.Numeric(18, 2), nullable=True))
    if "unit" not in cols:
        op.add_column("items", sa.Column("unit", sa.String(32), nullable=True))

    # --- sales ---
    cols = {c["name"] for c in inspector.get_columns("sales")}
    if "subtotal_amount" not in cols:
        op.add_column("sales", sa.Column("subtotal_amount", sa.Numeric(18, 2), nullable=True))
    if "discount_amount" not in cols:
        op.add_column("sales", sa.Column("discount_amount", sa.Numeric(18, 2), nullable=True))
    if "tax_amount" not in cols:
        op.add_column("sales", sa.Column("tax_amount", sa.Numeric(18, 2), nullable=True))

    # --- audit_logs ---
    cols = {c["name"] for c in inspector.get_columns("audit_logs")}
    if "business_id" not in cols:
        op.add_column("audit_logs", sa.Column("business_id", PGUUID(as_uuid=True), nullable=True))
    if "ip_address" not in cols:
        op.add_column("audit_logs", sa.Column("ip_address", sa.String(64), nullable=True))
    if "user_agent" not in cols:
        op.add_column("audit_logs", sa.Column("user_agent", sa.String(512), nullable=True))

    # --- composite indexes ---
    idxs = {i["name"] for i in inspector.get_indexes("customers")}
    if "ix_customers_phone_store" not in idxs:
        op.create_index("ix_customers_phone_store", "customers", ["phone_number", "store_id"])

    idxs = {i["name"] for i in inspector.get_indexes("items")}
    if "ix_items_sku_store" not in idxs:
        op.create_index("ix_items_sku_store", "items", ["sku", "store_id"])

    idxs = {i["name"] for i in inspector.get_indexes("inventory_movements")}
    if "ix_inventory_movements_item_created" not in idxs:
        op.create_index(
            "ix_inventory_movements_item_created",
            "inventory_movements",
            ["item_id", "created_at"],
        )

    idxs = {i["name"] for i in inspector.get_indexes("audit_logs")}
    if "ix_audit_logs_business_id" not in idxs:
        op.create_index("ix_audit_logs_business_id", "audit_logs", ["business_id"])


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_audit_logs_business_id")
    op.execute("DROP INDEX IF EXISTS ix_inventory_movements_item_created")
    op.execute("DROP INDEX IF EXISTS ix_items_sku_store")
    op.execute("DROP INDEX IF EXISTS ix_customers_phone_store")

    for col in ("business_id", "ip_address", "user_agent"):
        op.drop_column("audit_logs", col)
    for col in ("subtotal_amount", "discount_amount", "tax_amount"):
        op.drop_column("sales", col)
    for col in ("cost_price", "unit"):
        op.drop_column("items", col)
    for col in (
        "whatsapp_number",
        "email",
        "address",
        "notes",
        "preferred_contact_channel",
        "is_active",
    ):
        op.drop_column("customers", col)
    for col in ("full_name", "email", "last_login_at"):
        op.drop_column("users", col)
    for col in (
        "phone",
        "whatsapp_number",
        "email",
        "address",
        "city",
        "region",
        "country",
        "currency_code",
    ):
        op.drop_column("merchants", col)
