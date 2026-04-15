# BizTrack GH — Project Architecture

## 1. Architecture goals

The architecture must support:
- mobile-first product usage
- offline-first reliability
- fast daily transactions
- trustworthy records
- clean Paystack rollout (payment stages 2–3)
- scale from MVP to startup-ready platform

The system should be simple enough to ship early but strong enough that we do not have to rebuild the foundations later.

---

## 2. Recommended stack

### Mobile app
- Flutter
- Riverpod
- GoRouter
- Dio
- SQLite
- flutter_secure_storage (or equivalent secure token storage)

### Backend
- FastAPI
- SQLAlchemy 2.x
- Alembic
- PostgreSQL
- Redis
- Celery or Dramatiq

### Admin / internal web
- Next.js
- TypeScript

### Infrastructure
- AWS
- S3 for file storage
- RDS for PostgreSQL
- ElastiCache Redis or managed Redis equivalent
- CloudWatch / logging stack

### Payments
- **Paystack** — sole digital payment provider (Ghana): charges, customer checkout, and server-side verification via **Paystack webhooks**.

---

## 3. High-level system overview

```text
Flutter Mobile App
   |
   | HTTPS / JSON
   v
FastAPI Backend
   |
   +--> PostgreSQL (system of record)
   +--> Redis (cache / queues / worker broker)
   +--> Worker processes (notifications, reconciliations, reports)
   +--> S3 (receipts, exports, future uploads)
   +--> Paystack integration
   +--> Admin Dashboard (Next.js)
```

---

## 4. Core architecture principles

### 4.1 Offline-first capture
The mobile app captures and stores business actions locally first.

### 4.2 Server-authoritative reconciliation
The backend is the final trusted source after sync and verification.

### 4.3 Clear domain boundaries
Each business area should have clean module boundaries.

### 4.4 Event-driven side effects
Important actions should create events so async processing is clean and safe.

### 4.5 Payment rail is separate from business logic
Paystack helps process payments, but our backend remains the owner of:
- sales records
- payment state
- matching and reconciliation
- reporting

### 4.6 Data-first development (do not skip this)

Build **slow enough** that structures stay coherent. Rushing without fixing the schema creates duplicate logic and risky migrations.

- **Model before wide API surface:** define PostgreSQL tables, constraints, indexes, and relationships **before** filling in dozens of endpoints. Adjust with Alembic migrations.
- **Syncable entities from day one:** any row that can originate offline must carry **`device_id`**, **`local_operation_id`** (or equivalent), and timestamps needed for ordering and audit (`§7.3`, `§8`). Adding these later is painful.
- **Mobile SQLite mirrors server shape** for synced aggregates: same field names and types where possible; document mapping in one place (repository or mapper layer).
- **Identifiers:** pick a **single strategy** for primary keys (e.g. UUID for distributed-friendly IDs) and document it (`docs/architecture/id_strategy.md`).
- **Enums and labels:** payment method labels, sync states, receivable statuses—use **shared constants** (Python `Enum` / DB check constraints / Dart enums) so strings do not drift between mobile, API, and DB.

### 4.7 Clean, efficient implementation

- **Thin HTTP layer:** route handlers validate input, call a service, return a response.
- **Explicit types:** type hints in Python; strong typing in Dart; Pydantic at API boundaries.
- **Efficiency where it matters:** optimize **hot paths**—sale creation, sync batch apply, dashboard aggregates—with indexes and query shape; avoid N+1 queries in list endpoints.
- **One path for invariants:** e.g. “sale reduces stock” lives in the sales/inventory service, not duplicated in mobile and server with subtle differences.

### 4.8 Comments and in-code documentation

- Prefer **why** and **invariants** over narrating what the code literally does.
- **Always worth a short note:** idempotency (`local_operation_id` handling), money and rounding, Paystack webhook ordering/duplicates.
- **Docstrings:** use on public service methods and non-obvious domain rules; skip boilerplate on trivial getters.
- **Do not** comment out dead code—delete it; git has history.

---

## 5. Mobile architecture

### 5.1 Mobile layers

Recommended layering:

```text
presentation/
application/
domain/
data/
core/
```

### presentation
Screens, widgets, forms, navigation, visual state.

### application
State management, use cases, orchestration between UI and data.

### domain
Core entities and business rules.

### data
Repositories, API clients, local DB adapters, DTO mapping.

