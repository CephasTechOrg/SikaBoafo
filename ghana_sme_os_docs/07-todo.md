# Ghana SME OS — Execution Plan & Source of Truth

This document is the **single source of truth** for what BizTrack (the Ghana SME OS implementation) has built, what is partial, and what remains. Every gap from `00-overview.md` through `06-ui-design.md` is captured here.

Every item is annotated with:
- **Status** — `[x]` done · `[~]` partial · `[ ]` not started
- **Location** — where it lives in the repo (or should live)
- **Gap** — exactly what is missing vs. the docs

The repo is a monorepo:
- `backend/` — FastAPI + PostgreSQL + Alembic
- `mobile/` — Flutter (Android-first)
- `ghana_sme_os_docs/` — this documentation set (source of truth for product/architecture)

---

## Legend

| Marker | Meaning |
|---|---|
| `[x] ✅` | Complete and in production-quality shape |
| `[~] 🚧` | Partially implemented — working but with known gaps |
| `[ ] ❌` | Not started — file/folder may exist as stub |

---

## Section A — Database Schema Audit (vs. `04-database.md`)

For every table in the docs, here is the actual state in our codebase.

### A.1 `businesses` (we call it `merchants`)
File: `backend/app/models/merchant.py` · Status: `[~] 🚧`

| Doc field | Our column | Status |
|---|---|---|
| `id` | `id` | ✅ |
| `name` | `business_name` | ✅ (renamed) |
| `type` | `business_type` | ✅ (renamed) |
| `phone` | — | ❌ **MISSING** |
| `whatsapp_number` | — | ❌ **MISSING** |
| `email` | — | ❌ **MISSING** |
| `address` | — | ❌ **MISSING** |
| `city` | — | ❌ **MISSING** |
| `region` | — | ❌ **MISSING** |
| `country` | — | ❌ **MISSING** (hardcoded GH for now) |
| `currency_code` | — | ❌ **MISSING** (hardcoded GHS) |
| `created_at`/`updated_at` | via mixin | ✅ |

**Action**: Add migration to extend `merchants` with `phone`, `whatsapp_number`, `email`, `address`, `city`, `region`, `country`, `currency_code`. All nullable except `country`/`currency_code` which default to `GH`/`GHS`.

### A.2 `users`
File: `backend/app/models/user.py` · Status: `[~] 🚧`

| Doc field | Our column | Status |
|---|---|---|
| `id` | `id` | ✅ |
| `business_id` | — | ❌ **MISSING** (merchant→user is reverse direction — `merchants.owner_user_id`). Needed once multi-user/RBAC lands. |
| `full_name` | — | ❌ **MISSING** |
| `phone` | `phone_number` | ✅ (renamed) |
| `email` | — | ❌ **MISSING** |
| `password_hash` | `pin_hash` | ✅ (PIN-based; better for Ghana, keep) |
| `is_active` | `is_active` | ✅ |
| `last_login_at` | — | ❌ **MISSING** |

**Action**: Add `full_name`, `email` (nullable), `last_login_at`. Add `merchant_id` FK when staff/RBAC lands.

### A.3 `roles` + `user_roles`
Status: `[ ] ❌` **Entire tables missing**

Only one hardcoded role `merchant_owner` in `app/core/constants.py`.

**Action**: See §C.1 below (Staff & RBAC milestone).

### A.4 `customers`
File: `backend/app/models/customer.py` · Status: `[~] 🚧`

| Doc field | Our column | Status |
|---|---|---|
| `id` | `id` | ✅ |
| `business_id` | via `store_id → stores.merchant_id` | ✅ (indirect) |
| `full_name` | `name` | ✅ (renamed) |
| `phone` | `phone_number` | ✅ |
| `whatsapp_number` | — | ❌ **MISSING** |
| `email` | — | ❌ **MISSING** |
| `address` | — | ❌ **MISSING** |
| `notes` | — | ❌ **MISSING** |
| `preferred_contact_channel` | — | ❌ **MISSING** (blocker for channel selection in notifications) |
| `is_active` | — | ❌ **MISSING** |

**Action**: Extend customer table with these fields. `preferred_contact_channel` is critical for §5 messaging.

### A.5 `customer_balances`
Status: `[~] 🚧` Computed on-the-fly, not denormalized.

