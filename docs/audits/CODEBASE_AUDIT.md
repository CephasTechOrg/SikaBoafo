# SikaBoafo — Codebase Audit & Action Checklists

**Product:** SikaBoafo (BizTrackGh) — offline-first merchant OS for Ghana  
**Stack:** Flutter · FastAPI · PostgreSQL · Paystack  
**Last reviewed:** May 2026  
**Test snapshot:** Backend 157/157 pytest pass · Mobile tests pass

This is the **single audit document** for the repo. Use it to see what is wrong, what was already fixed, and what to tackle next. Older notes (e.g. root `debt_payment_flow_audit.md`) are folded in here; prefer **this file** for planning work.

---

## How to use this document

| Section | Purpose |
|--------|---------|
| **Audits (grouped)** | Each group explains *what is happening*, *why it matters*, and *where in the codebase* |
| **Status** | `open` = not done · `partial` = started or mitigated · `done` = verified fixed · `monitor` = watch in prod |
| **Checklist A — Must fix** | Blockers or high risk before more users / production scale |
| **Checklist B — Should complete** | Important next sprint items |
| **Checklist C — Do better** | Quality, maintainability, and product polish (not emergencies) |

When you fix an item, change its status here and tick the checklist box.

---

## What is working well (keep doing this)

- **Offline-first sync:** Local SQLite → sync queue → `POST /api/v1/sync/apply` with idempotency on `(device_id, local_operation_id)`.
- **Store scoping:** Services resolve merchant/store from `user_id`; receivables/inventory filtered by `store_id` (reduces cross-tenant IDOR).
- **Paystack webhooks:** HMAC signature verification; structured HTTP errors for retry vs reject.
- **Merchant secrets:** Paystack keys encrypted at rest (`PAYMENT_CONFIG_ENCRYPTION_KEY` + Fernet).
- **PIN storage:** Scrypt + per-PIN salt + `secrets.compare_digest`.
- **OTP verification:** Max 5 attempts per code; hashed codes in DB.
- **API client (mobile):** Proactive JWT refresh, single-flight refresh, one 401 retry, session logout.
- **User-facing errors:** `userFriendlyError` maps network/HTTP to calm copy.
- **CI:** Backend ruff + pytest + Docker; mobile analyze + tests.
- **Documentation:** `ghana_sme_os_docs/`, `docs/development/`, auth flow docs.

---

# Audit 1 — Security & authentication

### AUTH-01 · PIN login has no rate limiting

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | — |
| **What was wrong** | Unlimited PIN attempts per phone on `/auth/pin/login`. |
| **Fix applied** | `PinLoginGuard` tracks failures in `pin_login_lockouts` (migration `020`); 5 failures → 15-minute lockout (configurable via `AUTH_PIN_MAX_ATTEMPTS`, `AUTH_PIN_LOCKOUT_MINUTES`); returns HTTP 429. Successful login clears the row. `pin_not_set` does not count toward lockout. |
| **Where** | `backend/app/services/pin_login_guard.py`, `auth_service.py`, `api/v1/auth.py` |

### AUTH-02 · Refresh tokens are not revoked or rotated

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | Medium–High |
| **What's happening** | ~~Refresh returns new tokens but old refresh JWTs stayed valid until expiry.~~ |
| **Why it matters** | Stolen refresh token = long-lived account access even after user “logs out” on device. |
| **Fix applied** | `users.session_version` (migration `022`); JWT `sv` claim; refresh increments version and rejects replayed refresh tokens. |
| **Where** | `backend/app/core/security.py`, `auth_service.py`, `api/deps.py` |

### AUTH-03 · Logout does not invalidate tokens server-side

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | Medium |
| **What's happening** | ~~Mobile `signOut` cleared secure storage only.~~ |
| **Why it matters** | Lost phone or staff dismissal: token usable until expiry unless you add revocation. |
| **Fix applied** | `POST /api/v1/auth/logout` bumps `session_version`; mobile `signOut` calls it before clearing local storage (best-effort if offline). |
| **Where** | `backend/app/api/v1/auth.py`, `mobile/lib/core/services/session_service.dart`, `core_providers.dart` |

### AUTH-04 · Custom JWT implementation

