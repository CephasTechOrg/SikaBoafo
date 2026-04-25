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
File: `backend/app/models/merchant.py` · Status: `[x] ✅` *(M1 complete)*

| Doc field | Our column | Status |
|---|---|---|
| `id` | `id` | ✅ |
| `name` | `business_name` | ✅ (renamed) |
| `type` | `business_type` | ✅ (renamed) |
| `phone` | `phone` | ✅ added M1 |
| `whatsapp_number` | `whatsapp_number` | ✅ added M1 |
| `email` | `email` | ✅ added M1 |
| `address` | `address` | ✅ added M1 |
| `city` | `city` | ✅ added M1 |
| `region` | `region` | ✅ added M1 |
| `country` | `country` | ✅ default "GH" |
| `currency_code` | `currency_code` | ✅ default "GHS" |
| `created_at`/`updated_at` | via mixin | ✅ |

### A.2 `users`
File: `backend/app/models/user.py` · Status: `[x] ✅` *(M1+M2 complete)*

| Doc field | Our column | Status |
|---|---|---|
| `id` | `id` | ✅ |
| `business_id` | `merchant_id` FK | ✅ added M2 (staff FK; owners use `merchants.owner_user_id`) |
| `full_name` | `full_name` | ✅ added M1 |
| `phone` | `phone_number` | ✅ (renamed) |
| `email` | `email` | ✅ added M1 |
| `password_hash` | `pin_hash` | ✅ (PIN-based; better for Ghana, keep) |
| `is_active` | `is_active` | ✅ |
| `last_login_at` | `last_login_at` | ✅ added M1 |
| `role` | `role` | ✅ M2: owner/manager/cashier/stock_keeper |

### A.3 `roles` + `user_roles`
Status: `[x] ✅` *(M2 complete — single-table approach)*

`users.role` enum now covers `merchant_owner | manager | cashier | stock_keeper`. `staff_invites` table drives the invite-to-link flow. No separate roles/user_roles tables needed (simpler and sufficient for V1).

### A.4 `customers`
File: `backend/app/models/customer.py` · Status: `[x] ✅` *(M1 complete)*

| Doc field | Our column | Status |
|---|---|---|
| `id` | `id` | ✅ |
| `business_id` | via `store_id → stores.merchant_id` | ✅ (indirect) |
| `full_name` | `name` | ✅ (renamed) |
| `phone` | `phone_number` | ✅ |
| `whatsapp_number` | `whatsapp_number` | ✅ added M1 |
| `email` | `email` | ✅ added M1 |
| `address` | `address` | ✅ added M1 |
| `notes` | `notes` | ✅ added M1 |
| `preferred_contact_channel` | `preferred_contact_channel` | ✅ added M1 |
| `is_active` | `is_active` | ✅ added M1 |

### A.5 `customer_balances`
Status: `[x] ✅` *(M3 complete — exposed as `total_outstanding` on `CustomerOut`)*

`list_customers_for_user` computes `SUM(outstanding_amount)` via a single LEFT JOIN + GROUP BY query. Exposed as `total_outstanding: Decimal` on `CustomerOut` (API), `LocalDebtCustomer.totalOutstanding` (mobile), and shown as a badge on the Customers screen. Revisit denormalization if reports slow at 50k+ receivables.

### A.6 `products` (we call it `items`)
File: `backend/app/models/item.py` · Status: `[x] ✅` *(M1 complete)*

| Doc field | Our column | Status |
|---|---|---|
| `id` | `id` | ✅ |
| `business_id` | via store | ✅ |
| `name` | `name` | ✅ |
| `sku` | `sku` | ✅ |
| `category` | `category` | ✅ |
| `unit` | `unit` | ✅ added M1 |
| `cost_price` | `cost_price` | ✅ added M1 |
| `selling_price` | `default_price` | ✅ (renamed) |
| `reorder_level` | `low_stock_threshold` | ✅ (renamed) |
| `is_active` | `is_active` | ✅ |