We sum `receivables.outstanding_amount WHERE customer_id = ?` at read time. Works at current scale. **Action**: revisit if reports slow down at 50k+ receivables.

### A.6 `products` (we call it `items`)
File: `backend/app/models/item.py` · Status: `[~] 🚧`

| Doc field | Our column | Status |
|---|---|---|
| `id` | `id` | ✅ |
| `business_id` | via store | ✅ |
| `name` | `name` | ✅ |
| `sku` | `sku` | ✅ |
| `category` | `category` | ✅ |
| `unit` | — | ❌ **MISSING** (piece / pack / bag / ml / kg) |
| `cost_price` | — | ❌ **MISSING — BLOCKS PROFIT CALC** |
| `selling_price` | `default_price` | ✅ (renamed) |
| `reorder_level` | `low_stock_threshold` | ✅ (renamed) |
| `is_active` | `is_active` | ✅ |

**Action**: Add `unit` (String 32, nullable) and `cost_price` (Numeric 18,2, nullable). Wire `cost_price` into `reports_service.fetch_summary` to compute real margin instead of the current sales-minus-expenses proxy.

### A.7 `stock_items` (we call it `inventory_balances`)
File: `backend/app/models/inventory.py` · Status: `[x] ✅`

All expected columns present (`item_id`, `quantity_on_hand`, `updated_at`). `quantity_reserved` and `last_counted_at` from the doc are not critical for V1.

### A.8 `inventory_movements`
File: `backend/app/models/inventory.py` · Status: `[x] ✅`

**Correction from prior audit:** this IS built. `InventoryMovement` exists and is written to by `sales_service.py` and `inventory_service.py` on every stock change (`stock_in`, `sale_out`, `adjustment_up`, `adjustment_down`, etc.).

Missing from doc schema: `user_id` (who made the movement) — needed once RBAC lands so we can attribute adjustments to a cashier/stock-keeper.

**Action**: Add `user_id` FK when staff lands.

### A.9 `sales` + `sale_items`
File: `backend/app/models/sale.py` · Status: `[~] 🚧`

| Doc field | Our column | Status |
|---|---|---|
| `id` | `id` | ✅ |
| `business_id` | via store | ✅ |
| `customer_id` | `customer_id` | ✅ |
| `cashier_id` | — | ❌ **MISSING — BLOCKS STAFF REPORTS** |
| `subtotal_amount` | — | ❌ **MISSING** (we only store total) |
| `discount_amount` | — | ❌ **MISSING** |
| `tax_amount` | — | ❌ **MISSING** |
| `total_amount` | `total_amount` | ✅ |
| `payment_status` | `payment_status` | ✅ |
| `sale_status` | `sale_status` | ✅ |
| `notes` | `note` | ✅ |
| — | `payment_method_label` (cash/mobile_money/bank_transfer) | bonus |
| — | `voided_at`, `void_reason` | bonus |

**`sale_items`**: all doc fields present (`sale_id, product_id, quantity, unit_price, line_total`). ✅

**Action**: Add `subtotal_amount`, `discount_amount`, `tax_amount`, `cashier_id` (FK users). `cashier_id` backfill = `merchants.owner_user_id` for historical rows.

### A.10 `invoices`
Status: `[ ] ❌` **Entire table missing.**

We have `receivables` as a simpler flatter model. See §C.2 below (Invoice decision) — recommendation is to extend `receivables` rather than add a second table.

### A.11 `payments` (Paystack)
File: `backend/app/models/payment.py` · Status: `[~] 🚧` (model exists, never written by any service)

| Doc field | Our column | Status |
|---|---|---|
| `id` | `id` | ✅ |
| `business_id` | — | ❌ **MISSING** (tenant isolation) |
| `customer_id` | — | ❌ **MISSING** |
| `invoice_id` | — | ❌ (no invoice table) |
| `sale_id` | `sale_id` | ✅ |
| `receivable_payment_id` | `receivable_payment_id` | ✅ (bonus) |
| `provider_name` | `provider` | ✅ (renamed) |
| `provider_reference` | `provider_reference` | ✅ |
| `internal_reference` | — | ❌ **MISSING** |
| `amount` | `amount` | ✅ |
| `currency` | `currency` | ✅ |
| `payment_channel` | — | ❌ **MISSING** |
| `status` | `status` | ✅ |
| `paid_at` | `confirmed_at` | ✅ (renamed) |
| `raw_response_json` | `raw_provider_payload` | ✅ (renamed) |

