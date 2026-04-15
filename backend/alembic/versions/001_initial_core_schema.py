"""Initial core schema (all tables from SQLAlchemy models).

Revision ID: 001
Revises:
Create Date: 2026-04-14

For the first revision we use ``create_all`` so the database always matches
``app.models`` without hand-maintaining hundreds of lines. Later migrations
should use autogenerate or explicit ``op.*`` ops.

Requires: PostgreSQL (JSONB, UUID native types).
"""

from collections.abc import Sequence

# Registers models on Base.metadata
import app.models  # noqa: F401, E402
from alembic import op
from app.db.base import Base

revision: str = "001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    bind = op.get_bind()
    Base.metadata.create_all(bind=bind)


def downgrade() -> None:
    """Dev-only rollback: drops every ORM table. Do not run against production data lightly."""
    bind = op.get_bind()
    Base.metadata.drop_all(bind=bind)