| Field | Value |
|-------|--------|
| **Status** | `open` |
| **Severity** | Medium |
| **What's happening** | HS256 JWT built manually in `security.py` (encode/decode/sign). Works and uses `hmac.compare_digest` for signatures. |
| **Why it matters** | Easier to miss edge cases (alg none, claim validation) than with battle-tested library. |
| **Where** | `backend/app/core/security.py` |
| **Fix** | Migrate to `PyJWT` (or similar) with explicit `algorithms=["HS256"]`, `aud`/`iss` checks. |

### AUTH-05 · Mock OTP bypass in production

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | — |
| **What's happening** | If `AUTH_MOCK_OTP_CODE` is set, any user can verify with that fixed code—no SMS. |
| **Fix applied** | `validate_settings_or_raise()` in app lifespan **refuses to boot** when `APP_ENV=production` and mock OTP is set. Staging still allows mock OTP for QA. |
| **Where** | `backend/app/core/startup_checks.py`, `backend/app/main.py` |

### AUTH-06 · Default `secret_key` in config

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | — |
| **What's happening** | Default `secret_key="change-me-in-production"` in settings. |
| **Fix applied** | Startup check rejects default secret in **production** and **staging**. |
| **Where** | `backend/app/core/config.py`, `backend/app/core/startup_checks.py` |

### AUTH-07 · CORS allows `*` by default

| Field | Value |
|-------|--------|
| **Status** | `open` |
| **Severity** | Medium (when web clients exist) |
| **What's happening** | `cors_origins` defaults to `*` with `allow_credentials=True`. |
| **Why it matters** | Fine for mobile-only MVP; risky if you add a browser admin or web app. |
| **Where** | `backend/app/main.py`, `backend/app/core/config.py` |
| **Fix** | Set explicit origins per environment in Render/env. |

### AUTH-08 · No API-wide rate limiting (sync done — AUTH-08b)

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | Medium |
| **What's happening** | PIN (AUTH-01), OTP request (`OtpSendGuard`, migration `021`), and **`/sync/apply`** (`SyncApplyGuard`, migration `023`, default 120 req / 5 min per user). Payment initiation endpoints are not throttled separately. |
| **Why it matters** | Abuse of auth, sync, and SMS paths is mitigated. |
| **Fix applied** | `sync_apply_guard.py`, `api/v1/sync.py`; mobile `markRetryable` for HTTP 429/503 so rate limits do not burn retry budget. |
| **Where** | `otp_send_guard.py`, `sync_apply_guard.py`, `config.py`, `mobile/lib/data/sync/sync_queue_runner.dart` |

### AUTH-08b · `/sync/apply` rate limiting

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | Medium |
| **Fix applied** | `SyncApplyGuard` + `sync_apply_throttles` table (migration `023`); HTTP 429; env `SYNC_APPLY_MAX_PER_WINDOW`, `SYNC_APPLY_WINDOW_MINUTES`. |

---

# Audit 2 — Payments & Paystack (backend)

### PAY-01 · `PaymentService` is a god module (~2,300 lines)

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | Medium (maintainability) |
| **What's happening** | Exceptions, snapshots, pure helpers, **and Paystack secret/connection resolution** extracted. Orchestration (sale/receivable/webhook flows) remains in `payment_service.py` by design; further flow-level splits are optional. |
| **Why it matters** | Credential plumbing was the densest non-flow code; isolating it makes the orchestrator easier to read. |
| **Fix applied** | `payment_errors.py`, `payment_snapshots.py`, `payment_helpers.py`, `payment_secret_resolver.py` (`PaymentSecretResolverMixin` — `_client`, connection lookup, secret resolution + env fallback); re-exported from `payment_service` for backward-compatible imports. |
| **Where** | `backend/app/services/payment_*.py` |

### PAY-02 · Paystack connection vs initiation permissions

| Field | Value |
|-------|--------|
| **Status** | `monitor` |
| **Severity** | Low–Medium |
| **What's happening** | Connecting Paystack = **owner only**. Initiating payment (sale/debt) = **any authenticated** staff (cashier included). |
| **Why it matters** | May be intentional (cashiers run POS). If not, cashiers should not start digital charges without owner setup. |
| **Where** | `backend/app/api/v1/payments.py` |
| **Fix** | Product decision: document allowed roles; optionally restrict initiation to `manager`+ if needed. |

