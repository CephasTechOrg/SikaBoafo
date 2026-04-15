# BizTrack GH — Backend (FastAPI)

## Prerequisites

- Python 3.12+
- PostgreSQL 16+ (local or Docker)

## Setup

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt -r requirements-dev.txt
copy .env.example .env
```

Start Postgres (example):

```powershell
docker compose -f ..\infra\docker\docker-compose.local.yml up -d
```

## Migrations

From `backend/` with `PYTHONPATH` set to the current directory (PowerShell: `$env:PYTHONPATH = (Get-Location).Path`):

```powershell
alembic upgrade head
```

Initial revision `001` uses `Base.metadata.create_all` so the DB matches `app.models` (PostgreSQL required).

## Seed

```powershell
python scripts\seed_dev.py
```

## Run API

```powershell
uvicorn app.main:app --reload
```

- Root health: `GET http://127.0.0.1:8000/health`
- Versioned health: `GET http://127.0.0.1:8000/api/v1/health`
- OpenAPI: `http://127.0.0.1:8000/docs`
- OTP request: `POST http://127.0.0.1:8000/api/v1/auth/otp/request`
- OTP verify: `POST http://127.0.0.1:8000/api/v1/auth/otp/verify`
- Onboarding complete: `POST http://127.0.0.1:8000/api/v1/auth/onboarding/complete` (Bearer token required)

## Auth env (OTP)

Set these in `.env`:

- `ARKESEL_API_KEY` (required for live OTP sends)
- `ARKESEL_SENDER_ID` (<= 11 chars)
- `AUTH_MOCK_OTP_CODE` (dev fallback; set empty in production)

Flow:

1. `/auth/otp/request` normalizes phone and sends OTP via Arkesel (or mock code).
2. `/auth/otp/verify` validates code, creates user if needed, returns access/refresh tokens.

## Tests

```powershell
pytest app\tests -q
```

## Layout

- `app/core/` — settings, logging, **domain string constants** (`constants.py` — use these instead of magic strings in services)
- `app/db/` — engine, session, `Base`
- `app/models/` — SQLAlchemy models (sync fields on offline-capable entities); class docstrings note invariants
- `app/api/v1/` — routers (thin handlers; business logic will live in `app/services/` per `architecture.md` §4.7)
- `alembic/` — migrations

## Code quality (team norms)

Aligned with repo root `architecture.md` §4.6–§4.8:

- **Data:** UUID PKs and shared constants in `app/core/constants.py`; sync columns on entities that can originate offline.
- **Comments:** explain *why* and cross-cutting rules (sync, money, Paystack), not obvious line-by-line narration.
- **Layers:** keep routers thin; validate at the API boundary (Pydantic) when you add request bodies.
- **Lint:** `ruff check app scripts alembic` from `backend/`.