### core
Constants, utilities, shared helpers, theme, errors.

---

### 5.2 Local-first strategy with SQLite

SQLite is used on-device for:
- sales recorded locally
- expenses recorded locally
- inventory cache
- debt cache
- sync queue
- sync status
- pending payment references
- user/session cache where appropriate

### Why SQLite is required
The merchant must still be able to use the app when:
- internet is weak
- internet disappears temporarily
- APIs are slow
- the merchant is in a market with unstable signal

### Important clarification
SQLite is **not** for processing online mobile money payments directly.
It is for storing local business actions so the app remains usable.

---

### 5.3 Sync engine

Each local action creates:
- local record
- sync queue item
- sync state

### Sync states
- pending
- syncing
- synced
- failed
- conflict

### Example: sale recorded offline
1. merchant taps “Confirm Sale”
2. sale saves to SQLite immediately
3. local inventory updates immediately
4. UI confirms success instantly
5. sync queue stores the pending operation
6. when connection is available, mobile app sends operation to backend
7. backend validates and persists the sale
8. local record updates to synced

---

## 6. Backend architecture

### 6.1 Backend layers

```text
api/          -> route handlers
schemas/      -> request/response validation
domain/       -> domain entities and business rules
services/     -> orchestration and business workflows
repositories/ -> DB access logic
models/       -> ORM models
integrations/ -> Paystack, SMS, WhatsApp, etc.
workers/      -> async jobs
core/         -> config, security, logging, shared helpers
```

---

### 6.2 Domain modules

Recommended module boundaries:
- auth
- merchants
- stores
- items
- inventory
- sales
- expenses
- customers
- receivables
- payments
- reports
- notifications
- sync
- audit
- admin

---

### 6.3 Service responsibilities

### Auth service
- OTP request and verification
- token issuing
- session validation

### Merchant service
- merchant creation
- business metadata
- store setup

### Inventory service
- stock movement rules
- threshold alerts
- adjustments

### Sales service
- sale creation
- line item handling
- inventory deduction
- payment-method tagging

### Expense service
- expense recording
- categories
- reporting contribution

### Receivables service
- create debt
- partial/full repayment
- debt status changes

### Payments service
- payment initiation
- reference mapping
- webhook verification
- payment status changes
- reconciliation

### Reporting service
- dashboard summaries
- daily/weekly/monthly reports
- product summaries
- debt aging

### Sync service
- sync endpoint logic
- idempotency
- conflict handling rules

### Notification service
- reminders
- low stock notifications
- summary alerts

---

## 7. Database architecture

### 7.1 System of record
PostgreSQL is the primary source of truth for synced and verified records.

### 7.2 Important database concerns
- transactional consistency
- auditability
- idempotent sync processing
- payment reconciliation
- future analytics support

### 7.3 Core entities

### users
- id
- phone_number
- role
- is_active
- created_at

### merchants
- id
- business_name
- business_type
- owner_user_id
- created_at

### stores
- id
- merchant_id
- name
- location
- timezone
- is_default

### items
- id
- store_id
- name
- sku (optional)
- category
- default_price
- low_stock_threshold
- is_active

### inventory_balances
- id
- item_id
- quantity_on_hand
- updated_at

### inventory_movements
- id
- item_id
- store_id
- movement_type
- quantity
- reason
- reference_type
- reference_id
- created_at

### sales
- id
- store_id
- customer_id (nullable)
- total_amount
- payment_method_label
- payment_status
- source_device_id
- local_operation_id
- created_at

### sale_items
- id
- sale_id
- item_id
- quantity
- unit_price
- line_total

### expenses
- id
- store_id
- category
- amount
- note
- source_device_id
- local_operation_id
- created_at

### customers
- id
- store_id
- name
- phone_number
- created_at

### receivables
- id
- store_id
- customer_id
- original_amount
- outstanding_amount
- due_date
- status
- created_at

### receivable_payments
- id
- receivable_id
- amount
- payment_method_label
- created_at

### payments
- id
- sale_id (nullable)
- receivable_payment_id (nullable)
- provider (MVP digital rail: `paystack`)
- provider_reference
- amount
- currency
- status
- initiated_at
- confirmed_at
- raw_provider_payload

### sync_operations
- id
- device_id
- local_operation_id
- entity_type
- entity_id
- action_type
- status
- processed_at