**M3 complete**: `cost_price_snapshot` added to `sale_items` via migration 007. Snapshot frozen at sale time; gross profit computed as `Σ(unit_price − cost_price_snapshot) × qty` in `reports_service`. Backwards-safe: NULL snapshot rows excluded from gross profit so pre-M3 sales don't distort the metric.

### A.7 `stock_items` (we call it `inventory_balances`)
File: `backend/app/models/inventory.py` · Status: `[x] ✅`

All expected columns present (`item_id`, `quantity_on_hand`, `updated_at`). `quantity_reserved` and `last_counted_at` from the doc are not critical for V1.

### A.8 `inventory_movements`
File: `backend/app/models/inventory.py` · Status: `[x] ✅` *(M2 complete)*

`InventoryMovement` exists and is written to by `sales_service.py` and `inventory_service.py` on every stock change. `user_id` FK added M2 — every stock-in and adjustment now records the authenticated user.

### A.9 `sales` + `sale_items`
File: `backend/app/models/sale.py` · Status: `[x] ✅` *(M1+M2 complete)*

| Doc field | Our column | Status |
|---|---|---|
| `id` | `id` | ✅ |
| `business_id` | via store | ✅ |
| `customer_id` | `customer_id` | ✅ |
| `cashier_id` | `cashier_id` | ✅ added M2 — set to authenticated user on every new sale |
| `subtotal_amount` | `subtotal_amount` | ✅ added M1 |
| `discount_amount` | `discount_amount` | ✅ added M1 |
| `tax_amount` | `tax_amount` | ✅ added M1 |
| `total_amount` | `total_amount` | ✅ |
| `payment_status` | `payment_status` | ✅ |
| `sale_status` | `sale_status` | ✅ |
| `notes` | `note` | ✅ |
| — | `payment_method_label` (cash/mobile_money/bank_transfer) | bonus |
| — | `voided_at`, `void_reason` | bonus |

**`sale_items`**: all doc fields present (`sale_id, product_id, quantity, unit_price, line_total`). ✅

**Remaining**: Backfill historical `cashier_id = merchants.owner_user_id` (low-priority; only affects pre-M2 rows).

### A.10 `invoices`
Status: `[ ] ❌` **Entire table missing.**

We have `receivables` as a simpler flatter model. See §C.2 below (Invoice decision) — recommendation is to extend `receivables` rather than add a second table.

### A.11 `payments` (Paystack)
File: `backend/app/models/payment.py` · Status: `[~] 🚧` (service writes now active for receivable and sale initiation)

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

**Action**: Add `business_id`, `customer_id`, `internal_reference`, `payment_channel`; complete webhook settlement + post-payment notification flow.

### A.12 `payment_provider_connections`
Status: `[x] ✅` *(merchant-owned credential architecture implemented)*

`payment_provider_connections` now stores merchant-level Paystack state for **both test and live modes**: active `mode`, `account_label`, per-mode `public_key`, encrypted `secret_key`, last4 mask, verification timestamps, and `is_connected` for the active verified mode. Owner-only APIs/UI now use write-only secret submission with backend verification on save.

### A.13 `notifications`
Status: `[ ] ❌` **Entire table missing.**

Required for §5 messaging. Schema per doc: `business_id, customer_id, channel, template_name, message_body, status, external_reference, related_type, related_id, sent_at`.

### A.14 `audit_logs`
File: `backend/app/models/audit_log.py` · Status: `[x] ✅` *(M1 complete)*

| Doc field | Our column | Status |
|---|---|---|
| `id` | `id` | ✅ |
| `business_id` | `business_id` | ✅ added M1 |
| `user_id` | `actor_user_id` | ✅ (renamed) |
| `action` | `action` | ✅ |
| `entity_type` | `entity_type` | ✅ |
| `entity_id` | `entity_id` | ✅ |
| `old_values_json` / `new_values_json` | `meta` (single JSONB) | ✅ (combined — acceptable) |
| `ip_address` | `ip_address` | ✅ added M1 |
| `user_agent` | `user_agent` | ✅ added M1 |