**Action**: Add `business_id`, `customer_id`, `internal_reference`, `payment_channel`. Build the service that writes to it (Phase 4).

### A.12 `payment_provider_connections`
Status: `[ ] ❌` **Entire table missing.**

Required before Paystack can be wired up — this stores each merchant's encrypted Paystack secret, public key, account label, connection status.

### A.13 `notifications`
Status: `[ ] ❌` **Entire table missing.**

Required for §5 messaging. Schema per doc: `business_id, customer_id, channel, template_name, message_body, status, external_reference, related_type, related_id, sent_at`.

### A.14 `audit_logs`
File: `backend/app/models/audit_log.py` · Status: `[~] 🚧` (model exists, **zero writes anywhere in the codebase**)

Verified: no file other than the model itself and `models/__init__.py` references `AuditLog(`.

| Doc field | Our column | Status |
|---|---|---|
| `id` | `id` | ✅ |
| `business_id` | — | ❌ **MISSING** |
| `user_id` | `actor_user_id` | ✅ (renamed) |
| `action` | `action` | ✅ |
| `entity_type` | `entity_type` | ✅ |
| `entity_id` | `entity_id` | ✅ |
| `old_values_json` / `new_values_json` | `meta` (single JSONB) | ✅ (combined — acceptable) |
| `ip_address` | — | ❌ **MISSING** |
| `user_agent` | — | ❌ **MISSING** |

**Action**: Add `business_id`, `ip_address`, `user_agent`. Build `audit_service.log()` and call from every mutating service. See §C.3.

### A.15 Indexes required by docs
Status: `[~] 🚧`

| Index | Status |
|---|---|
| `business_id` on all tenant tables | ✅ (via `store_id → merchant_id`) |
| `customers(phone, business_id)` | ❌ missing composite |
| `products(sku, business_id)` | ❌ missing composite |
| `invoices(provider_reference)` | N/A (no invoices table) |
| `payments(provider_reference)` | ✅ indexed |
| `notifications(status, channel)` | N/A (table missing) |
| `inventory_movements(product_id, created_at)` | ❌ missing composite |
| `audit_logs(entity_type, entity_id)` | ✅ entity_id indexed; need composite |

**Action**: Add composite indexes in a cleanup migration.

### A.16 Data integrity rules from docs §"Data Integrity Rules"
| Rule | Status |
|---|---|
| No payment success without `provider_reference` | N/A (Paystack not built) — enforce when it is |
| No inventory reduction without inventory movement row | ✅ (enforced in `sales_service`, `inventory_service`) |
| No invoice marked paid unless payment verified | N/A (Paystack not built) |
| All tenant queries filtered by `business_id` | `[~] 🚧` — done manually per-query; no central middleware |
| Every important mutation writes audit log | `[ ] ❌` — **zero audit writes today** |

### A.17 Tables we have that the docs don't mention (keep)
- `stores` — multi-location ready (doc assumes 1 business = 1 location)
- `expenses` — operating costs for owner visibility
- `sync_operations` — offline sync queue (our architectural advantage)

---

## Section B — Phase-by-Phase Status (vs. original doc §Phases 0–8)

### Phase 0 — Product Definition

| # | Task | Status | Notes |
|---|---|---|---|
| 0.1 | Finalize product name | `[~] 🚧` | Codebase is **BizTrack / SikaBoafo**. Doc suggests MoMoLedger, MikaOS, ShopFlow Ghana, Dwen Ledger. Pick one. |
| 0.2 | Choose first merchant niche | `[ ] ❌` | Recommended: pharmacy (highest debt-pain). |
| 0.3 | Lock version 1 scope | `[~] 🚧` | Current scope good for sales/inventory/debts. Missing MVP: Paystack, WhatsApp/SMS, staff roles. |
| 0.4 | Define pricing hypothesis | `[ ] ❌` | No pricing yet. |
| 0.5 | Merchant interview questions | `[ ] ❌` | Questions at bottom of doc — formalize sheet. |

