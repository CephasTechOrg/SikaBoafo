"""Engine and session factory (sync — matches Alembic + psycopg).

Engine/session are created lazily so importing FastAPI routers in tests does not
require an installed PostgreSQL driver unless a DB session is actually opened.
"""

from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import get_settings
from app.db.base import Base

_engine: Engine | None = None
_session_local: sessionmaker[Session] | None = None


def get_engine() -> Engine:
    global _engine
    if _engine is None:
        settings = get_settings()
        _engine = create_engine(
            settings.database_url,
            pool_pre_ping=True,
            echo=settings.app_env == "local",
        )
    return _engine


def get_session_local() -> sessionmaker[Session]:
    global _session_local
    if _session_local is None:
        _session_local = sessionmaker(
            autocommit=False,
            autoflush=False,
            bind=get_engine(),
        )
    return _session_local


def get_db() -> Generator[Session, None, None]:
    db = get_session_local()()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    """Create all tables from ORM metadata (e.g. integration tests). Production uses Alembic."""
    import app.models  # noqa: F401 — registers tables on Base.metadata

    Base.metadata.create_all(bind=get_engine())