`audit_service.log_audit()` built M1; called from every mutating service (sales, inventory, expenses, receivables). Owner-only read endpoint is M3 backlog.

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
| Every important mutation writes audit log | `[~] 🚧` — writes active on sales/inventory/expenses/receivables (M1). Paystack + role changes pending. |

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
| 0.3 | Lock version 1 scope | `[~] 🚧` | Current scope good for sales/inventory/debts. Missing MVP: Paystack live collection/webhooks and WhatsApp/SMS messaging. |
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
| 1.6 | Customers Screen (list, phone, total owed, recent payments, preferred channel, reminder) | `[x] ✅` | Built M3 — `features/customers/` with `CustomersScreen` (list + outstanding badge) and `CustomerDetailScreen` (profile + debt history). Accessible via people icon in Debts header. **Remaining**: send reminder (M5), payment link (M4). |
| 1.7 | Staff Screen (roles, activity, permissions) | `[x] ✅` | Built M2 — `features/settings/presentation/staff_screen.dart`. Invite, list, change role, deactivate. Accessible from Business Settings sheet. |
| 1.8 | Payment Settings (Connect Paystack, status, verify, test) | `[x] ✅` | `features/settings/presentation/connect_paystack_screen.dart` now supports test/live mode selection, write-only secret capture, backend verify-on-save, and per-mode configured/verified status. |
| 1.9 | Clickable prototype | `[~] 🚧` | Live app = prototype. Mockups in `mobile/UI UPDATES/`. |
| 1.10 | Dashboard quick actions: New Sale, **New Invoice**, Record Stock, **Send Reminder**, Add Customer | `[~] 🚧` | Has New Sale and Add Customer. **Missing New Invoice, Record Stock shortcut, Send Reminder shortcut.** |
| 1.11 | Enterprise UI polish (per `06-ui-design.md` visual tone) | `[~] 🚧` | Dashboard/Inventory/Sales/Debts/Customers/Staff/Settings migrated. Navigation consistency sweep done (all `maybePop` → GoRouter `pop`). **Remaining: Expenses screen, Auth screens, Onboarding screens.** |
| 1.12 | Color system (docs say blue+white+green; we use forest+gold) | **decision made** | Brand is forest+gold. Keep. Just note the divergence from doc. |

### Phase 2 — Technical Setup

| # | Task | Status | Notes |
|---|---|---|---|
| 2.1 | Backend repo | `[x] ✅` | `backend/` |
| 2.2 | Mobile repo | `[x] ✅` | `mobile/` — 37 tests green; 51 backend tests green |
| 2.3 | PostgreSQL | `[x] ✅` | `backend/alembic/versions/` — 6 migrations |
| 2.4 | Redis | `[ ] ❌` | Not configured. Blocker for §6 background jobs. |
| 2.5 | FastAPI structure | `[x] ✅` | Clean layout |
| 2.6 | Authentication | `[x] ✅` | Phone OTP + PIN (better for Ghana than password). 2026-04-24 hardening: OTP is now locally generated/verified by BizTrack with Arkesel used only as SMS transport. |
| 2.7 | RBAC / permissions | `[x] ✅` | M2: 4 roles, `require_role()` dep in `api/deps.py`, staff routes owner-gated. |
| 2.8 | Tenant middleware | `[~] 🚧` | Per-query `merchant_id` filtering; no central enforcement. Risk: a future endpoint forgets. |
| 2.9 | Offline-first sync | `[x] ✅` | **Ahead of docs** — `services/sync_service.py` + `features/sync/` |

### Phase 3 — Core Backend Modules