### Phase 1 — UX and Product Design

Per `06-ui-design.md` "Main Screens Needed":

| # | Screen | Status | Location |
|---|---|---|---|
| 1.1 | Onboarding (create account, business, type, payments, first products, first staff) | `[~] 🚧` | `features/onboarding/` — has business profile; **missing connect payments + first staff steps** |
| 1.2 | Dashboard (sales today, unpaid, low stock, top items, staff activity, quick actions) | `[~] 🚧` | `features/dashboard/` — has first four; **missing staff activity summary** |
| 1.3 | Sales Screen (search, add items, customer, total, pay mode, pay now/later, send receipt) | `[~] 🚧` | `features/sales/` — has first six; **missing send receipt** |
| 1.4 | Invoice/Debt Screen (customer, outstanding, due, send reminder, status, history) | `[~] 🚧` | `features/debts/` — has customer/outstanding/due/history; **missing send reminder + payment link** |
| 1.5 | Inventory Screen (list, current stock, reorder warnings, movement history, add/adjust stock) | `[~] 🚧` | `features/inventory/` — has list/stock/reorder/add/adjust; **missing stock movement history UI** |
| 1.6 | Customers Screen (list, phone, total owed, recent payments, preferred channel, reminder) | `[ ] ❌` | **No dedicated customers screen.** Customer CRUD is embedded inside Debts. Build a standalone customers feature. |
| 1.7 | Staff Screen (roles, activity, permissions) | `[ ] ❌` | **Not built.** Requires §C.1 RBAC first. |
| 1.8 | Payment Settings (Connect Paystack, status, verify, test) | `[ ] ❌` | `features/settings/` folder is empty. |
| 1.9 | Clickable prototype | `[~] 🚧` | Live app = prototype. Mockups in `mobile/UI UPDATES/`. |
| 1.10 | Dashboard quick actions: New Sale, **New Invoice**, Record Stock, **Send Reminder**, Add Customer | `[~] 🚧` | Has New Sale and Add Customer. **Missing New Invoice, Record Stock shortcut, Send Reminder shortcut.** |
| 1.11 | Enterprise UI polish (per `06-ui-design.md` visual tone) | `[~] 🚧` | Dashboard/Inventory/Sales/Debts migrated. **Remaining: Expenses, Auth, Settings, Onboarding.** |
| 1.12 | Color system (docs say blue+white+green; we use forest+gold) | **decision made** | Brand is forest+gold. Keep. Just note the divergence from doc. |

### Phase 2 — Technical Setup

| # | Task | Status | Notes |
|---|---|---|---|
| 2.1 | Backend repo | `[x] ✅` | `backend/` |
| 2.2 | Mobile repo | `[x] ✅` | `mobile/` — 37 tests green |
| 2.3 | PostgreSQL | `[x] ✅` | `backend/alembic/versions/` — 4 migrations |
| 2.4 | Redis | `[ ] ❌` | Not configured. Blocker for §6 background jobs. |
| 2.5 | FastAPI structure | `[x] ✅` | Clean layout |
| 2.6 | Authentication | `[x] ✅` | Phone OTP + PIN (better for Ghana than password) |
| 2.7 | RBAC / permissions | `[ ] ❌` | Only `merchant_owner` role. No `@require_role`. |
| 2.8 | Tenant middleware | `[~] 🚧` | Per-query `merchant_id` filtering; no central enforcement. Risk: a future endpoint forgets. |
| 2.9 | Offline-first sync | `[x] ✅` | **Ahead of docs** — `services/sync_service.py` + `features/sync/` |

### Phase 3 — Core Backend Modules

