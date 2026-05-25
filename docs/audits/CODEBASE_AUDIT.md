# SikaBoafo — Codebase Audit & Action Checklists

**Product:** SikaBoafo (BizTrackGh) — offline-first merchant OS for Ghana  
**Stack:** Flutter · FastAPI · PostgreSQL · Paystack  
**Last reviewed:** May 2026  
**Test snapshot:** Backend 137/137 pytest pass · Mobile 82/83 tests pass (1 routing test failing)

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
| **Status** | `open` |
| **Severity** | High |
| **What's happening** | `/api/v1/auth/pin/login` accepts unlimited PIN attempts per phone. Only OTP verify has attempt limits (`otp_provider.py`, `_MAX_VERIFY_ATTEMPTS = 5`). |
| **Why it matters** | 4–6 digit PIN = 10,000–1,000,000 combinations. An attacker with network access can brute-force accounts. |
| **Where** | `backend/app/services/auth_service.py`, `backend/app/api/v1/auth.py` |
| **Fix** | Per-phone lockout after N failures (DB or Redis), exponential backoff, optional CAPTCHA; generic error message on failure. |

### AUTH-02 · Refresh tokens are not revoked or rotated

| Field | Value |
|-------|--------|
| **Status** | `open` |
| **Severity** | Medium–High |
| **What's happening** | Refresh returns new access + refresh JWTs, but old refresh tokens remain valid until expiry (~7 days default). No server-side session table or denylist. |
| **Why it matters** | Stolen refresh token = long-lived account access even after user “logs out” on device. |
| **Where** | `backend/app/services/auth_service.py`, `mobile/lib/core/services/api_client.dart` |
| **Fix** | Refresh token rotation (invalidate previous on use); optional `session_version` on `User`; store refresh jti in DB/Redis. |

### AUTH-03 · Logout does not invalidate tokens server-side

| Field | Value |
|-------|--------|
| **Status** | `open` |
| **Severity** | Medium |
| **What's happening** | Mobile `signOut` clears secure storage only. Access token still works until `exp`. |
| **Why it matters** | Lost phone or staff dismissal: token usable until expiry unless you add revocation. |
| **Where** | `mobile/lib/shared/providers/core_providers.dart`, session service |
| **Fix** | Pair with AUTH-02; optional `POST /auth/logout` that bumps session version or blocklists jti. |

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
| **Status** | `monitor` |
| **Severity** | Critical if misconfigured |
| **What's happening** | If `AUTH_MOCK_OTP_CODE` is set, any user can verify with that fixed code—no SMS. |
| **Why it matters** | Full account takeover for any known phone number. |
| **Where** | `backend/app/services/otp_provider.py`, `backend/app/core/config.py` |
| **Fix** | Production deploy checklist: env must have **empty** mock OTP; fail deploy if `app_env=production` and mock is set. |

### AUTH-06 · Default `secret_key` in config

| Field | Value |
|-------|--------|
| **Status** | `monitor` |
| **Severity** | Critical if misconfigured |
| **What's happening** | Default `secret_key="change-me-in-production"` in settings. |
| **Why it matters** | Anyone can forge JWTs if production uses default. |
| **Where** | `backend/app/core/config.py` |
| **Fix** | Require strong key in production startup; refuse to boot if default detected. |

### AUTH-07 · CORS allows `*` by default

| Field | Value |
|-------|--------|
| **Status** | `open` |
| **Severity** | Medium (when web clients exist) |
| **What's happening** | `cors_origins` defaults to `*` with `allow_credentials=True`. |
| **Why it matters** | Fine for mobile-only MVP; risky if you add a browser admin or web app. |
| **Where** | `backend/app/main.py`, `backend/app/core/config.py` |
| **Fix** | Set explicit origins per environment in Render/env. |

### AUTH-08 · No API-wide rate limiting

| Field | Value |
|-------|--------|
| **Status** | `open` |
| **Severity** | Medium |
| **What's happening** | No global throttle on sync, auth, or payment endpoints. `redis_url` exists but is unused. |
| **Why it matters** | Abuse, credential stuffing, sync flooding. |
| **Where** | `backend/app/core/config.py` (redis unused) |
| **Fix** | Redis + middleware or reverse-proxy limits; prioritize `/auth/*` and `/sync/apply`. |

---

# Audit 2 — Payments & Paystack (backend)