| # | Module | Status | Location | Gap |
|---|---|---|---|---|
| 3.1 | Businesses (merchants) | `[~] 🚧` | `models/merchant.py`, `api/v1/merchants.py` | Schema gap §A.1 (phone, address, etc.) |
| 3.2 | Stores (branches) | `[x] ✅` | `models/store.py` | Ahead of docs |
| 3.3 | Users | `[x] ✅` | `models/user.py` | M1+M2: full_name, email, last_login_at, merchant_id, role widened |
| 3.4 | Roles + user_roles | `[x] ✅` | `models/staff_invite.py`, `core/constants.py` | M2: single-table approach with staff_invites |
| 3.5 | Customers | `[x] ✅` | `models/customer.py`, `features/customers/` | M1 schema complete; M3: dedicated screen + `GET /receivables/customers/{id}` detail endpoint + `total_outstanding` on list + `whatsapp_number/email/notes` exposed on `CustomerOut` |
| 3.6 | customer_balances | `[~] 🚧` | Computed | Consider denormalizing at scale |
| 3.7 | Products (items) | `[x] ✅` | `models/item.py` | M1: `cost_price`, `unit` added |
| 3.8 | stock_items (inventory_balances) | `[x] ✅` | `models/inventory.py` | |
| 3.9 | inventory_movements | `[x] ✅` | `models/inventory.py` | M2: `user_id` added |
| 3.10 | Sales + sale_items | `[x] ✅` | `models/sale.py` | M1+M2: `subtotal`, `discount`, `tax`, `cashier_id` all added |
| 3.11 | Invoices | `[ ] ❌` | — | See §C.2 decision |
| 3.12 | Payments (Paystack) | `[~] 🚧` | `models/payment.py`, `services/payment_service.py`, `api/v1/payments.py`, `api/v1/webhooks.py` | M4 Step 2-7 plus merchant-owned credential refactor are built: initiation/webhooks now use merchant-specific encrypted secrets with payment-level mode snapshots. Remaining: notifications and optional provider abstraction cleanup. |
| 3.13 | payment_provider_connections | `[x] ✅` | `models/payment_provider_connection.py` + migrations 009/012 | Merchant-owned test/live credentials now persist encrypted at rest with verify-on-save and active-mode connection status. |
| 3.14 | Notifications | `[ ] ❌` | — | Phase 5 |
| 3.15 | Audit logs | `[x] ✅` | `models/audit_log.py`, `services/audit_service.py` | M1: writes on every mutation |
| 3.16 | Expenses | `[x] ✅` | `models/expense.py` | Ahead of docs |
| 3.17 | Reports | `[x] ✅` | `services/reports_service.py` | Missing: staff activity. **M3**: gross profit via cost_price snapshot added ✅ |

### Phase 4 — Payment Integration (Paystack)

**Overall status: `[~] 🚧` — Step 1 connection settings slice is complete and stabilized.**

Current stubs:
- `mobile/lib/features/payments/` — empty folder