| # | Module | Status | Location | Gap |
|---|---|---|---|---|
| 3.1 | Businesses (merchants) | `[~] 🚧` | `models/merchant.py`, `api/v1/merchants.py` | Schema gap §A.1 (phone, address, etc.) |
| 3.2 | Stores (branches) | `[x] ✅` | `models/store.py` | Ahead of docs |
| 3.3 | Users | `[~] 🚧` | `models/user.py` | Schema gap §A.2 (full_name, email, last_login_at) |
| 3.4 | Roles + user_roles | `[ ] ❌` | — | See §C.1 |
| 3.5 | Customers | `[~] 🚧` | `models/customer.py` | Schema gap §A.4; no dedicated UI |
| 3.6 | customer_balances | `[~] 🚧` | Computed | Consider denormalizing at scale |
| 3.7 | Products (items) | `[~] 🚧` | `models/item.py` | **Missing `cost_price`, `unit`** — §A.6 |
| 3.8 | stock_items (inventory_balances) | `[x] ✅` | `models/inventory.py` | |
| 3.9 | inventory_movements | `[x] ✅` | `models/inventory.py` | Add `user_id` when RBAC lands |
| 3.10 | Sales + sale_items | `[~] 🚧` | `models/sale.py` | Schema gap §A.9 (`subtotal`, `discount`, `tax`, `cashier_id`) |
| 3.11 | Invoices | `[ ] ❌` | — | See §C.2 decision |
| 3.12 | Payments (Paystack) | `[~] 🚧` | `models/payment.py` (never written) | Service missing — Phase 4 |
| 3.13 | payment_provider_connections | `[ ] ❌` | — | Blocker for Paystack |
| 3.14 | Notifications | `[ ] ❌` | — | Phase 5 |
| 3.15 | Audit logs | `[~] 🚧` | `models/audit_log.py` (never written) | See §C.3 |
| 3.16 | Expenses | `[x] ✅` | `models/expense.py` | Ahead of docs |
| 3.17 | Reports | `[x] ✅` | `services/reports_service.py` | Missing: staff activity; real profit via cost_price |

### Phase 4 — Payment Integration (Paystack)

**Overall status: `[ ] ❌` — none built.**

Current stubs:
- `backend/app/api/v1/payments.py` — 5 lines, empty router
- `backend/app/api/v1/webhooks.py` — 5 lines, empty router
- `backend/app/integrations/paystack/` — empty folder
- `mobile/lib/features/payments/` — empty folder

| # | Task | Status | Where |
|---|---|---|---|
| 4.1 | Provider abstraction interface | `[ ] ❌` | `backend/app/integrations/payments/base.py` (new) |
| 4.2 | `payment_provider_connections` table + model | `[ ] ❌` | `models/payment_provider_connection.py` (new) + migration |
| 4.3 | Encrypt merchant secret at rest (Fernet/libsodium) | `[ ] ❌` | `core/crypto.py` (new) |
| 4.4 | Paystack HTTP client | `[ ] ❌` | `integrations/paystack/client.py` |
| 4.5 | "Connect Paystack" settings UI | `[ ] ❌` | `mobile/lib/features/settings/presentation/connect_paystack_screen.dart` |
| 4.6 | Backend connect/disconnect API | `[ ] ❌` | new `payment_settings.py` routes |
| 4.7 | Payment request creation service | `[ ] ❌` | `services/payment_service.py` + `POST /payments/initiate` |
| 4.8 | Webhook endpoint with HMAC-SHA512 validation | `[ ] ❌` | `api/v1/webhooks.py` |
| 4.9 | Webhook double-verification via `/transaction/verify` | `[ ] ❌` | inside webhook handler |
| 4.10 | Idempotency (unique `provider_reference`, store event IDs) | `[ ] ❌` | in handler + DB constraint |
| 4.11 | Downstream updates (sale/receivable, audit log, notification) | `[ ] ❌` | `payment_service.py` |
| 4.12 | Pay-now flow (immediate sale) | `[ ] ❌` | sales screen |
| 4.13 | Pay-later flow (debt → shareable link) | `[ ] ❌` | debts screen |
| 4.14 | Partial payment handling | `[ ] ❌` | `receivables_service.py` |
| 4.15 | Test-mode toggle (test/live keys) | `[ ] ❌` | settings |
| 4.16 | Payment status polling on mobile (after opening link) | `[ ] ❌` | mobile payments feature |

### Phase 5 — Messaging Integration (WhatsApp + SMS)

**Overall status: `[ ] ❌`**