### PAY-03 · Webhook idempotency and shared verify path

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | — |
| **What's happening** | Webhook handler calls `_apply_paystack_verify_to_receivable_payment` (same family as manual verify). |
| **Where** | `backend/app/services/payment_service.py` (~line 1599) |
| **Fix** | None — keep both paths on shared helper when changing settlement logic. |

---

# Audit 3 — Debt payment flow (Paystack link / QR / MoMo)

*Consolidated from `debt_payment_flow_audit.md` (root). Status re-verified against current code.*

### DEBT-01 · UI stuck on “Waiting for payment” after success

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | High (UX) |
| **What's happening** | Mobile polls `fetchReceivable` then `verifyPayment` when still open (QR sheet + link panel). Backend: `test_webhook_then_verify_receivable_payment_reports_settled_to_client`. Mobile: `debt_paystack_qr_sheet_test.dart` covers webhook-delay (stale fetch → verify settles) and webhook-first (fetch already settled, verify skipped). |
| **Why it matters** | Trust in digital collections; merchants think money was not received. |
| **Where** | `test_paystack_webhooks.py`, `debt_paystack_qr_sheet.dart`, `debt_paystack_qr_sheet_test.dart` |
| **Fix applied** | Widget tests + scroll controller on payment-link `Scrollbar` (testability). Manual QA on slow networks still recommended before prod cutover. |

### DEBT-02 · Payment link not cleared after settlement

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | — |
| **What's happening** | `_apply_receivable_settlement` clears `payment_link` and `payment_provider_reference` when reference matches. |
| **Where** | `backend/app/services/payment_service.py` (~1970, ~2038) |

### DEBT-03 · Cancelled debt mutated by late Paystack payment

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | — |
| **What's happening** | Settlement refuses cancelled receivables; audit event `payment.ignored_cancelled_receivable`. `cancel_receivable` calls `_invalidate_pending_online_payments` (fails pending [Payment] rows, clears cached link/reference). |
| **Where** | `backend/app/services/payment_service.py`, `receivables_service.py` |
| **Fix applied** | Confirmed cancel path; added regression test `test_cancel_receivable_invalidates_pending_paystack_payment` (initiate → cancel → pending payment is `failed` with `failure_reason=receivable_cancelled`, link/reference cleared). |

### DEBT-04 · Cash repayment leaves stale online link

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | — |
| **What's happening** | `record_repayment` calls `_invalidate_pending_online_payments`. |
| **Where** | `backend/app/services/receivables_service.py` |

### DEBT-05 · Panel watcher did not call verify

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | — |
| **What's happening** | `_watchServerPaymentProgress` calls `verifyPayment` when receivable unchanged and `paymentId` present. |
| **Where** | `mobile/lib/features/debts/presentation/widgets/debt_payment_link_panel.dart` |

### DEBT-06 · Partial amount ignored on initiate API

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | — |
| **What's happening** | `PaymentInitiateIn` includes optional `amount`; route passes to service. |
| **Where** | `backend/app/schemas/payment.py`, `backend/app/api/v1/payments.py` |

### DEBT-07 · “Active link” when latest payment is not pending

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | — |
| **What's happening** | `_latest_payment_context_for_receivable` only returns payment context for pending, non-expired payments. |
| **Where** | `backend/app/services/receivables_service.py` (~577+) |

### DEBT-08 · Webhook vs verify settlement divergence

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | — |
| **What's happening** | Webhook uses `_apply_paystack_verify_to_receivable_payment`. |
| **Where** | `backend/app/services/payment_service.py` |

### DEBT-09 · Debt must be synced before online payment

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | Medium |
| **What's happening** | Online Paystack flows expect server-side receivable ID. Offline-created debt must sync first. The panel now **replaces the pay buttons** (Share / Show QR / Push MoMo) with a plain-language notice + "Sync now" CTA whenever the receivable's local row is not `applied`. |
| **Why it matters** | Merchant offline → tries QR → confusing error if sync failed. |
| **Where** | `debt_payment_link_panel.dart`, sync queue |
| **Fix applied** | `_PendingSyncNotice` gates online pay until synced; `_syncNow()` kicks the global queue, confirms the receivable create reached the server, refreshes, and unlocks pay. Lazy `_ensureSyncedForOnlinePayment` retained as a safety net. |