| # | Task | Status | Where |
|---|---|---|---|
| 4.1 | Provider abstraction interface | `[ ] ❌` | `backend/app/integrations/payments/base.py` (new) |
| 4.2 | `payment_provider_connections` table + model | `[x] ✅` | `models/payment_provider_connection.py` + migration 009 |
| 4.3 | Encrypt merchant secret at rest (Fernet/libsodium) | `[x] ✅` | `core/crypto.py` + `PAYMENT_CONFIG_ENCRYPTION_KEY` |
| 4.4 | Paystack HTTP client | `[x] ✅` | `integrations/paystack/client.py` now covers initialization, verify, and connection verification (`/integration/payment_session_timeout`) |
| 4.5 | "Connect Paystack" settings UI | `[x] ✅` | `mobile/lib/features/settings/presentation/connect_paystack_screen.dart` |
| 4.6 | Backend connect/disconnect API | `[x] ✅` | `/payments/paystack/connection` (`GET/PUT/DELETE`) |
| 4.7 | Payment request creation service | `[~] 🚧` | `services/payment_service.py` + `POST /payments/initiate` + `POST /payments/initiate-sale` |
| 4.8 | Webhook endpoint with HMAC-SHA512 validation | `[x] ✅` | `POST /webhooks/paystack` with signature validation |
| 4.9 | Webhook double-verification via `/transaction/verify` | `[x] ✅` | implemented in `payment_service.handle_paystack_webhook()` |
| 4.10 | Idempotency (unique `provider_reference`, store event IDs) | `[x] ✅` | migration 010 adds unique `payments.provider_reference`; `payment_webhook_events` table enforces unique `(provider, event_key)` for replay protection. |
| 4.11 | Downstream updates (sale/receivable, audit log, notification) | `[~] 🚧` | receivable settlement + sale settlement + audit logs are wired. notifications still pending. |
| 4.12 | Pay-now flow (immediate sale) | `[~] 🚧` | Sales checkout supports Paystack link generation via `POST /payments/initiate-sale`; webhook-based sale settlement is now wired; mobile status refresh action is wired via `GET /sales/{sale_id}` polling. |
| 4.13 | Pay-later flow (debt → shareable link) | `[~] 🚧` | Debt Detail now has Generate/Copy Link + **Check Status** polling via `GET /receivables/{receivable_id}`; receivable webhook settlement is wired. Remaining: deeper partial-payment UX polish. |
| 4.14 | Partial payment handling | `[~] 🚧` | Webhook settlement now uses verified Paystack amount and records partial receivable settlement safely; underpaid sale verification now fails settlement. Remaining: optional UI polish for partial-payment messaging. |
| 4.15 | Test-mode toggle (test/live keys) | `[x] ✅` | Mode selector implemented in connection settings (`test` / `live`) |
| 4.16 | Payment status polling on mobile (after opening link) | `[x] ✅` | Implemented for both sales and debt payment-link flows with in-app status refresh actions. |

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
| 6.7 | Real profit estimation (via `cost_price`) | `[x] ✅` | M3: `cost_price_snapshot` frozen on `sale_items` at sale time (migration 007). Gross profit = `Σ(unit_price − cost_price_snapshot) × qty` via `_sum_gross_profit` in reports service. Exposed on dashboard summary + period insights. Conditional KPI card in Reports screen (only shown when gross profit > 0). |
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

### C.1 Staff Roles & RBAC  `[x] ✅` *(M2 complete)*

All steps done:
1. `users.merchant_id` FK — staff link added. `users.role` widened to `owner | manager | cashier | stock_keeper`.
2. `users.full_name` / `email` / `last_login_at` — added M1.
3. `sales.cashier_id` FK — added M2, populated on every new sale.
4. `inventory_movements.user_id` FK — added M2, populated on stock-in and adjustments.
5. Invite flow — `staff_invites` table, `auth_service._accept_pending_invite()` links user on first OTP.
6. `require_role(*roles)` dependency factory in `api/deps.py`; staff routes are owner-gated.
7. Mobile Staff screen built at `features/settings/presentation/staff_screen.dart`.
8. New sales auto-attribute to `cashier_id = current_user.id`. Historical backfill is a low-priority follow-up.

**Remaining**: Expand `require_role` to cover more sensitive routes (void sale, adjust stock, etc.) as part of future hardening.

### C.2 Invoice Model Decision  `[x] ✅` *(M3 — done)*

Docs describe `invoices (invoice_number, status lifecycle, payment_link, provider_reference, created_by)`. We have `receivables` (flatter).

**Decision: Path A — extend `Receivable`.** Implemented M3:
- Alembic migration `008_invoice_extension.py`: added `invoice_number`, `sale_id`, `created_by_user_id`, `payment_link`, `payment_provider_reference` columns
- Service: `_generate_invoice_number()` auto-generates `INV-YYYY-####`; `cancel_receivable()` endpoint; `partially_paid` status on partial repayment; `_TERMINAL_STATUSES` guard
- API: `POST /{id}/cancel` endpoint; `_receivable_out()` helper
- Mobile: SQLite schema v11 migration; DTO fields; sync upsert; debt card shows invoice tag + `cancelled`/`partially_paid` status pills; detail screen shows Invoice metric + Cancel button with confirmation dialog; "Receive" button active for `open` and `partially_paid`
- Tests: 53 backend / 37 Flutter all pass