### PAY-01 · `PaymentService` is a god module (~2,300 lines)

| Field | Value |
|-------|--------|
| **Status** | `open` |
| **Severity** | Medium (maintainability) |
| **What's happening** | Sales QR, receivable links, MoMo, webhooks, settlement, and verify paths live in one file. |
| **Why it matters** | Regressions in one flow break another; hard onboarding for new devs. |
| **Where** | `backend/app/services/payment_service.py` |
| **Fix** | Split into `sale_payments.py`, `receivable_payments.py`, `paystack_webhook.py`; keep tests as safety net. |

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
| **Status** | `partial` |
| **Severity** | High (UX) |
| **What's happening** | Merchants reported sheet staying on “checking” until they leave and return. **Fixes applied:** `_onSheetPaymentConfirmed` invalidates `receivableDetailProvider`, applies server row, `refreshFromServer()`; QR/MoMo sheets also invalidate. |
| **Why it matters** | Trust in digital collections; merchants think money was not received. |
| **Where** | `mobile/lib/features/debts/presentation/widgets/debt_payment_link_panel.dart`, `debt_paystack_qr_sheet.dart`, `debt_paystack_momo_sheet.dart` |
| **Fix** | E2E test: pay → webhook/verify → UI shows settled without navigation. Monitor slow webhook regions; tune poll/verify interval. |

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
| **What's happening** | Settlement refuses cancelled receivables; audit event `payment.ignored_cancelled_receivable`. Cancel flow should invalidate pending payments (verify in `receivables_service.cancel_receivable`). |
| **Where** | `backend/app/services/payment_service.py`, `receivables_service.py` |
| **Fix** | Confirm cancel path calls `_invalidate_pending_online_payments` — add test if missing. |

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
| **Status** | `monitor` |
| **Severity** | Medium |
| **What's happening** | Online Paystack flows expect server-side receivable ID. Offline-created debt must sync first (`_ensureSyncedForOnlinePayment` in UI). |
| **Why it matters** | Merchant offline → tries QR → confusing error if sync failed. |
| **Where** | `debt_payment_link_panel.dart`, sync queue |
| **Fix** | Clear UI copy + disable pay buttons until sync success; surface sync pill. |

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
| **Status** | `open` |
| **Severity** | Medium (UX) |
| **What's happening** | Conflicts mark queue row `conflict` and refresh server snapshot; no “keep mine / use server” screen. |
| **Why it matters** | Merchants may not understand `SyncStatusPill` counts. |
| **Where** | `sync_queue_runner.dart`, `sync_status_pill.dart` |
| **Fix** | Conflict detail screen with plain language and actions. |

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
| **Status** | `open` |
| **Severity** | Medium |
| **What's happening** | Constants define `manager`, `cashier`, `stock_keeper`. Enforcement is mostly **owner** (`get_merchant_owner`) vs **everyone else** (`get_current_user`). |
| **Why it matters** | Product may promise tiered permissions; backend treats non-owners similarly. |
| **Where** | `backend/app/core/constants.py`, `backend/app/api/deps.py`, routers |
| **Fix** | Permission matrix doc + `require_role` on routes; extend `test_owner_permissions.py` for manager. |

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
| **Status** | `open` |
| **Severity** | Medium (CI) |
| **What's happening** | `app_routing_test.dart` — `dashboard Debts quick action opens Debts` fails locally (82 pass, 1 fail). |
| **Why it matters** | Mobile CI on `main`/`develop` will fail. |
| **Where** | `mobile/test/features/app_routing_test.dart`, `dashboard_quick_actions.dart` |
| **Fix** | Align finder with current label/route or update test expectations. |

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
| **Status** | `open` |
| **Severity** | High |
| **What's happening** | Several footguns rely on manual env discipline. |
| **Fix** | See **Checklist A** below; automate in Render/deploy script where possible. |

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

- [ ] **AUTH-01** — PIN login rate limiting / lockout
- [ ] **AUTH-05** — Confirm `AUTH_MOCK_OTP_CODE` unset in production (automate check)
- [ ] **AUTH-06** — Confirm strong `SECRET_KEY` in production (fail boot if default)
- [ ] **MOB-01** — Fix failing `app_routing_test` (Debts quick action)
- [ ] **OPS-01** — Run production env checklist on Render (see below)
- [ ] **DEBT-01** — Add E2E or integration test: Paystack debt pay → UI settled (verify webhook-delay path)