---

# Audit 4 — Offline sync

### SYNC-01 · Push-only sync (no incremental pull protocol)

| Field | Value |
|-------|--------|
| **Status** | `open` |
| **Severity** | Low (MVP OK) |
| **What's happening** | Device pushes operations; server does not stream full change feed. Conflicts trigger **snapshot refresh** (inventory/debts). |
| **Why it matters** | Large catalogs / multi-device: more bandwidth and race windows. |
| **Where** | `mobile/lib/data/sync/`, `backend/app/services/sync_service.py` |
| **Fix** | Cursor-based pull per entity type (P2). |

### SYNC-02 · Conflict resolution is technical, not merchant-guided

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | Medium (UX) |
| **What's happening** | Conflicts mark queue row `conflict` and refresh server snapshot (server-wins). The sync sheet now has a dedicated **"Sync Conflicts"** section, split out from generic failures, with plain-language copy and per-row actions. |
| **Why it matters** | Merchants may not understand `SyncStatusPill` counts. |
| **Where** | `sync_queue_runner.dart`, `sync_status_pill.dart`, `sync_providers.dart`, `sync_queue_repository.dart` |
| **Fix applied** | New `conflictRows()` / `discardConflict()` / `requeueConflict()` repo methods + `conflictEntries` snapshot field + controller `keepServerVersion()` / `retryConflict()`. `_ConflictRow` widget offers "Keep latest" (accept server version, drop local op) and "Try again" (re-queue local change). `failedRows()` now returns only `failed` so conflicts read cleanly. |

### SYNC-03 · Dead-letter queue after max attempts

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | — |
| **What's happening** | After `maxAttempts` (10), rows move to `dead` status. |
| **Where** | `mobile/lib/data/local/sync_queue_repository.dart`, `sync_queue_runner.dart` |
| **Fix** | UI to retry or discard dead ops (Checklist C). |

### SYNC-04 · Sync apply not transactional across batch

| Field | Value |
|-------|--------|
| **Status** | `monitor` |
| **Severity** | Low |
| **What's happening** | Each operation commits separately in loop; partial batch success possible. |
| **Why it matters** | Usually OK with idempotency; odd states if mid-batch failure. |
| **Where** | `backend/app/services/sync_service.py` |
| **Fix** | Document behavior; optional per-batch transaction for related ops. |

---

# Audit 5 — RBAC & staff

### RBAC-01 · Manager / stock_keeper roles not enforced in API

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | Medium |
| **What's happening** | ~~Non-owners were treated uniformly via `get_current_user`.~~ |
| **Why it matters** | Cashiers, managers, and stock keepers now have distinct write permissions. |
| **Fix applied** | `ROLE_PERMISSIONS` matrix in `rbac.py`; `require_permission()` on items/sales/receivables/expenses mutating routes. Owner-only config unchanged (`get_merchant_owner`). Tests for manager, cashier, stock_keeper. |
| **Where** | `backend/app/core/rbac.py`, `api/deps.py`, `api/v1/{items,sales,receivables,expenses}.py`, `test_owner_permissions.py` |

### RBAC-02 · Destructive actions owner-only

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | — |
| **What's happening** | Void sale, cancel debt, delete item, audit logs, merchant profile edit = owner only. Staff tested in `test_owner_permissions.py`. |
| **Where** | `backend/app/api/v1/sales.py`, `receivables.py`, `items.py`, etc. |

### RBAC-03 · Staff can create sales/debts/expenses

| Field | Value |
|-------|--------|
| **Status** | `done` (by design) |
| **Severity** | — |
| **What's happening** | Cashiers use `get_current_user` for daily ops. |
| **Fix** | Document in staff onboarding which roles can do what. |

---

# Audit 6 — Mobile app & tests