### C.3 Audit Log Writes  `[~] 🚧` *(M1 complete — read endpoint + UI still missing)*

`services/audit_service.py` built M1. Writes active on:
- sale create / void (sales_service)
- inventory stock-in / adjustment / item create / item update (inventory_service)
- receivable create / payment record (receivables_service)
- expense create (expense_service)

**Remaining (M3 backlog)**:
4. Owner-only `GET /audit-logs` endpoint with filters + paging.
5. Mobile **Audit Log screen** (`features/settings/presentation/audit_log_screen.dart`).

---

## Section D — Recommended Build Order (6 Milestones)

Each milestone is shippable on its own and unlocks the next.

### M1 — Schema Parity + Inventory Movements + Audit Writes  `[x] ✅` *(complete)*

- §A.1 merchants: phone, whatsapp_number, email, address, city, region, country, currency_code ✅
- §A.2 users: full_name, email, last_login_at ✅
- §A.4 customers: whatsapp_number, email, address, notes, preferred_contact_channel, is_active ✅
- §A.6 items: `cost_price`, `unit` ✅
- §A.9 sales: `subtotal_amount`, `discount_amount`, `tax_amount` ✅
- §A.14 audit_logs: business_id, ip_address, user_agent ✅
- §C.3 `audit_service.log_audit()` + call sites in every mutating service ✅
- §A.15 composite indexes (migration 005) ✅

### M2 — Staff Roles & RBAC  `[x] ✅` *(complete)*

- §A.9 `sales.cashier_id` — added, populated on every new sale ✅
- §A.8 `inventory_movements.user_id` — added, populated on stock ops ✅
- §C.1 roles widened, `users.merchant_id` FK, `staff_invites` table ✅
- Invite flow: owner invites by phone → staff accepts on first OTP ✅
- `require_role(*roles)` dependency in `api/deps.py` ✅
- Mobile Staff screen at `features/settings/presentation/staff_screen.dart` ✅
- New sales attributed to authenticated user (`cashier_id`) ✅
- `store_context.get_merchant_and_store()` — unified owner+staff context lookup ✅

### M3 — Customers Screen + Invoice Extension + Cost-Based Profit (~1 week)
- §1.6 build standalone Customers feature (`mobile/lib/features/customers/`) `[x] ✅` *(done)*
  - Backend: `CustomerOut` extended with M1 fields + `total_outstanding`; `GET /receivables/customers/{id}` detail endpoint
  - Mobile: schema v10 migration; `CustomersScreen` + `CustomerDetailScreen`; people icon in Debts header
- §C.2 extend Receivable with `invoice_number`, `payment_link`, `payment_provider_reference`, `created_by_user_id`, `sale_id`, wider status enum `[x] ✅` *(done)*
- §6.7 compute real profit using `cost_price` snapshot on sale_items `[x] ✅` *(done)*
- M3 stabilization pass (2026-04-23): fixed Sales "Today" KPI scoping to local-day records, projected `sales_local.note` in recent-sales query, and aligned reports KPI widget test with compact-currency UI output. `[x] ✅`

### M4 — Paystack Integration (~2–3 weeks)
The big one. §4.1 through §4.16.
- M4 Step 1 (2026-04-23) `[~] 🚧`: built Paystack connection settings slice:
  - backend `payment_provider_connections` table + owner-only APIs (`GET/PUT/DELETE /payments/paystack/connection`)
  - mobile `ConnectPaystackScreen` + Business Settings navigation entry
  - backend + mobile tests added and passing
  - stabilization sweep complete: `python -m pytest -q` (56 pass), `flutter analyze` (clean), `flutter test` (42 pass)