| # | Task | Status | Where |
|---|---|---|---|
| 5.1 | `notifications` table + model | `[ ] ❌` | `models/notification.py` (new) + migration |
| 5.2 | Notification service (single entry point `send()`) | `[ ] ❌` | `services/notification_service.py` |
| 5.3 | WhatsApp provider (Meta Cloud API) | `[ ] ❌` | `integrations/whatsapp/client.py` |
| 5.4 | SMS provider (Hubtel or Mnotify — Ghana-local) | `[ ] ❌` | `integrations/sms/client.py` |
| 5.5 | Receipt template | `[ ] ❌` | `services/notification_service.py` |
| 5.6 | Reminder template | `[ ] ❌` | `services/notification_service.py` |
| 5.7 | Channel-selection logic (`customer.preferred_contact_channel`, opt-out, fallback) | `[ ] ❌` | depends on §A.4 customer fields |
| 5.8 | Notification delivery log (queued→sent→delivered→failed) | `[ ] ❌` | write row in `notifications` |
| 5.9 | Wire receipts into payment-success flow | `[ ] ❌` | `payment_service.py` |
| 5.10 | Scheduled reminder job (daily, cool-down per customer) | `[ ] ❌` | `tasks/reminders.py` (Celery) |
| 5.11 | Owner daily summary send | `[ ] ❌` | `tasks/daily_summary.py` (Celery) |
| 5.12 | Webhook for delivery status (WhatsApp/SMS callbacks) | `[ ] ❌` | `api/v1/webhooks.py` |

### Phase 6 — Reporting, Audit & Background Jobs

| # | Task | Status | Notes |
|---|---|---|---|
| 6.1 | Daily sales summary UI | `[x] ✅` | `reports_service.fetch_summary` |
| 6.2 | Daily summary WhatsApp/SMS send to owner | `[ ] ❌` | Depends on §5.11 |
| 6.3 | Low-stock UI alerts | `[x] ✅` | Dashboard + inventory |
| 6.4 | Low-stock push / WhatsApp alerts | `[ ] ❌` | Event + Celery |
| 6.5 | Cashier activity summary report | `[ ] ❌` | Blocked on §A.9 `cashier_id` + §C.1 RBAC |
| 6.6 | Suspicious action report | `[ ] ❌` | Blocked on §C.3 audit writes |
| 6.7 | Real profit estimation (via `cost_price`) | `[~] 🚧` | Today = sales − expenses. Need §A.6 cost_price column + per-line cost snapshot on sale_items. |
| 6.8 | Redis + Celery setup | `[ ] ❌` | `celery.py` missing, no Docker-compose entry |
| 6.9 | Celery beat schedule | `[ ] ❌` | For §5.10 / §6.2 / §6.4 |
| 6.10 | Event bus (sale.created, payment.succeeded, stock.low …) | `[ ] ❌` | `backend/app/events/` folder empty |

### Phase 7 — Merchant Validation

| # | Task | Status |
|---|---|---|
| 7.1 | Pharmacy pilot | `[ ] ❌` — blocked on M4 |
| 7.2 | Provision store pilot | `[ ] ❌` |
| 7.3 | Building materials pilot | `[ ] ❌` |
| 7.4 | Feedback collection | `[ ] ❌` |
| 7.5 | Flow simplifications | `[ ] ❌` |
| 7.6 | Identify top-3 sticky features | `[ ] ❌` |

### Phase 8 — Launch Readiness

| # | Task | Status |
|---|---|---|
| 8.1 | Onboarding checklist UI | `[~] 🚧` — basic, not a checklist |
| 8.2 | Merchant help content | `[ ] ❌` |
| 8.3 | Paystack connection guide | `[ ] ❌` |
| 8.4 | Privacy policy | `[ ] ❌` |
| 8.5 | Terms of service | `[ ] ❌` |
| 8.6 | In-app support flow (WhatsApp handoff) | `[ ] ❌` |
| 8.7 | Internal admin tools (superuser dashboard) | `[ ] ❌` |
| 8.8 | Beta launch list | `[ ] ❌` |

---

## Section C — The Three Structural Gaps (Must-Haves)

### C.1 Staff Roles & RBAC  `[ ] ❌`

Blocks: staff activity reports, meaningful audit logs, multi-user shops.

