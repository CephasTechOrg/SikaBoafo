# Production deploy checklist (OPS-01)

Use this before pointing real merchants at **Render** (or any production host). Items marked **(boot)** are enforced when the API starts with `APP_ENV=production` — still confirm they are set correctly in the dashboard.

## 1. Environment variables (Render → Environment)

| Variable | Required | Notes |
|----------|----------|--------|
| `APP_ENV` | Yes | `production` |
| `SECRET_KEY` | Yes | Long random string; not `change-me-in-production` **(boot)** |
| `AUTH_MOCK_OTP_CODE` | Yes | **Unset or empty** **(boot)** |
| `PAYMENT_CONFIG_ENCRYPTION_KEY` | Yes | Valid Fernet key (see below) **(boot)** |
| `DATABASE_URL` | Yes | Postgres connection string |
| `ARKESEL_API_KEY` | Yes | Live SMS for OTP |
| `PAYSTACK_SECRET_KEY_LIVE` | Yes | Live secret; test key must not be the only key in prod |
| `PAYSTACK_SECRET_KEY_TEST` | Optional | Omit on prod unless you need test-mode QA |
| `CORS_ORIGINS` | If web clients | Comma-separated origins; avoid `*` in production |
| `SYNC_APPLY_MAX_PER_WINDOW` | Optional | Default OK; tune if merchants hit 429 |
| `SYNC_APPLY_WINDOW_MINUTES` | Optional | Default OK |

### Generate `PAYMENT_CONFIG_ENCRYPTION_KEY`

```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

Store the value in Render; **never** commit it to git.

## 2. Database migrations

On deploy (or one-off job), run:

```bash
cd backend
alembic upgrade head
```

Recent migrations to confirm (020–024):

- `020` — `pin_login_lockouts`
- `021` — `otp_send_throttles`
- `022` — `users.session_version` (refresh rotation / logout)
- `023` — `sync_apply_throttles`
- `024` — `updated_at` on items/customers/receivables (SYNC-01 incremental pull)

## 3. Pre-deploy local check (optional)

From repo root, with production-like env loaded (e.g. Render env export or `.env`):

```bash
cd backend
python scripts/check_deploy_env.py
```

Exit code `0` = automated checks passed. Warnings list manual dashboard items.

## 4. Post-deploy smoke tests

1. **Health**

   ```bash
   curl -sS https://YOUR-API.onrender.com/health
   ```

   Expect: `{"status":"ok"}`

2. **Auth** — OTP request returns 200 (not 500); no mock OTP in prod.

3. **Paystack** — Owner connects Paystack in app; initiate a **test** receivable payment in test mode if available.

4. **Mobile** — Build with production API URL:

   ```bash
   cd mobile
   flutter run --dart-define-from-file=.env.render.json
   ```

5. **Debt payment (DEBT-01 manual QA)** — Generate QR/link → pay (or simulate webhook) → sheet leaves “Waiting for payment” within ~10s on slow network.

## 5. Sign-off

- [x] All env vars in §1 set on Render
- [x] `alembic upgrade head` applied on production DB
- [x] `/health` returns ok
- [x] OTP SMS works (Arkesel)
- [x] Paystack connect + one test collection
- [x] Mobile app points at production API

---

*Tracked as **OPS-01** in [CODEBASE_AUDIT.md](../audits/CODEBASE_AUDIT.md).*
