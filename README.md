# SikaBoafo

SikaBoafo is a mobile-first, offline-first financial inventory system for micro and small businesses. It helps merchants record sales, manage inventory, track expenses, manage debts, understand profit, and grow into digital payment collection.

## Product idea

This is not just a bookkeeping app.

SikaBoafo is a **merchant operating system** for daily business control.

Core value:

- record sales quickly
- track stock reliably
- manage customer debts
- understand daily performance
- continue working even without internet
- prepare for digital payments and future finance

---

## Current documentation

- `project_description.md`
- `architecture.md`
- `folderstructure.md`
- `todo.md`

UI reference asset:

- `docs/mockups/sikaboafo_mockups_v1.png`

**Documentation terms:** **Payment stages** (1–3) describe the Paystack rollout. **Product milestones** (M2–M5) in `project_description.md` describe broader feature waves—do not mix those numbers with payment stages.

---

## Recommended stack

### Mobile

- Flutter
- Riverpod
- GoRouter
- Dio
- SQLite

### Backend

- FastAPI
- SQLAlchemy 2.x
- Alembic
- PostgreSQL
- Redis
- Celery or Dramatiq

### Admin

- Next.js
- TypeScript

### Infra

- AWS
- S3
- RDS PostgreSQL
- Managed Redis

### Payments

- **Paystack** is the digital payment provider for collection, webhooks, and (later) QR and reconciliation features supported by Paystack in Ghana.

---

## Project structure (high level)

Repository root (e.g. this repo):

```text
./
  mobile/
  backend/
  admin/
  docs/
  scripts/
  infra/
```

See `folderstructure.md` for the complete startup-ready structure.

---

## If you are starting the project now

Do **not** rush ahead of the data model. The point of going step by step is to keep **schemas, sync fields, and boundaries** correct so you do not rewrite piles of code later.

**First work (in order):**

1. **Repo and docs** — Finish `todo.md` §0–§3: root layout per `folderstructure.md`, `.gitignore`, formatting/lint config, `docs/mockups/`, optional `docs/product/` and `docs/architecture/` stubs.
2. **Backend skeleton** — `todo.md` §4.1–§4.2: FastAPI app, config, health route, versioned API shell (no business logic dump in routers).
3. **Data model first** — Before most endpoints: SQLAlchemy models and **Alembic migrations** for core tables (users, merchants, stores, then items/inventory, sales, expenses, customers/receivables as you add modules). Include **sync/idempotency columns** (`device_id`, `local_operation_id`, etc.) on every syncable entity from the start (`architecture.md` §7.3, §8).
4. **Seed and verify** — `seed_dev.py`, run migrations, prove DB shape with real inserts.
5. **Mobile shell** — `todo.md` §5: Flutter app, env, Riverpod, GoRouter, Dio, theme; **sketch SQLite tables** to match server-shaped entities + sync queue before heavy UI.
6. **Connect and auth** — API client, tokens, then auth + onboarding (`todo.md` §6–§7).
7. **MVP modules in order** — Inventory → Sales → Expenses → Debts → Dashboard/Reports (`todo.md` §8–§12), with **local-first + sync queue** wired as you go (`todo.md` §13).
8. **Harden sync** — Idempotency, retries, conflict handling per `architecture.md` §8.3.
9. **Admin and Paystack** — When MVP capture is solid: internal admin, then payment stage 2 (`todo.md` §14–§15, §21).

**Code quality:** Follow **`architecture.md` §4.6–§4.8** (data-first, efficient boundaries, purposeful comments). The goal is maintainable, boring-in-a-good-way code—not the smallest possible first draft.

---

## How to start the project (summary)

1. Repository structure, tooling, and docs (`todo.md` §0–§3).
2. Backend foundation **with migrations driven by a deliberate schema** (`todo.md` §4).
3. Seed data and local verification.
4. Mobile app shell **with SQLite/sync design aligned to the server model** (`todo.md` §5).
5. Connect mobile to backend; implement offline storage and sync (`todo.md` §13).
6. Build MVP modules one by one (`todo.md` §8–§12).

---

## Backend startup guide