### audit_logs
- id
- actor_user_id
- action
- entity_type
- entity_id
- metadata
- created_at

---

## 8. Offline sync and idempotency design

This is one of the most important parts of the architecture.

### 8.1 Why idempotency matters
If the app retries a sync request because the network fails, the backend must not create duplicate sales or duplicate expenses.

### 8.2 Strategy
Each write operation should carry:
- device_id
- local_operation_id
- timestamp
- payload checksum if needed later

The backend checks whether the same local operation has already been processed.

If yes:
- return the previously accepted result

If no:
- process and store it

### 8.3 Sync conflict policy (MVP default)

For the same entity, if the server has already accepted a conflicting update (rare in single-device MVP; more relevant with multi-device later), the **server state wins**. The client should mark the local row as **conflict**, surface a short message, and **refresh from the server** (replace local copy with server snapshot). Manual merge is out of scope for MVP.

---

## 9. Payment engine architecture (Paystack)

Use **payment stage 1 / 2 / 3** in docs and planning. Do not use “Phase 2” for payments—that label is reserved for **product milestones** (M2–M5) in `project_description.md`.

### 9.1 Payment stages

### Payment stage 1 — recorded payment labels only
The merchant records that a sale was paid by:
- cash
- mobile money
- bank transfer

No Paystack API call; `payments` rows for digital completion are not required for these sales.

### Payment stage 2 — Paystack collection
When online, the app can initiate collection through **Paystack** (backend creates the transaction / reference; mobile follows your chosen Paystack flow). Recommended flow:

1. mobile app asks backend to create a Paystack-backed payment intent (amount, metadata, reference)
2. backend creates the Paystack transaction and stores a pending `payments` row (`provider = paystack`)
3. mobile app presents Paystack checkout / authorization to the payer
4. Paystack sends webhook (and any redirect callbacks you use only as UX hints, not as proof)
5. backend **verifies** the webhook (signature, idempotency) and updates payment status
6. backend links final payment status to sale or receivable repayment
7. app syncs and reflects final result

### Payment stage 3 — deep Paystack-backed operations
- payment history and admin reconciliation
- digital receipts
- refunds where Paystack supports them
- QR or other Paystack-supported checkout patterns
- supplier payouts and future finance rails as the product matures

---

### 9.2 Important payment rule
The mobile app must never be the final authority for Paystack payment completion.

The backend must confirm payment from **verified Paystack webhooks** (and internal idempotent processing) and then mark the payment as final.

---

## 10. Reporting engine

Reports should initially be computed server-side from clean records.

**Estimated profit (MVP):** for the selected period and store timezone, `estimated_profit = total_sales − total_expenses`. This matches `project_description.md` §8.9 and is not full COGS or tax accounting.

Required outputs:
- daily sales total
- daily expenses total
- estimated daily profit
- low stock count
- debt outstanding total
- payment method mix
- top-selling items
- debt aging summary

For mobile speed, selected snapshots can be cached locally after sync.

---

## 11. Notifications architecture

Notification sources:
- low stock threshold crossed
- debt due soon
- debt overdue
- payment success/failure
- sync failure
- daily summary reminder

Notification channels:
- in-app first
- push notifications later
- SMS/WhatsApp later

---

## 12. Security architecture

Minimum security baseline:
- secure OTP flow
- token-based auth
- encrypted transport over HTTPS
- Paystack webhook signature verification
- environment-based secrets management
- audit logs for sensitive operations
- admin role protection
- database backups
- rate limiting for public endpoints

---

## 13. Deployment architecture

### Environments
- local
- staging
- production

### Suggested deployment approach
- backend containerized
- PostgreSQL managed service
- Redis managed or isolated service
- worker service deployed separately
- admin app deployed independently
- mobile app releases through Play Store / App Store test tracks

---

## 14. UI and design asset placement

The visual baseline mockups belong inside docs and should be treated as design references.

Asset location:

- `docs/mockups/biztrack_gh_mockups_v1.png`

These assets should guide implementation until refined Figma or detailed screen specs exist.

---

## 15. Final architecture summary

The architecture is intentionally designed so that:
- merchants can always record business activity
- the app feels fast on mobile
- the backend remains financially trustworthy
- Paystack can be deepened (stages 2–3) without redesigning core business entities
- the product can grow from MVP to startup-grade platform without throwing away the foundations