### Production env checklist (copy into deploy runbook)

- [ ] `APP_ENV=production`
- [ ] `SECRET_KEY` — long random value, not default
- [ ] `AUTH_MOCK_OTP_CODE` — **empty / unset**
- [ ] `ARKESEL_API_KEY` — set for live SMS
- [ ] `PAYMENT_CONFIG_ENCRYPTION_KEY` — valid Fernet key
- [ ] `PAYSTACK_SECRET_KEY_LIVE` — live key only on production
- [ ] `CORS_ORIGINS` — explicit list (not `*`) if any browser client exists

---

# Master Checklist B — Should complete (next sprint)

- [ ] **AUTH-02** — Refresh token rotation + optional session version on user
- [ ] **AUTH-03** — Server-aware logout (paired with AUTH-02)
- [ ] **AUTH-08** — Rate limiting on `/auth/pin/login`, `/auth/otp/request`, `/sync/apply`
- [ ] **PAY-01** — Split `payment_service.py` into smaller modules
- [ ] **RBAC-01** — Define and enforce manager vs cashier matrix; extend tests
- [ ] **DEBT-03** — Test: cancel receivable invalidates pending Paystack payments
- [ ] **DEBT-09** — UX: block/disable online pay until debt synced; clear messaging
- [ ] **SYNC-02** — Merchant-visible conflict resolution (not only sync pill count)

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
| AUTH-01 | PIN rate limiting | open |
| AUTH-02 | Refresh token revocation | open |
| AUTH-03 | Logout server-side | open |
| AUTH-04 | Custom JWT | open |
| AUTH-05 | Mock OTP in prod | monitor |
| AUTH-06 | Default secret key | monitor |
| AUTH-07 | CORS `*` | open |
| AUTH-08 | API rate limiting | open |
| PAY-01 | PaymentService size | open |
| PAY-02 | Paystack role split | monitor |
| PAY-03 | Webhook shared verify | done |
| DEBT-01 | Stuck “waiting” UI | partial |
| DEBT-02 | Clear link on settle | done |
| DEBT-03 | Cancelled + Paystack | done |
| DEBT-04 | Cash + stale link | done |
| DEBT-05 | Panel verify poll | done |
| DEBT-06 | Partial amount API | done |
| DEBT-07 | Active link semantics | done |
| DEBT-08 | Webhook/verify parity | done |
| DEBT-09 | Sync before online pay | monitor |
| SYNC-01 | Push-only sync | open |
| SYNC-02 | Conflict UX | open |
| SYNC-03 | Dead letter queue | done |
| SYNC-04 | Batch transaction | monitor |
| RBAC-01 | Manager role enforcement | open |
| RBAC-02 | Owner destructive ops | done |
| RBAC-03 | Staff daily ops | done |
| MOB-01 | Routing test fail | open |
| MOB-02 | Large widgets | open |
| MOB-03 | Silent refresh errors | open |
| MOB-04 | Build-time config | monitor |
| ARCH-01 | Single store | open |
| ARCH-02 | Redis unused | open |
| ARCH-03 | Admin stub | open |
| ARCH-04 | Thin routers | done |
| OPS-01 | Prod checklist | open |
| OPS-02 | Security headers | open |
| OPS-03 | Webhook HMAC | done |
| REPO-01 | Scratch files | open |
| REPO-02 | Audit consolidation | done |

---

# Suggested fix order (one path through the audits)

1. **MOB-01** — Green CI (fast win)  
2. **AUTH-01 + AUTH-08** — PIN + auth rate limits  
3. **OPS-01 + AUTH-05 + AUTH-06** — Production env hardening  
4. **AUTH-02 + AUTH-03** — Session lifecycle  
5. **DEBT-01** — E2E payment UX test + monitor webhook delay  
6. **RBAC-01** — Role matrix  
7. **PAY-01** — Payment module split  
8. **SYNC-02 + SYNC-01** — Sync UX and scale  

---

## Related files

| Path | Notes |
|------|--------|
| `debt_payment_flow_audit.md` (repo root) | Historical debt audit — see header for pointer here |
| `docs/auth/pin-and-otp-flow.md` | Auth flow design |
| `ghana_sme_os_docs/` | Architecture & API contracts |
| `docs/development/SETUP.md` | Local and env setup |

---

*Update this document when an audit item is fixed: change **Status** and tick the matching checklist box.*