Steps:
1. Add `users.merchant_id` FK (or create `user_roles` table per doc §A.3). Simpler path: widen existing `users.role` enum to `owner | manager | cashier | stock_keeper` and add `merchant_id`.
2. Add `users.full_name` / `email` / `last_login_at` (§A.2).
3. Add `sales.cashier_id` FK (§A.9).
4. Add `inventory_movements.user_id` FK (§A.8).
5. "Invite staff" flow: owner enters phone → creates `staff_invite` row → staff signs in via OTP on that phone → completes PIN setup.
6. `@require_role(…)` decorator on sensitive routes: delete item, adjust stock, connect Paystack, delete debt, void sale, change staff.
7. Mobile **Staff screen** (`features/settings/presentation/staff_screen.dart`): list users, invite, change role, deactivate.
8. Attribution fix: every existing sale backfilled to `merchants.owner_user_id` as cashier.

### C.2 Invoice Model Decision  `[ ] ❌`

Docs describe `invoices (invoice_number, status lifecycle, payment_link, provider_reference, created_by)`. We have `receivables` (flatter).

**Two paths — pick before Phase 4:**

- **A. Extend `Receivable`** with `invoice_number` (auto-generated `INV-YYYY-####`), `payment_link` (nullable), `payment_provider_reference`, `created_by_user_id`, `sale_id` (nullable link), widen `status` to `draft|sent|partially_paid|paid|overdue|cancelled`.
- **B. Add new `Invoice` model** wrapping receivable — correct long-term but doubles schema and forces UI rewrites.

**Recommendation: A.** Keep UI unchanged; only external-facing language says "invoice".

### C.3 Audit Log Writes  `[ ] ❌`

Schema exists, zero writes confirmed via grep across `backend/app/`.

Steps:
1. Build `services/audit_service.py` with `log(action, entity_type, entity_id, actor_user_id, meta, business_id=, ip_address=, user_agent=)`.
2. Add `audit_logs.business_id`, `ip_address`, `user_agent` columns (§A.14).
3. Call inside the same DB transaction from:
   - sale create / cancel / void / refund
   - inventory adjustment (manual, damage, return)
   - receivable create / edit / delete
   - receivable payment record / undo
   - payment connection connect / disconnect
   - user role change / user deactivation / user invite accepted
   - expense create / delete
   - merchant profile edit
4. Owner-only endpoint `GET /audit-logs` with filters (entity_type, entity_id, actor, date range, action) + paging.
5. Mobile owner-only **Audit Log screen** (`features/settings/presentation/audit_log_screen.dart`) — timeline view with filters.

---

## Section D — Recommended Build Order (6 Milestones)

Each milestone is shippable on its own and unlocks the next.

### M1 — Schema Parity + Inventory Movements + Audit Writes (~1–1.5 weeks)
Backend-only. No UI changes except audit-log viewer.

- §A.1 merchants: add phone, whatsapp_number, email, address, city, region, country, currency_code
- §A.2 users: add full_name, email, last_login_at
- §A.4 customers: add whatsapp_number, email, address, notes, preferred_contact_channel, is_active
- §A.6 items: add `cost_price`, `unit`
- §A.9 sales: add `subtotal_amount`, `discount_amount`, `tax_amount`
- §A.14 audit_logs: add business_id, ip_address, user_agent
- §C.3 build `audit_service.log()` + call sites in every mutating service
- §A.15 composite indexes

### M2 — Staff Roles & RBAC (~1.5–2 weeks)
- §A.9 add `sales.cashier_id`
- §A.8 add `inventory_movements.user_id`
- §C.1 widen user roles, add merchant_id FK
- Invite flow (phone OTP)
- `@require_role` decorator on sensitive routes
- Mobile Staff screen
- Backfill `cashier_id` = owner for historical rows
- Attribute future sales/movements to actual authenticated user

### M3 — Customers Screen + Invoice Extension + Cost-Based Profit (~1 week)
- §1.6 build standalone Customers feature (`mobile/lib/features/customers/`)
- §C.2 extend Receivable with `invoice_number`, `payment_link`, `payment_provider_reference`, `created_by_user_id`, `sale_id`, wider status enum
- §6.7 compute real profit using `cost_price` snapshot on sale_items

### M4 — Paystack Integration (~2–3 weeks)
The big one. §4.1 through §4.16.
- Provider abstraction + encrypted key storage
- "Connect Paystack" settings screen
- Create payment request
- Webhook with HMAC verification + double-verify + idempotency
- Pay-now flow on sales
- Pay-later flow on debts (generates link, stores on receivable)
- Partial payment handling