- M4 Step 8 (2026-04-24) `[x] ✅`: merchant-owned credential refactor:
  - merchant test/live Paystack credentials now stored encrypted at rest with backend verify-on-save
  - mobile Paystack settings now collect write-only secret keys and expose per-mode configured/verified status
  - payment initiation now uses merchant-specific secrets; Render env keys are non-production fallback only
  - webhooks now validate signatures against the payment’s stored merchant/mode snapshot rather than current connection mode
  - stabilization sweep: `python -m pytest -q backend/app/tests/test_auth.py backend/app/tests/test_crypto.py backend/app/tests/test_payment_settings.py backend/app/tests/test_payments_initiate.py backend/app/tests/test_paystack_webhooks.py` (31 pass), `flutter analyze` (clean), `flutter test test/features/connect_paystack_screen_test.dart` (3 pass)
- M4 Step 2 (2026-04-24) `[~] 🚧`: built initiation slice for receivable links:
  - backend Paystack client + `POST /payments/initiate` (`services/payment_service.py`)
  - pending `payments` row now created on initiation; receivable `payment_link` + `payment_provider_reference` updated
  - mobile Debt Detail page adds **Generate Link** action + link panel/copy button
  - stabilization sweep complete: `python -m pytest -q` (59 pass), `flutter analyze` (clean), `flutter test` (43 pass)
- M4 Step 3 (2026-04-24) `[~] 🚧`: webhook verification and settlement slice:
  - backend `POST /webhooks/paystack` with HMAC-SHA512 signature validation
  - webhook now double-verifies with Paystack `/transaction/verify/{reference}`
  - on verified success: payment marked `succeeded`, receivable settled, receivable repayment row created, audit log written
  - idempotent duplicate handling added at service layer
  - hardening completed: migration 010 adds unique payment reference constraint + webhook event idempotency table
  - stabilization sweep complete: `python -m pytest -q` (63 pass)
- M4 Step 4 (2026-04-24) `[~] 🚧`: pay-now initiation slice for sales (webhook later):
  - backend `POST /payments/initiate-sale` now creates pending `payments` rows linked to `sale_id`
  - sale initiation sets `sales.payment_status = pending_provider` and writes audit log entries
  - mobile Sales checkout adds **Generate Paystack Link** action for MoMo and link copy flow
  - stabilization sweep: `python -m pytest -q backend/app/tests/test_payments_initiate.py backend/app/tests/test_paystack_webhooks.py` (9 pass), `flutter analyze` (clean), `flutter test test/features/frontend_lifecycle_regression_test.dart` (2 pass)
- M4 Step 5 (2026-04-24) `[~] 🚧`: mobile sale payment-status polling/refresh slice:
  - backend `GET /sales/{sale_id}` endpoint added to support single-sale status checks
  - mobile Sales link dialog now supports **Check Status** polling (`pending_provider` / `succeeded` / `failed`) via `GET /sales/{sale_id}`
  - stabilization sweep: `python -m pytest -q backend/app/tests/test_sales_sync.py backend/app/tests/test_payments_initiate.py backend/app/tests/test_paystack_webhooks.py` (20 pass), `flutter analyze` (clean), `flutter test test/features/frontend_lifecycle_regression_test.dart test/features/inventory_archive_ui_test.dart` (5 pass)
- M4 Step 6 (2026-04-24) `[~] 🚧`: debt payment-status polling/refresh slice:
  - backend `GET /receivables/{receivable_id}` endpoint added for single-debt status checks
  - mobile Debt Detail payment-link panel now supports **Check Status** polling and server snapshot refresh (`open` / `partially_paid` / `settled` / `cancelled`)
  - debts refresh path now pulls server debt snapshot to keep `payment_link` and status transitions current
  - stabilization sweep: `python -m pytest -q backend/app/tests/test_receivables_sync.py backend/app/tests/test_payments_initiate.py backend/app/tests/test_paystack_webhooks.py` (19 pass), `flutter analyze` (clean), `flutter test test/features/debt_detail_screen_test.dart test/features/frontend_lifecycle_regression_test.dart` (3 pass)
