# BizTrackGh — Local Development Setup

Everything a new developer needs to get the full stack running on their laptop from scratch. Follow each section in order and you will hit zero surprises.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Clone the Repository](#2-clone-the-repository)
3. [Start Local Infrastructure (PostgreSQL + Redis)](#3-start-local-infrastructure)
4. [Backend Setup](#4-backend-setup)
5. [Mobile Setup](#5-mobile-setup)
6. [Connect Mobile to Backend](#6-connect-mobile-to-backend)
7. [Running Tests](#7-running-tests)
8. [Code Quality](#8-code-quality)
9. [Environment Variable Reference](#9-environment-variable-reference)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Prerequisites

Install all of these before you start. Versions listed are the minimum tested.

| Tool | Version | Download |
|------|---------|----------|
| **Python** | 3.12+ | https://www.python.org/downloads/ |
| **Flutter SDK** | 3.5+ | https://docs.flutter.dev/get-started/install |
| **Docker Desktop** | Any recent | https://www.docker.com/products/docker-desktop/ |
| **Git** | Any | https://git-scm.com/ |
| **Android Studio** | Any | https://developer.android.com/studio (needed for ADB and emulator) |

**Windows-only:** After installing Flutter, run `flutter doctor` in PowerShell and fix everything it reports (Android toolchain, SDK licenses, etc.).

```powershell
flutter doctor
```

All items should show a green checkmark before continuing.

---

## 2. Clone the Repository

```bash
git clone <repo-url>
cd BizTrackGh
```

The repository has this top-level structure:

```
BizTrackGh/
├── backend/        # FastAPI Python backend
├── mobile/         # Flutter app
├── infra/          # Docker Compose and deployment config
├── docs/           # Architecture, auth flows, debugging guides
└── render.yaml     # Render deployment blueprint
```

---

## 3. Start Local Infrastructure

The backend needs PostgreSQL 16 and Redis 7. The easiest way is Docker Compose — it starts both with one command.

```bash
docker compose -f infra/docker/docker-compose.local.yml up -d
```

This starts:
- **PostgreSQL 16** on `localhost:5432` — user `postgres`, password `postgres`, database `biztrack`
- **Redis 7** on `localhost:6379`

Verify both are running:

```bash
docker compose -f infra/docker/docker-compose.local.yml ps
```

Both services should show `running` or `healthy`.

> **No Docker?** Install PostgreSQL and Redis manually, then create a database named `biztrack` with user `postgres` / password `postgres`.

---

## 4. Backend Setup

All commands in this section run from the `backend/` directory.

### 4.1 Create Python Virtual Environment

**macOS / Linux:**
```bash
cd backend
python3.12 -m venv .venv
source .venv/bin/activate
```

**Windows (PowerShell):**
```powershell
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1
```

You will see `(.venv)` in your prompt. Keep this active for all backend commands.

### 4.2 Install Dependencies

```bash
pip install -r requirements.txt
pip install -r requirements-dev.txt
```

### 4.3 Configure the Environment File

Copy the example file:

```bash
cp .env.example .env
```

Open `.env` and fill in the required values. Here is a working local development config:

```env
# ── App ───────────────────────────────────────────────────────
APP_ENV=local

# ── Database ──────────────────────────────────────────────────
DATABASE_URL=postgresql+psycopg://postgres:postgres@localhost:5432/biztrack

# ── Redis ─────────────────────────────────────────────────────
REDIS_URL=redis://localhost:6379/0

# ── Auth ──────────────────────────────────────────────────────
SECRET_KEY=any-string-at-least-16-chars-here
AUTH_MOCK_OTP_CODE=123456

# ── CORS ──────────────────────────────────────────────────────
CORS_ORIGINS=*

# ── Arkesel SMS (skip for local — mock OTP above handles it) ──
ARKESEL_API_KEY=
ARKESEL_SENDER_ID=BizTrack
ARKESEL_OTP_EXPIRY_MINUTES=5

# ── Paystack (leave blank until you are testing payments) ─────
PAYSTACK_API_BASE_URL=https://api.paystack.co
PAYSTACK_SECRET_KEY_TEST=
PAYSTACK_SECRET_KEY_LIVE=
PAYSTACK_HTTP_TIMEOUT_SECONDS=15

# ── Payment encryption key (REQUIRED to save Paystack credentials) ──
PAYMENT_CONFIG_ENCRYPTION_KEY=
```

**Generate the encryption key** (run this once and paste the output into `.env`):

```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

The `PAYMENT_CONFIG_ENCRYPTION_KEY` must be a valid Fernet key. If it is missing or wrong, the backend will refuse to start.

**Generate a strong `SECRET_KEY`** for production or staging:

```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

### 4.4 Run Database Migrations

```bash
alembic upgrade head
```

This creates all tables. You should see output like:
```
INFO  [alembic.runtime.migration] Running upgrade -> 001_initial, initial schema
```

### 4.5 Seed Development Data (Optional)

Creates a sample merchant, store, and inventory items so you have data to work with immediately:

```bash
python scripts/seed_dev.py
```

### 4.6 Start the Backend

```bash
uvicorn app.main:app --reload
```

The API is now running at `http://127.0.0.1:8000`.

Verify it is alive:

```bash
curl http://127.0.0.1:8000/health
# or open in browser:
# http://127.0.0.1:8000/docs
```

The `/docs` page gives you the full interactive API documentation.

---

## 5. Mobile Setup

All commands in this section run from the `mobile/` directory.

### 5.1 Install Flutter Dependencies

```bash
cd mobile
flutter pub get
```

### 5.2 Understand the API Base URL

The app reads its backend URL at **compile time** from a `--dart-define` flag. The default values are:

| Build type | Default URL |
|-----------|------------|
| Debug | `http://127.0.0.1:8000` |
| Release | `https://biztrackgh-api.onrender.com` |

This is configured in [mobile/lib/app/env/app_config.dart](mobile/lib/app/env/app_config.dart):

```dart
static const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: _isReleaseBuild
      ? 'https://biztrackgh-api.onrender.com'
      : 'http://127.0.0.1:8000',
);
```

You override this with `--dart-define=API_BASE_URL=<your-url>` at run time.

### 5.3 Run on an Android Emulator

Start an emulator from Android Studio (AVD Manager), then:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

`10.0.2.2` is the emulator's alias for your computer's localhost. Do **not** use `127.0.0.1` here — that resolves to the emulator itself, not your machine.

### 5.4 Run on a Physical Android Device (Same Wi-Fi)

Find your machine's local IP address:

**Windows:**
```powershell
ipconfig
# Look for IPv4 Address under your Wi-Fi adapter, e.g. 192.168.1.42
```

**macOS / Linux:**
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

Then run:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.42:8000
```

Replace `192.168.1.42` with your actual IP.

> **This only works if your phone and laptop are on the same Wi-Fi network.** School/office Wi-Fi often blocks device-to-device traffic. Use USB instead (see section 6).

### 5.5 Run Against Production Backend

```bash
flutter run --dart-define=API_BASE_URL=https://biztrackgh-api.onrender.com
```

Or simply use `flutter run --release` — the release default is the production URL.

### 5.6 Run on iOS Simulator (macOS Only)

```bash
open -a Simulator
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

iOS simulator uses the host machine's network directly, so `127.0.0.1` works fine.

---

## 6. Connect Mobile to Backend

### Option A — USB Reverse Forwarding (Recommended)

This is the most reliable method. It works on any network including restricted school/office Wi-Fi. The phone's port 8000 is tunneled over the USB cable directly to your computer's port 8000.

**Step 1 — Enable USB debugging on your phone:**
Settings → About Phone → tap Build Number 7 times → Developer Options → enable USB Debugging.

**Step 2 — Connect phone via USB and confirm ADB sees it:**

```powershell
# Windows (full path if adb is not in PATH):
C:\Users\<YourName>\AppData\Local\Android\Sdk\platform-tools\adb devices
```

You should see your device listed. If it shows `unauthorized`, unlock your phone and tap "Allow" on the popup.

**Step 3 — Create the tunnel:**

```bash
adb reverse tcp:8000 tcp:8000
```

Run this once per session. The tunnel stays alive until you unplug the cable or reboot.

**Step 4 — Run the app (no `--dart-define` needed, default `127.0.0.1:8000` works):**

```bash
cd mobile
flutter run
```

The phone will now route all `http://127.0.0.1:8000` requests through the USB cable to your backend.

**Verify it works:**
- Tap "Request OTP" in the app
- You should see a log line in the backend terminal: `POST /api/v1/auth/otp/request HTTP/1.1" 200 OK`
- The mock OTP code is `123456` (set in `.env` via `AUTH_MOCK_OTP_CODE`)

### Option B — ngrok (Works Anywhere, Public URL)

If you cannot use USB, ngrok creates a public HTTPS tunnel to your local backend.

**Install ngrok:** https://ngrok.com/download

```bash
ngrok http 8000
```

ngrok prints a URL like `https://abc123.ngrok-free.app`. Use that as your API base:

```bash
flutter run --dart-define=API_BASE_URL=https://abc123.ngrok-free.app
```

> The ngrok URL changes every time you restart. Free plan has usage limits. Do not share the URL publicly.

### Option C — Render (Production / Staging)

Push your branch to GitHub. Render auto-deploys from `main`. After deploy (2–3 minutes):

```bash
flutter run --dart-define=API_BASE_URL=https://biztrackgh-api.onrender.com
```

---

## 7. Running Tests

### Backend Tests

From `backend/` with the virtual environment active:

```bash
pytest app/tests -q
```

To run a specific file:

```bash
pytest app/tests/test_payment_settings.py -q
```

All 92 tests should pass. The test suite uses an in-memory SQLite database — no running PostgreSQL required.

**Full reliability gate** (run before merging major changes):

```bash
python -m pytest \
  app/tests/test_sync_report_consistency.py \
  app/tests/test_reports_summary.py \
  app/tests/test_sales_sync.py \
  app/tests/test_expenses_sync.py \
  app/tests/test_inventory_sync.py \
  app/tests/test_receivables_sync.py -q
```

### Mobile Tests

From `mobile/`:

```bash
flutter test test/core/services/api_client_test.dart
flutter test test/data/sync/sync_queue_runner_test.dart
flutter test test/features/local_first_repositories_test.dart
```

---

## 8. Code Quality

### Backend — Ruff

```bash
cd backend
ruff check app scripts alembic      # lint
ruff format app scripts alembic     # format
```

### Mobile — Dart

```bash
cd mobile
dart format lib test                # format
flutter analyze                     # lint
```

Fix all analyzer warnings before opening a pull request.

---

## 9. Environment Variable Reference

Full list of every variable the backend reads, what it does, and whether it is required.

| Variable | Required | Description |
|----------|---------|-------------|
| `APP_ENV` | Yes | `local` / `staging` / `production` |
| `DATABASE_URL` | Yes | PostgreSQL connection string. Use `postgresql+psycopg://user:pass@host:port/dbname` |
| `REDIS_URL` | No | Redis URL for background workers (not active yet) |
| `SECRET_KEY` | Yes | JWT signing key — min 16 chars. Generate with `secrets.token_hex(32)` |
| `AUTH_TOKEN_ISSUER` | No | JWT issuer claim (default: `biztrack-gh`) |
| `AUTH_ACCESS_TOKEN_EXP_MINUTES` | No | Access token lifetime in minutes (default: 60) |
| `AUTH_REFRESH_TOKEN_EXP_MINUTES` | No | Refresh token lifetime in minutes (default: 10080 = 7 days) |
| `AUTH_MOCK_OTP_CODE` | No | **Dev only.** Fixed OTP code that bypasses SMS — set to `123456` locally. Remove in production. |
| `CORS_ORIGINS` | No | Comma-separated allowed origins, or `*` for dev |
| `ARKESEL_BASE_URL` | No | Arkesel SMS API base (default: `https://sms.arkesel.com`) |
| `ARKESEL_API_KEY` | No | Arkesel API key. Not needed locally if `AUTH_MOCK_OTP_CODE` is set |
| `ARKESEL_SENDER_ID` | No | SMS sender name (default: `BizTrack`) |
| `ARKESEL_OTP_EXPIRY_MINUTES` | No | OTP validity window (default: 5) |
| `ARKESEL_OTP_LENGTH` | No | OTP digit count (default: 6) |
| `ARKESEL_OTP_TYPE` | No | `numeric` or `alphanumeric` (default: `numeric`) |
| `PAYSTACK_API_BASE_URL` | No | Paystack API URL (default: `https://api.paystack.co`) |
| `PAYSTACK_SECRET_KEY_TEST` | No | Platform-level Paystack test key (optional — merchants use their own keys) |
| `PAYSTACK_SECRET_KEY_LIVE` | No | Platform-level Paystack live key |
| `PAYSTACK_HTTP_TIMEOUT_SECONDS` | No | HTTP timeout for Paystack calls (default: 15) |
| `PAYMENT_CONFIG_ENCRYPTION_KEY` | Yes* | Fernet key for merchant Paystack credential encryption. *Required if merchants save Paystack credentials. Generate with `Fernet.generate_key()` |

---

## 10. Troubleshooting

### Backend won't start — "PAYMENT_CONFIG_ENCRYPTION_KEY is invalid"

Generate a fresh Fernet key and paste it into `.env`:

```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

### Backend won't start — "could not connect to server"

PostgreSQL is not running. Start it:

```bash
docker compose -f infra/docker/docker-compose.local.yml up -d
```

### `alembic upgrade head` fails — "table already exists"

The database has partial state. Drop and recreate it:

```bash
# Connect to PostgreSQL and run:
# DROP DATABASE biztrack; CREATE DATABASE biztrack;
# Then rerun:
alembic upgrade head
```

### Flutter app cannot reach the backend

Work through this checklist:

1. **Backend is running?** — Open `http://127.0.0.1:8000/health` in your browser. Should return `{"status": "ok"}`.
2. **Using correct URL for your test method?**
   - Emulator → `http://10.0.2.2:8000`
   - USB reverse → `http://127.0.0.1:8000` (default, no flag needed)
   - Same Wi-Fi → `http://192.168.x.x:8000`
3. **USB tunnel active?** — Run `adb reverse tcp:8000 tcp:8000` again. Unplugging and replugging may clear it.
4. **Hot reload** — Press `r` in the Flutter terminal after changing `--dart-define`. Dart defines are compile-time; hot reload does not pick them up. Do a full restart (`flutter run` again).

### ADB not found

Add the Android SDK platform-tools to your PATH, or use the full path:

**Windows:**
```
C:\Users\<YourName>\AppData\Local\Android\Sdk\platform-tools\adb reverse tcp:8000 tcp:8000
```

**macOS / Linux:**
```
~/Library/Android/sdk/platform-tools/adb reverse tcp:8000 tcp:8000
```

### OTP never arrives (SMS)

In local development, set `AUTH_MOCK_OTP_CODE=123456` in `.env`. The app will accept `123456` as a valid OTP without sending any SMS, even if `ARKESEL_API_KEY` is empty.

### Paystack "Merchant not connected" or 502 on save

- The secret key must start with `sk_test_` (test mode) or `sk_live_` (live mode) and be at least 32 characters long.
- Copy the key directly from your Paystack Dashboard → Settings → API Keys & Webhooks.
- A `pk_` public key in the secret field returns HTTP 400 — that is correct behaviour.
- A 502 means the backend could not verify the key with Paystack's servers. Check your internet connection and try again.

### `flutter pub get` fails with pubspec errors

Make sure your Flutter SDK is 3.5 or newer:

```bash
flutter --version
flutter upgrade
```

### Tests fail with "auth_mock_otp_code" errors

Do not set `AUTH_MOCK_OTP_CODE` in your shell environment when running the backend test suite — the tests set it to `None` explicitly. Only set it in `.env` (which tests do not load).

---

## Quick-Start Summary

Once you have done the full setup once, your daily workflow is three terminals:

**Terminal 1 — Infrastructure (if not already running):**
```bash
docker compose -f infra/docker/docker-compose.local.yml up -d
```

**Terminal 2 — Backend:**
```bash
cd backend
source .venv/bin/activate          # or .venv\Scripts\Activate.ps1 on Windows
uvicorn app.main:app --reload
```

**Terminal 3 — USB tunnel + Flutter:**
```bash
adb reverse tcp:8000 tcp:8000
cd mobile
flutter run
```

Use mock OTP `123456` to log in. All requests from the phone go through the USB cable to your local backend.