### M5 — WhatsApp + SMS + Receipts + Reminders (~2 weeks)
- Redis + Celery setup (§6.8)
- §5.1–5.8 Notification model + service + providers + templates
- Channel selection (now that `preferred_contact_channel` exists from M1)
- Hook receipts into payment success
- Scheduled reminder job (§5.10)
- Daily summary job (§5.11 / §6.2)
- Low-stock WhatsApp alert (§6.4)

### M6 — Merchant Validation & Launch Prep (~2–4 weeks)
- Pick one vertical (pharmacy recommended)
- Onboard 3 real shops
- Instrument funnel
- Phase 8 launch-readiness items (privacy, terms, help content, support)
- Iterate

**Total time-to-real-merchants: ~10–12 weeks of focused work.**

---

## Section E — Empty Stubs (build or delete)

| Path | Action |
|---|---|
| `backend/app/api/v1/payments.py` | Build in M4 |
| `backend/app/api/v1/webhooks.py` | Build in M4 + M5 |
| `backend/app/integrations/paystack/` | Build in M4 |
| `backend/app/integrations/whatsapp/` | Build in M5 |
| `backend/app/integrations/sms/` | Build in M5 |
| `backend/app/events/` | Build in M5 (event bus for sale/payment/stock events) |
| `backend/app/tasks/` | Build in M5 (Celery task modules) |
| `backend/app/workers/` | Build in M5 (worker entrypoints) |
| `mobile/lib/features/payments/` | Build in M4 |
| `mobile/lib/features/settings/` | Build in M2 (staff) + M4 (Paystack) |
| `mobile/lib/features/sync/` | Empty — sync logic lives in `core/`. Delete this folder. |

---

## Section F — Out of Scope for Version 1

Keep saying NO to (per `00-overview.md` §Version 1 Focus + `03-system-design.md` §Version 1 Product Boundary):

- Multi-currency (GHS only)
- Multi-provider payment routing (Paystack only)
- Tax-filing automation
- Lending / BNPL / credit scoring
- Marketplace settlement / split payments
- Direct handling of merchant funds (provider holds & settles)
- Advanced accounting (GL, trial balance, balance sheet)
- Web admin dashboard (mobile-first only for V1)
- QR payments as primary flow (links first, QR later)
- Refunds (defer to V2)

---

## Section G — Questions to Validate with Real Merchants

Run these interviews at the start of M6 (unchanged from original doc):

- How often do you sell on credit?
- How do you currently track who owes you?
- How often do customers pay with MoMo?
- Do you remind customers by WhatsApp, SMS, or voice call?
- Who records sales today?
- How do you know stock is finishing?
- What is the most painful part of your daily operation?
- Would you pay monthly for a tool that improves collections and stock control?

---

## Section H — Revised First-Build Priorities

Original list vs. current reality:

| # | Original | Revised |
|---|---|---|
| 1 | Auth + tenant | ✅ Done |
| 2 | Customers | ✅ Done (embedded) — M3 standalone |
| 3 | Products + stock | ✅ Done — M1 adds cost_price/unit |
| 4 | Sales | ✅ Done — M1 adds subtotal/discount/tax; M2 adds cashier_id |
| 5 | Invoices + debt | ✅ Done (as receivables) — M3 extends with invoice fields |
| 6 | Payment links | **M4** |
| 7 | Webhook verification | **M4** |
| 8 | Reminders + receipts | **M5** |
| 9 | Dashboard | ✅ Done — M2 adds staff activity |
| 10 | Audit logs | **M1** (writes) |

---

## One-Paragraph Summary

BizTrack has the **foundation of the Ghana SME OS already working**: auth, tenancy via merchant+store, inventory with movement audit trail, sales, debts, expenses, reports — plus an offline-sync layer the docs don't describe. The remaining work splits into four layers: **schema parity** (add missing columns on merchants/users/customers/items/sales — M1), **trust & accountability** (audit writes + staff RBAC — M1+M2), **monetization** (Paystack payment links — M4), and **customer touch** (WhatsApp/SMS receipts and reminders — M5). In order: M1 → M2 → M3 → M4 → M5 → M6, roughly 10–12 weeks to first real merchant validation.