### MOB-01 · Failing widget test: dashboard → Debts quick action

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | — |
| **What was wrong** | Routing worked; test failed because `DebtsHeader` overflowed (16px) inside `SliverAppBar` flexible space (~162px tall). |
| **Fix applied** | `debts_header.dart`: `LayoutBuilder` + compact spacing / `FittedBox` when height &lt; 190px; `debts_screen.dart`: `expandedHeight` 230→252; test uses `pumpAndSettle`. |
| **Where** | `mobile/test/features/app_routing_test.dart`, `debts_header.dart`, `debts_screen.dart` |

### MOB-02 · Large payment/debt widgets

| Field | Value |
|-------|--------|
| **Status** | `open` |
| **Severity** | Low |
| **What's happening** | Debt sheets and payment panels are large, multi-state files. |
| **Why it matters** | Harder unit tests and reviews. |
| **Where** | `debt_payment_link_panel.dart`, paystack sheets |
| **Fix** | Extract polling, amount validation, and link state into testable classes. |

### MOB-03 · Silent background errors

| Field | Value |
|-------|--------|
| **Status** | `open` |
| **Severity** | Low |
| **What's happening** | Many `unawaited(refreshFromServer())` / sync runs swallow errors unless user watches sync pill. |
| **Why it matters** | Merchant thinks data is current when refresh failed. |
| **Where** | Debts controller, sync providers |
| **Fix** | Snackbar or badge when background refresh fails. |

### MOB-04 · API base URL and Supabase keys via dart-define

| Field | Value |
|-------|--------|
| **Status** | `monitor` |
| **Severity** | Low |
| **What's happening** | Release defaults to Render API URL; Supabase anon key from `--dart-define`. |
| **Where** | `mobile/lib/app/env/app_config.dart` |
| **Fix** | Document release build flags in `docs/development/SETUP.md`. |

---

# Audit 7 — Backend architecture & data model

### ARCH-01 · Single default store per merchant

| Field | Value |
|-------|--------|
| **Status** | `open` |
| **Severity** | Low (product limit) |
| **What's happening** | `get_merchant_and_store` always uses `Store.is_default == True`. |
| **Why it matters** | Multi-branch shops not supported in API/UX. |
| **Where** | `backend/app/services/store_context.py` |
| **Fix** | Product roadmap: multi-store selector or document single-store only. |

### ARCH-02 · Redis configured but unused

| Field | Value |
|-------|--------|
| **Status** | `open` |
| **Severity** | Low |
| **What's happening** | `redis_url` in settings; no cache, queue, or rate limit wired. |
| **Where** | `backend/app/core/config.py` |
| **Fix** | Use for rate limits + refresh token store, or remove from docs until needed. |

### ARCH-03 · Admin app not implemented

| Field | Value |
|-------|--------|
| **Status** | `open` |
| **Severity** | Low |
| **What's happening** | `admin/` is README stub only. |
| **Fix** | Build internal admin or remove from architecture diagrams until ready. |

### ARCH-04 · Thin routers, fat services (good pattern)

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | — |
| **What's happening** | Routers delegate to services; Pydantic at boundary. Matches `backend/README.md` norms. |

---

# Audit 8 — Operations & production

### OPS-01 · Production environment checklist

| Field | Value |
|-------|--------|
| **Status** | `partial` |
| **Severity** | High |
| **What's happening** | **Automated at boot:** default `SECRET_KEY`, production `AUTH_MOCK_OTP_CODE`, production `PAYMENT_CONFIG_ENCRYPTION_KEY`. **Runbook:** `docs/operations/PRODUCTION_DEPLOY_CHECKLIST.md`. **Pre-flight script:** `backend/scripts/check_deploy_env.py` (same boot checks + env advisories). Manual Render sign-off still required (Arkesel, Paystack live, migrations, smoke tests). |
| **Fix** | Run checklist + script on each production deploy; tick sign-off in runbook. |

### OPS-02 · No structured security headers / HSTS

| Field | Value |
|-------|--------|
| **Status** | `open` |
| **Severity** | Low |
| **What's happening** | FastAPI app does not set security headers middleware. |
| **Fix** | Add middleware or terminate at CDN/load balancer. |

### OPS-03 · Webhook endpoint public by design

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | — |
| **What's happening** | `POST /api/v1/webhooks/paystack` unauthenticated; HMAC is the control. |
| **Where** | `backend/app/api/v1/webhooks.py` |