### 1. Create backend folder and environment

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
```

On Windows PowerShell:

```powershell
.venv\Scripts\Activate.ps1
```

### 2. Install dependencies

```bash
pip install -r requirements.txt
```

### 3. Create environment file

Create `.env` with required variables such as:

```env
APP_ENV=local
DATABASE_URL=postgresql+psycopg://postgres:postgres@localhost:5432/biztrack
REDIS_URL=redis://localhost:6379/0
SECRET_KEY=change-me
PAYSTACK_SECRET_KEY=change-me-later
PAYSTACK_PUBLIC_KEY=change-me-later
```

### 4. Run database migrations

```bash
alembic upgrade head
```

### 5. Seed local development data

```bash
python scripts/seed_dev.py
```

### 6. Start backend API

```bash
uvicorn app.main:app --reload
```

### 7. Start worker process

Example if using Celery:

```bash
celery -A app.workers.celery_app worker --loglevel=info
```

---

## Mobile startup guide

### 1. Create Flutter app or enter mobile folder

```bash
cd mobile
flutter pub get
```

### 2. Run code generation if used later

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Start app

```bash
flutter run
```

### 4. Recommended early setup tasks

- configure app flavors/environments
- configure Riverpod
- configure routing
- configure Dio API client
- configure SQLite local database
- configure secure token storage

---

## Local development services

Recommended local stack:

- PostgreSQL
- Redis
- FastAPI app
- worker process
- Flutter app

Optional:

- Docker Compose for backend infrastructure (`infra/docker/docker-compose.local.yml`)

---

## Reliability Verification Runbook (MVP Gate)

Use this before merging major changes to auth, sync, sales/expenses/debts, or reports.

### 1) Mobile reliability tests

From `mobile/`:

```bash
flutter test \
  test/core/services/api_client_test.dart \
  test/data/sync/sync_queue_runner_test.dart \
  test/features/local_first_repositories_test.dart
```

Expected result: all tests pass.

What this verifies:

- session-expiry handling (401 -> clear session -> redirect)
- sync queue status transitions (applied/duplicate/failed/conflict)
- local-first writes for expenses, sales/inventory, and debts

### 2) Backend sync/report consistency tests

From `backend/` (venv active):

```powershell
python -m pytest \
  app/tests/test_sync_report_consistency.py \
  app/tests/test_reports_summary.py \
  app/tests/test_sales_sync.py \
  app/tests/test_expenses_sync.py \
  app/tests/test_inventory_sync.py \
  app/tests/test_receivables_sync.py -q
```

Expected result: all tests pass.

What this verifies:

- duplicate sync replay does not duplicate business records
- replayed sync operations do not inflate dashboard/report totals
- inventory and debt conflict paths are handled safely

### 3) Device connectivity check (Android phone)

If testing on physical Android under restricted Wi-Fi, use USB reverse.
See `docs/development/MOBILE_BACKEND_DEBUGGING.md` and `USB_REVERSE_QUICK_START.md`.

### 4) Recovery flow when auth/sync looks stuck

1. Confirm backend is running and health endpoint returns OK.
2. Confirm phone tunnel/network path is active (USB reverse or LAN path).
3. Trigger a protected endpoint from app UI.
4. If token is stale, app should auto-redirect to auth with session-expired message.
5. Sign in again and re-check dashboard + recent activity.

If step 4 fails, re-run the mobile reliability tests above before shipping.

---

## MVP feature list

- phone number + **PIN** sign-in (SMS OTP only for signup / Forgot PIN — see `docs/auth/pin-and-otp-flow.md`)
- merchant onboarding
- dashboard
- record sale
- record expense
- inventory management
- debt tracking
- daily / weekly / monthly summaries
- offline save and sync foundation

---

## Payment rollout plan (Paystack)

Digital money movement is implemented **only through Paystack** (API, redirects/checkout as applicable, and **verified webhooks**). The app never treats a payment as final until the backend confirms it via Paystack.

### Stage 1

Record payment method labels only (cash, mobile money, bank transfer). No live Paystack charge.

### Stage 2

**Paystack live collection:** initiate Paystack transactions from the app, customer pays via Paystack-supported channels, backend confirms via Paystack webhooks and updates `payments` / linked sale or receivable.

### Stage 3

**Deep operations:** receipts, reconciliation, refunds where supported, Paystack-backed QR or other flows available in the stack, settlement visibility, future finance hooks.

---

## Offline-first explanation

Offline mode is for business continuity.

The app should still allow:

- recording a cash sale
- recording an expense
- updating stock
- creating a debt
- viewing recent business data

even when internet is weak.

When internet returns, the app syncs queued operations to the backend.

---

## Design and UI workflow

The generated mockups are part of the source of truth for implementation direction.

Use the mockup asset in `docs/mockups/` as the initial visual reference while refining the design system and screen specs.

---

## Development approach

The best **feature** order after the backend shell and data model exist:

- auth
- merchant/store setup
- inventory
- sales
- expenses
- debts
- dashboard
- reports
- offline sync hardening
- Paystack integration (payment stage 2+)

Keep **routers thin**, **services explicit**, and **types/schemas** at system edges so data structures stay the single source of truth for behavior.

---

## Status

Active development (2026-04-24): M1-M3 delivered and stabilized; M4 Paystack integration is in progress (Step 1 connection settings, Step 2 receivable payment-link initiation, and Step 3 webhook verification/settlement with idempotency hardening completed).
