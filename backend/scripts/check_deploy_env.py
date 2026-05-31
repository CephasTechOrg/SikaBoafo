#!/usr/bin/env python3
"""OPS-01: Validate production/staging environment before deploy.

Runs the same boot-time safety checks as the API plus advisory warnings for
items that must be confirmed in the host dashboard (Arkesel, Paystack live key).

Usage:
  cd backend
  APP_ENV=production SECRET_KEY=... python scripts/check_deploy_env.py

Exit 0 = pass, 1 = blocking misconfiguration.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.config import get_settings
from app.core.startup_checks import ProductionConfigError, validate_settings_or_raise


def _warn(msg: str) -> None:
    print(f"  WARN  {msg}")


def _ok(msg: str) -> None:
    print(f"  OK    {msg}")


def main() -> int:
    settings = get_settings()
    env = settings.app_env.strip().lower()
    print(f"Checking deploy env (APP_ENV={env!r})…\n")

    try:
        validate_settings_or_raise(settings)
        _ok("Boot safety checks (SECRET_KEY, mock OTP, encryption key)")
    except ProductionConfigError as exc:
        print(f"  FAIL  {exc}")
        return 1

    if not (settings.database_url or "").strip():
        print("  FAIL  DATABASE_URL is empty.")
        return 1
    _ok("DATABASE_URL is set")

    if env == "production":
        if not (settings.arkesel_api_key or "").strip():
            _warn("ARKESEL_API_KEY is empty — OTP SMS will not work.")
        else:
            _ok("ARKESEL_API_KEY is set")

        live = (settings.paystack_secret_key_live or "").strip()
        if not live:
            _warn(
                "PAYSTACK_SECRET_KEY_LIVE is empty — live MoMo/card collections "
                "need merchant keys or this fallback."
            )
        else:
            _ok("PAYSTACK_SECRET_KEY_LIVE is set")

        cors = settings.cors_origins.strip()
        if cors == "*":
            print("  FAIL  CORS_ORIGINS is '*' — boot check rejects this in production.")
            return 1
        if cors:
            _ok(f"CORS_ORIGINS configured ({len(settings.cors_origin_list)} origin(s))")
        else:
            _ok("CORS_ORIGINS empty — mobile-only API (no browser CORS)")

    print("\nManual steps (cannot verify from env alone):")
    print("  • Run: alembic upgrade head  (migrations through 024)")
    print('  • curl https://<host>/health  → {"status":"ok"}')
    print("  • See docs/operations/PRODUCTION_DEPLOY_CHECKLIST.md")
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