---

# Audit 9 — Repository hygiene

### REPO-01 · Scratch scripts and stray HTML in root

| Field | Value |
|-------|--------|
| **Status** | `open` |
| **Severity** | Low |
| **What's happening** | `scripts/scratch/`, `index (2).html` at repo root. |
| **Fix** | Move to `scripts/scratch/README` only in dev branches or delete; add to `.gitignore` if local-only. |

### REPO-02 · Duplicate audit doc at root

| Field | Value |
|-------|--------|
| **Status** | `done` |
| **Severity** | — |
| **What's happening** | `debt_payment_flow_audit.md` superseded by this file. |
| **Fix** | Root file points here (see that file’s header). |

---

# Master Checklist A — Must fix (before scaling users)

Use for release gates and security reviews.

- [x] **AUTH-01** — PIN login rate limiting / lockout
- [x] **AUTH-05** — Confirm `AUTH_MOCK_OTP_CODE` unset in production (automated boot check)
- [x] **AUTH-06** — Confirm strong `SECRET_KEY` in production (automated boot check)
- [x] **MOB-01** — Fix failing `app_routing_test` (Debts quick action)
- [ ] **OPS-01** — Run production env checklist on Render (`docs/operations/PRODUCTION_DEPLOY_CHECKLIST.md` + `scripts/check_deploy_env.py`)
- [x] **DEBT-01** — Widget tests: poll-after-verify when fetch stale; fetch-settled skips verify

### Production env checklist (copy into deploy runbook)

Items marked *(boot)* are enforced at API startup in production/staging — still confirm in the Render dashboard.

- [ ] `APP_ENV=production`
- [ ] `SECRET_KEY` — long random value, not default *(boot)*
- [ ] `AUTH_MOCK_OTP_CODE` — **empty / unset** *(boot, production only)*
- [ ] `alembic upgrade head` — migrations `020`–`023` (`pin_login_lockouts`, `otp_send_throttles`, `users.session_version`, `sync_apply_throttles`)
- [ ] `PAYMENT_CONFIG_ENCRYPTION_KEY` — valid Fernet key *(boot, production only)*
- [ ] `ARKESEL_API_KEY` — set for live SMS
- [ ] `PAYSTACK_SECRET_KEY_LIVE` — live key only on production
- [ ] `CORS_ORIGINS` — explicit list (not `*`) if any browser client exists

---

# Master Checklist B — Should complete (next sprint)

- [x] **AUTH-02** — Refresh token rotation + `session_version` on user (migration `022`)
- [x] **AUTH-03** — Server-aware logout (`POST /auth/logout` + mobile signOut)
- [x] **AUTH-08** — Rate limiting on `/auth/otp/request` + `/sync/apply` (AUTH-08b)
- [x] **AUTH-08b** — Rate limiting on `/sync/apply` (migration `023`)
- [x] **RBAC-01** — Role permission matrix + `require_permission` on mutating routes
- [x] **PAY-01** — Split `payment_service.py` (errors/snapshots/helpers + `payment_secret_resolver.py` mixin; orchestration kept by design)
- [x] **DEBT-03** — Test: cancel receivable invalidates pending Paystack payments
- [x] **DEBT-09** — UX: block/disable online pay until debt synced; clear messaging
- [x] **SYNC-02** — Merchant-visible conflict resolution (dedicated "Sync Conflicts" section + keep/retry actions)

---

# Master Checklist C — Do better (quality & growth)

- [ ] **AUTH-04** — Migrate JWT to maintained library (`PyJWT`)
- [ ] **AUTH-07** — Tighten CORS per environment
- [ ] **SYNC-01** — Incremental server pull / sync cursors
- [ ] **SYNC-03** — UI to review/retry **dead** sync queue rows
- [ ] **MOB-02** — Refactor large debt/payment widgets for testability
- [ ] **MOB-03** — Surface background refresh/sync failures to user
- [ ] **ARCH-01** — Multi-store product design (if roadmap requires)
- [ ] **ARCH-02** — Wire Redis for sessions/rate limits or remove from architecture docs
- [ ] **ARCH-03** — Admin console or remove from public architecture
- [ ] **REPO-01** — Clean scratch artifacts from main branch
- [ ] **OPS-02** — Security headers at edge or in FastAPI