- M4 Step 7 (2026-04-24) `[~] 🚧`: partial-payment hardening slice:
  - webhook settlement now applies **verified Paystack amount** (`amount_kobo`) instead of blindly using initiated amount
  - receivables now settle correctly for partial payments (outstanding reduced by verified amount; status moves to `partially_paid` when needed)
  - underpaid sale verifications now fail sale settlement (`sales.payment_status = failed`) instead of incorrectly marking success
  - stabilization sweep: `python -m pytest -q backend/app/tests/test_paystack_webhooks.py backend/app/tests/test_payments_initiate.py backend/app/tests/test_receivables_sync.py` (21 pass)
- M4 UX/UI stabilization sweep (2026-04-24) `[x] ✅`: navigation consistency + payment UI polish:
  - **Root fix**: `PAYMENT_CONFIG_ENCRYPTION_KEY` added to `.env` — this was the root cause of all key-save failures (backend was returning HTTP 503 `CryptoConfigError` on every save attempt)
  - **`connect_paystack_screen.dart`** fully rewritten: Test/Live mode tab toggle (`_ModeTab` widget), clearer status banner with connected/disconnected styling, per-mode configured/verified status rows (`_ModeStatusRow`), human-readable error messages (maps 503/502/400/401 → friendly copy), danger-styled disconnect button, confirmation dialog on disconnect
  - **`business_settings_sheet.dart`**: all `Navigator.of(context).maybePop()` → `context.pop()`; Paystack connection status badge wired via `paystackConnectionProvider` — shows connected/disconnected pill with active mode, and button label changes from "Connect Paystack" to "Manage Paystack" when connected
  - **Sales QR payment sheet**: `_PaystackQrSheet` widget added — shows checkout URL as scannable QR code (via `qr_flutter`), Copy Link, Open Link (via `url_launcher`), Check Status actions; "Send Paystack Payment Link" button shown for ALL payment methods in checkout sheet
  - **Navigation sweep**: all `Navigator.of(context).maybePop()` calls across the entire mobile codebase replaced with GoRouter `context.pop()` (or `Navigator.of(context).pop()` for screens opened via MaterialPageRoute). Files fixed: `connect_paystack_screen.dart`, `business_settings_sheet.dart`, `customer_detail_screen.dart`, `customers_screen.dart`, `staff_screen.dart`, `debt_detail_screen.dart`, `receive_repayment_screen.dart`; added `go_router` import where missing
  - **Router**: `/debts/:id` GoRoute added; `debt_detail_screen.dart` back-navigation converted to GoRouter
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
| `mobile/lib/features/settings/` | Staff screen (M2) and Paystack connection settings screen (M4 Step 1) are both built. |
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
| 2 | Customers | ✅ Done — M3 standalone screen built (`features/customers/`) |
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

BizTrack has the **foundation of the Ghana SME OS already working**: auth, tenancy via merchant+store, inventory with movement audit trail, sales, debts, expenses, reports, plus offline sync. M1-M3 are complete. M4 now includes Paystack connection, merchant-owned encrypted credentials with verify-on-save, receivable initiation+webhooks, sale/debt payment-link flows with webhook settlement, mobile payment-status polling for both flows, partial-payment hardening, and a full UX/navigation consistency sweep (all `maybePop` calls replaced with GoRouter `context.pop()`, QR checkout sheet in sales, Paystack status badge in Business Settings, human-readable error messages throughout settings); auth OTP is now locally generated/verified by BizTrack with Arkesel reduced to SMS transport. The next critical slice is notifications, then **M5** (WhatsApp/SMS receipts and reminders), then **M6** merchant validation and launch prep.

