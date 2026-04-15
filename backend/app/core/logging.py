"""Logging bootstrap.

Uses stdlib ``logging`` only for now; swap or wrap with structlog later if you need
JSON logs in production without blocking MVP.
"""

import logging
import sys


def configure_logging(app_env: str) -> None:
    level = logging.DEBUG if app_env == "local" else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
        stream=sys.stdout,
    )