---

# Quick reference — Audit ID index

| ID | Title | Status |
|----|--------|--------|
| AUTH-01 | PIN rate limiting | done |
| AUTH-02 | Refresh token revocation | done |
| AUTH-03 | Logout server-side | done |
| AUTH-04 | Custom JWT | open |
| AUTH-05 | Mock OTP in prod | done |
| AUTH-06 | Default secret key | done |
| AUTH-07 | CORS `*` | open |
| AUTH-08 | OTP + sync rate limits | done |
| AUTH-08b | Sync rate limit | done |
| PAY-01 | PaymentService size | done |
| PAY-02 | Paystack role split | monitor |
| PAY-03 | Webhook shared verify | done |
| DEBT-01 | Stuck “waiting” UI | done |
| DEBT-02 | Clear link on settle | done |
| DEBT-03 | Cancelled + Paystack | done |
| DEBT-04 | Cash + stale link | done |
| DEBT-05 | Panel verify poll | done |
| DEBT-06 | Partial amount API | done |
| DEBT-07 | Active link semantics | done |
| DEBT-08 | Webhook/verify parity | done |
| DEBT-09 | Sync before online pay | done |
| SYNC-01 | Push-only sync | open |
| SYNC-02 | Conflict UX | done |
| SYNC-03 | Dead letter queue | done |
| SYNC-04 | Batch transaction | monitor |
| RBAC-01 | Manager role enforcement | done |
| RBAC-02 | Owner destructive ops | done |
| RBAC-03 | Staff daily ops | done |
| MOB-01 | Routing test fail | done |
| MOB-02 | Large widgets | open |
| MOB-03 | Silent refresh errors | open |
| MOB-04 | Build-time config | monitor |
| ARCH-01 | Single store | open |
| ARCH-02 | Redis unused | open |
| ARCH-03 | Admin stub | open |
| ARCH-04 | Thin routers | done |
| OPS-01 | Prod checklist | partial |
| OPS-02 | Security headers | open |
| OPS-03 | Webhook HMAC | done |
| REPO-01 | Scratch files | open |
| REPO-02 | Audit consolidation | done |

---

# Suggested fix order (one path through the audits)

1. ~~**MOB-01** — Green CI~~ ✓ done  
2. ~~**OPS-01 + AUTH-05 + AUTH-06** — Production env hardening (boot checks)~~ ✓ partial — manual Render checklist remains  
3. ~~**AUTH-01** — PIN lockout~~ ✓ done  
4. ~~**DEBT-01** — Poll-after-verify (backend + mobile widget tests)~~ ✓ done  
5. ~~**AUTH-02 + AUTH-03** — Session lifecycle~~ ✓ done  
6. ~~**AUTH-08b** — Sync rate limiting~~ ✓ done  
7. ~~**RBAC-01** — Role matrix~~ ✓ done  
8. ~~**PAY-01** — Payment module split~~ ✓ done (errors/snapshots/helpers + secret-resolver mixin; flow orchestration kept by design)  
9. ~~**DEBT-03** — Cancel invalidates pending Paystack payment (regression test)~~ ✓ done  
10. ~~**DEBT-09** — Block online pay until debt synced + clear messaging~~ ✓ done  
11. ~~**SYNC-02** — Merchant-visible conflict resolution~~ ✓ done  

**Next suggested:** SYNC-01 (incremental pull), MOB-02/MOB-03 (large widgets / silent refresh errors), or OPS-02 (security headers).

---

## Related files

| Path | Notes |
|------|--------|
| `docs/operations/PRODUCTION_DEPLOY_CHECKLIST.md` | OPS-01 deploy runbook |
| `backend/scripts/check_deploy_env.py` | OPS-01 pre-flight env validation |
| `debt_payment_flow_audit.md` (repo root) | Historical debt audit — see header for pointer here |
| `docs/auth/pin-and-otp-flow.md` | Auth flow design |
| `ghana_sme_os_docs/` | Architecture & API contracts |
| `docs/development/SETUP.md` | Local and env setup |

---

*Update this document when an audit item is fixed: change **Status** and tick the matching checklist box.*
