"""Declarative base: all ORM models inherit ``Base`` so Alembic sees one ``metadata`` object."""

from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    """SQLAlchemy 2.x declarative base for SikaBoafo."""

    pass
