"""Scope receivable invoice uniqueness by store and backfill counters.

Revision ID: 019
Revises: 018
Create Date: 2026-05-12
"""

from __future__ import annotations

import re
from collections.abc import Sequence
from uuid import UUID

import sqlalchemy as sa
from alembic import op

revision: str = "019"
down_revision: str | None = "018"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_INVOICE_RE = re.compile(r"^INV-(\d{4})-(\d+)$")


def _to_uuid(value: object) -> UUID | None:
    if isinstance(value, UUID):
        return value
    if isinstance(value, str):
        try:
            return UUID(value)
        except ValueError:
            return None
    return None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    indexes = {idx["name"] for idx in inspector.get_indexes("receivables")}

    if "ix_receivables_invoice_number" in indexes:
        op.drop_index("ix_receivables_invoice_number", table_name="receivables")

    if "ix_receivables_store_invoice_number" not in indexes:
        op.create_index(
            "ix_receivables_store_invoice_number",
            "receivables",
            ["store_id", "invoice_number"],
            unique=True,
        )

    # Backfill counter values from existing invoice numbers, per store+year.
    rows = bind.execute(
        sa.text(
            """
SELECT store_id, invoice_number
FROM receivables
WHERE invoice_number IS NOT NULL
"""
        )
    ).fetchall()
    max_suffix_by_key: dict[tuple[UUID, int], int] = {}
    for store_id_raw, invoice_number_raw in rows:
        store_id = _to_uuid(store_id_raw)
        if store_id is None or not isinstance(invoice_number_raw, str):
            continue
        match = _INVOICE_RE.match(invoice_number_raw.strip())
        if match is None:
            continue
        year = int(match.group(1))
        suffix = int(match.group(2))
        key = (store_id, year)
        max_suffix_by_key[key] = max(max_suffix_by_key.get(key, 0), suffix)

    for (store_id, year), max_suffix in max_suffix_by_key.items():
        next_number = max_suffix + 1
        bind.execute(
            sa.text(
                """
INSERT INTO receivable_invoice_counters (store_id, year, next_number)
VALUES (:store_id, :year, :next_number)
ON CONFLICT (store_id, year)
DO UPDATE SET next_number = GREATEST(receivable_invoice_counters.next_number, :next_number)
"""
            ),
            {
                "store_id": str(store_id),
                "year": year,
                "next_number": next_number,
            },
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    indexes = {idx["name"] for idx in inspector.get_indexes("receivables")}
    if "ix_receivables_store_invoice_number" in indexes:
        op.drop_index("ix_receivables_store_invoice_number", table_name="receivables")
    if "ix_receivables_invoice_number" not in indexes:
        op.create_index(
            "ix_receivables_invoice_number",
            "receivables",
            ["invoice_number"],
            unique=True,
        )

