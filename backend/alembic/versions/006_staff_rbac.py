"""Staff RBAC: merchant_id on users, cashier_id on sales, user_id on movements, staff_invites table.

Revision ID: 006
Revises: 005
Create Date: 2026-04-22
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID as PGUUID

# revision identifiers, used by Alembic.
revision = "006"
down_revision = "005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    # ── users: add merchant_id FK ────────────────────────────────────────────
    users_cols = {c["name"] for c in inspector.get_columns("users")}
    if "merchant_id" not in users_cols:
        op.add_column(
            "users",
            sa.Column("merchant_id", PGUUID(as_uuid=True), nullable=True),
        )
        op.create_foreign_key(
            "fk_users_merchant_id",
            "users",
            "merchants",
            ["merchant_id"],
            ["id"],
            ondelete="SET NULL",
        )
        op.create_index("ix_users_merchant_id", "users", ["merchant_id"])

    # ── sales: add cashier_id FK ─────────────────────────────────────────────
    sales_cols = {c["name"] for c in inspector.get_columns("sales")}
    if "cashier_id" not in sales_cols:
        op.add_column(
            "sales",
            sa.Column("cashier_id", PGUUID(as_uuid=True), nullable=True),
        )
        op.create_foreign_key(
            "fk_sales_cashier_id",
            "sales",
            "users",
            ["cashier_id"],
            ["id"],
            ondelete="SET NULL",
        )
        op.create_index("ix_sales_cashier_id", "sales", ["cashier_id"])

    # ── inventory_movements: add user_id ────────────────────────────────────
    inv_mov_cols = {c["name"] for c in inspector.get_columns("inventory_movements")}
    if "user_id" not in inv_mov_cols:
        op.add_column(
            "inventory_movements",
            sa.Column("user_id", PGUUID(as_uuid=True), nullable=True),
        )
        op.create_foreign_key(
            "fk_inventory_movements_user_id",
            "inventory_movements",
            "users",
            ["user_id"],
            ["id"],
            ondelete="SET NULL",
        )

    # ── staff_invites table ──────────────────────────────────────────────────
    existing_tables = inspector.get_table_names()
    if "staff_invites" not in existing_tables:
        op.create_table(
            "staff_invites",
            sa.Column("id", PGUUID(as_uuid=True), primary_key=True),
            sa.Column("merchant_id", PGUUID(as_uuid=True), nullable=False),
            sa.Column("phone_number", sa.String(32), nullable=False),
            sa.Column("role", sa.String(32), nullable=False),
            sa.Column("invited_by_user_id", PGUUID(as_uuid=True), nullable=True),
            sa.Column("status", sa.String(16), nullable=False, server_default="pending"),
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                server_default=sa.func.now(),
                nullable=False,
            ),
            sa.Column(
                "updated_at",
                sa.DateTime(timezone=True),
                server_default=sa.func.now(),
                nullable=False,
            ),
            sa.ForeignKeyConstraint(
                ["merchant_id"], ["merchants.id"], ondelete="CASCADE"
            ),
            sa.ForeignKeyConstraint(
                ["invited_by_user_id"], ["users.id"], ondelete="SET NULL"
            ),
        )
        op.create_index("ix_staff_invites_merchant_id", "staff_invites", ["merchant_id"])
        op.create_index("ix_staff_invites_phone_number", "staff_invites", ["phone_number"])
        op.create_index(
            "ix_staff_invites_status",
            "staff_invites",
            ["merchant_id", "phone_number", "status"],
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing_tables = inspector.get_table_names()

    if "staff_invites" in existing_tables:
        op.drop_index("ix_staff_invites_status", table_name="staff_invites")
        op.drop_index("ix_staff_invites_phone_number", table_name="staff_invites")
        op.drop_index("ix_staff_invites_merchant_id", table_name="staff_invites")
        op.drop_table("staff_invites")

    inv_mov_cols = {c["name"] for c in inspector.get_columns("inventory_movements")}
    if "user_id" in inv_mov_cols:
        op.drop_constraint(
            "fk_inventory_movements_user_id", "inventory_movements", type_="foreignkey"
        )
        op.drop_column("inventory_movements", "user_id")

    sales_cols = {c["name"] for c in inspector.get_columns("sales")}
    if "cashier_id" in sales_cols:
        op.drop_index("ix_sales_cashier_id", table_name="sales")
        op.drop_constraint("fk_sales_cashier_id", "sales", type_="foreignkey")
        op.drop_column("sales", "cashier_id")

    users_cols = {c["name"] for c in inspector.get_columns("users")}
    if "merchant_id" in users_cols:
        op.drop_index("ix_users_merchant_id", table_name="users")
        op.drop_constraint("fk_users_merchant_id", "users", type_="foreignkey")
        op.drop_column("users", "merchant_id")
