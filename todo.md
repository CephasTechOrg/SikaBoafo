# SikaBoafo — Detailed To-Do Roadmap

This is the master execution file.

It includes:

- immediate work
- startup setup work
- MVP implementation work
- post-MVP work
- future integrations and long-term ideas

The goal is to make sure we do not forget anything important.

**Terms:** **Payment stages** 1–3 = Paystack rollout (see `README.md` / `architecture.md`). **Product milestones** M2–M5 = broader feature waves in `project_description.md`. Digital collection is **Paystack-only** for SikaBoafo.

**How we build:** Step by step, **data model before features**, thin API layers, and comments where behavior is non-obvious (`architecture.md` §4.6–§4.8). See **README → “If you are starting the project now”** for the canonical first steps.

---

## 0. Repository and documentation foundation

### Purpose

Before building features, make the repo a reliable source of truth.

- [x] place updated docs in repo root
- [x] add `project_description.md`
- [x] add `architecture.md`
- [x] add `folderstructure.md`
- [x] add `todo.md`
- [x] add root `README.md`
- [x] create `docs/mockups/` directory
- [ ] copy mockup image to `docs/mockups/sikaboafo_mockups_v1.png`
- [ ] decide whether to keep mockups in repo or external design tool as well
- [x] create `docs/product/` notes area
- [x] create `docs/architecture/` notes area
- [ ] create ADR process for future architecture decisions

---

## 1. Product foundation and validation

### Purpose

Confirm who exactly we are building for first and what pain matters most.

- [ ] finalize product name
- [ ] finalize one-line product promise
- [ ] define first merchant segment for launch
- [ ] define first city/market target
- [ ] create merchant interview guide
- [ ] interview at least 10 merchants
- [ ] record exact phrases merchants use to describe their problems
- [ ] validate whether inventory or debt pain is stronger in first segment
- [ ] validate whether merchants already use smartphones daily
- [ ] define MVP success criteria
- [ ] define day-7 and day-30 retention goals
- [ ] define first monetization assumptions

---

## 2. Design system and UI planning

### Purpose

Turn mockups into implementation-ready UI direction.

- [x] review generated mockups screen by screen _(used `mobile/UI MockUps` to guide dashboard, inventory, sales, debts, and report polish)_
- [ ] name each mockup screen explicitly
- [ ] create screen list from mockups:
  - [ ] splash / welcome
  - [x] login / OTP
  - [x] dashboard
  - [x] record sale
  - [x] choose payment method
  - [x] manage debts
  - [x] inventory
  - [x] receive payment
  - [x] daily report _(report UI baseline in app; deeper reporting remains in §12)_
- [ ] document which mockup parts are reference only vs required MVP behavior
- [x] define design tokens
  - [x] colors
  - [x] spacing
  - [x] typography
  - [ ] icon set
  - [x] card styles
  - [x] input styles
  - [x] button hierarchy
- [x] define reusable components
  - [x] primary button
  - [x] secondary button
  - [x] summary stat card
  - [x] quick action card
  - [x] list tile
  - [x] empty state
  - [ ] offline banner
  - [x] sync status pill
- [ ] write `docs/product/screen_specs.md`
- [ ] write `docs/product/user_flows.md`

---

## 3. Startup-ready repository structure

### Purpose

Create the real folder structure before feature work starts.

- [x] create `mobile/`
- [x] create `backend/`
- [x] create `admin/`
- [x] create `docs/`
- [x] create `scripts/`
- [x] create `infra/`
- [x] create `.github/workflows/`
- [x] align repo with `folderstructure.md`
- [x] add `.gitignore`
- [ ] add editor config if needed
- [ ] add code formatting config
- [x] document primary key and ID strategy (`docs/architecture/id_strategy.md`) per `architecture.md` §4.6

**Done so far:** top-level apps, `docs/`, `infra/`, `.github/`, inner layout per `folderstructure.md`. **§4:** backend skeleton, models, Alembic `001`, seed script — run Postgres + `alembic upgrade head` locally to finish DB setup.

---

## 3.5 What to start first (execution spine)

After §0–§3 are underway or done, use this order so **data structures** stay clean; full narrative is in `README.md` (“If you are starting the project now”).

1. **§4.1–§4.2** — Backend app skeleton only (config, health, API versioning).
2. **§4.3** — **Database first:** models + Alembic migrations; **sync/idempotency fields** on every offline-capable entity (`architecture.md` §7.3, §8). **Primary key strategy** decided and documented.
3. **§4.3** — Seed script; prove the schema with realistic rows.
4. **§5** — Mobile shell; **SQLite + sync queue schema** aligned to server models before most screens.
5. **§6–§7** — Auth and merchant/store.
6. **§8–§12** — Inventory → sales → expenses → debts → dashboard/reports (MVP).
7. **§13** — Offline/sync hardening (idempotency, retries, conflicts per `architecture.md` §8.3).
8. **§15 then §14** — Admin when useful; **Paystack** only after capture and sync are trustworthy.

Skipping a solid §4.3 to “move faster” usually means **rewrites**—not efficiency.

---

## 4. Backend setup and startup flow

### Purpose

Set up the backend properly so future work sits on a stable base.

#### 4.1 Environment and dependencies

- [x] initialize backend project
- [ ] create Python virtual environment inside `backend/.venv` _(run locally: `python -m venv .venv`)_
- [ ] activate virtual environment
- [x] create `requirements.txt` or `pyproject.toml`
- [x] install FastAPI and core dependencies _(see `requirements.txt`)_
- [x] install DB driver
- [x] install Alembic
- [x] install Redis client _(dependency present; wire in §4.4)_
- [ ] install worker dependencies _(deferred to Celery/Dramatiq in §4.4)_
- [x] install testing dependencies (`requirements-dev.txt`)
- [x] install linting/formatting dependencies (`ruff` in dev requirements)

#### 4.2 Config and app skeleton

- [x] create `app/main.py`
- [x] create config module
- [x] create settings loading from env
- [x] create app router structure
- [x] create health endpoint
- [x] create versioned API base (`/api/v1/…`)

#### 4.3 Database and migrations

- [x] set up PostgreSQL locally _(local Postgres reachable via `.env` and migration run validated)_
- [x] configure DB session
- [x] configure SQLAlchemy models **with sync fields on all offline-capable writes** (`source_device_id`, `local_operation_id`, timestamps as in `architecture.md` §7.3)
- [x] configure Alembic
- [x] create initial migration(s); revision `001` uses `metadata.create_all` once; later use autogenerate
- [x] run `alembic upgrade head` _(validated to `002 (head)`)_
- [x] create seed script in `backend/scripts/seed_dev.py`
- [x] add sample merchant/store/items seed data
- [ ] review indexes for list/hot paths _(add when sync/report endpoints land)_

#### 4.4 Redis and workers

- [ ] set up Redis locally _(compose file includes Redis)_
- [ ] choose Celery or Dramatiq
- [ ] configure broker connection
- [ ] create worker entrypoint
- [ ] test a sample async task

#### 4.5 Dev experience

- [x] add structured logging
- [x] add local Docker support (`infra/docker/docker-compose.local.yml`)
- [ ] add Makefile or task runner if desired
- [x] document exact backend startup commands in README (`backend/README.md`)

---

## 5. Mobile app setup and startup flow

### Purpose

Set up the Flutter app correctly before feature work.

#### 5.1 App initialization

- [x] initialize Flutter app in `mobile/` _(Dart sources + `pubspec`; run `flutter create .` locally for `android/` / `ios/` — see `mobile/README.md`)_
- [ ] run `flutter pub get` _(on dev machine after Flutter install)_
- [ ] set up environments/flavors _(baseline: `--dart-define=API_BASE_URL=...` in `AppConfig`)_
- [x] set up Riverpod
- [x] set up GoRouter
- [x] set up Dio
- [x] set up secure local token storage
- [x] set up SQLite package and **schema** (`local_meta` + **sync_queue**; domain tables later) aligned to idempotency in `architecture.md` §4.6 / `id_strategy.md`
- [x] set up app theming
- [ ] set up error handling and logging

#### 5.2 UI shell

- [x] create base app shell
- [x] create auth flow shell
- [x] create dashboard navigation shell
- [x] create shared components folder
- [x] create sync status UI component

#### 5.3 Mobile dev notes

- [x] document Flutter startup commands in README
- [x] document emulator/device setup notes if needed
- [ ] decide whether to support tablet layouts later

---

## 6. Authentication and onboarding

### Purpose

Give merchants a simple, trustworthy entry into the app.

- [x] status note: OTP auth flow + onboarding flow implemented end-to-end (backend + mobile)
- [x] status note: login/OTP UI refreshed against mockup references and polished for responsive phone layouts
- [x] document **PIN + OTP split** (daily login vs SMS cost) — `docs/auth/pin-and-otp-flow.md`

- [x] define auth domain model _(phone normalization + OTP provider adapter + token shape)_
- [x] implement phone number input screen
- [x] implement OTP request endpoint
- [x] implement OTP verification endpoint
- [x] implement **PIN login** endpoint _(phone + PIN, no SMS)_
- [x] implement **PIN set / reset** endpoint _(authenticated; after OTP for recovery)_
- [x] create token issuance flow
- [x] add secure token storage on mobile
- [x] create login state restoration
- [x] build merchant onboarding flow
- [x] capture business name
- [x] capture business type/category
- [x] create first store automatically
- [x] create logout flow
- [x] mobile: **Sign in** = phone + PIN; **Create account / Forgot PIN** = OTP then set PIN

---

## 7. Merchant/store domain

### Purpose

Represent the merchant cleanly from the start.

- [x] create merchant entity/model
- [x] create store entity/model
- [ ] support single-store MVP cleanly
- [ ] design multi-store compatibility without exposing it in MVP UI
- [ ] store default currency and locale info
- [x] store simple location metadata

---

## 8. Inventory module

### Purpose

Give merchants visibility into what they have and what is running out.

- [x] define item entity/model
- [x] define inventory balance model
- [x] define inventory movement model
- [x] implement create item flow
- [x] implement edit item flow _(mobile edit dialog now updates locally first and syncs through `sync_queue`)_
- [x] implement stock-in flow
- [x] implement stock adjustment flow
- [x] implement low stock threshold _(persisted on item create/update)_
- [x] show inventory list
- [x] show low stock widgets on dashboard
- [x] create inventory history / audit trail _(movement rows stored locally + backend)_
- [ ] support search/filter later if needed

---

## 9. Sales module

### Purpose

This is the highest-frequency flow and must feel excellent.

- [x] define sale model
- [x] define sale item model
- [x] build quick sale entry screen from mockup reference _(functional baseline UI in app)_
- [x] allow item selection
- [x] allow quantity entry
- [ ] allow unit price override where appropriate
- [x] allow payment method tagging
- [x] save sale locally first
- [x] update local inventory immediately
- [x] queue sale for sync
- [x] sync sale to backend
- [x] show sale history _(recent sales list with sync status)_
- [ ] support note on sale if needed
- [ ] define future digital receipt placeholder

### UX quality tasks for sales flow

- [ ] minimize number of taps
- [ ] make common items easy to select later
- [ ] ensure large touch targets
- [ ] support fast repeat usage

---

## 10. Expense module

### Purpose

Capture money leaving the business clearly.

- [x] define expense model
- [x] create expense categories
- [x] build add expense screen
- [x] save expense locally first
- [x] queue expense for sync
- [x] sync expense to backend
- [x] show expense history
- [ ] decide edit/delete policy

---

## 11. Receivables / debt module

### Purpose

Help the merchant track who owes them and when money comes back.

- [x] define customer model
- [x] define receivable model
- [x] define receivable payment model
- [x] build customer creation flow
- [x] build add debt flow
- [x] capture customer name and phone
- [x] capture due date
- [x] support partial repayment
- [x] support full repayment
- [x] show outstanding balances
- [x] show debt status clearly
- [x] create debt detail screen
- [ ] create receive repayment screen from mockup direction
- [ ] add future reminder hooks
- [ ] add future SMS/WhatsApp reminder plan

---

## 12. Dashboard and reports

### Purpose

Turn raw records into immediate clarity for the merchant.

- [x] implement dashboard summary cards _(UI shell + backend summary API wiring for key totals done)_
- [x] calculate today's sales
- [x] calculate today's expenses
- [x] calculate today's estimated profit (`sales − expenses` per `project_description.md` §8.9)
- [x] show low stock summary
- [x] show debt summary
- [x] show recent activity
- [x] build daily report screen _(visual baseline report screen with live summary metrics; deeper time-range reporting still pending below)_
- [ ] build weekly summary
- [ ] build monthly summary
- [ ] build top-selling items report
- [ ] build payment method breakdown
- [ ] build debt aging summary
- [ ] add export/share later

---

## 13. Offline-first engine

### Purpose

Make the app reliable in poor network conditions.

- [x] define local SQLite schema
- [x] define sync queue table
- [x] define sync status enum _(pending/sending/applied/duplicate/failed/conflict tracked locally and surfaced in UI)_
- [x] define device ID strategy
- [x] define local operation ID strategy
- [x] save all core write actions locally first _(inventory + sales + expense + debt writes)_
- [x] detect connectivity changes _(backend reachability polling + automatic sync attempts on reconnect in app shell state)_
- [x] process queued operations in order
- [x] make sync operations idempotent
- [x] handle retry behavior
- [x] display sync states in UI _(live sync pill with pending/failed/offline/synced states)_
- [x] support manual retry on failed sync
- [x] implement conflict handling per `architecture.md` §8.3 (MVP: server wins, client refresh)
- [ ] test no-network scenarios thoroughly
- [ ] test reconnect scenarios thoroughly

---

## 14. Payment engine — Paystack (current and future)

### Purpose

Prepare the system properly so **Paystack** collection and webhooks are safe and idempotent.

#### 14.1 Current foundation

- [ ] define internal payment domain model
- [x] record payment method labels on sales
- [x] support cash
- [x] support manually recorded mobile money
- [x] support manually recorded bank transfer
- [ ] support `pending_payment` state for future payment requests

#### 14.2 Paystack integration

- [ ] create Paystack integration module in backend
- [ ] define transaction initialization endpoint
- [ ] define mobile app payment start flow
- [ ] create callback/webhook endpoint
- [ ] verify webhook authenticity securely
- [ ] map Paystack reference to internal payment record
- [ ] mark payment success only from verified backend event
- [ ] update sale status when payment is confirmed
- [ ] handle failed/cancelled/expired payments
- [ ] create reconciliation job
- [ ] build admin payment review screen

#### 14.3 Future payment features

- [ ] customer payment request initiated by merchant
- [ ] in-app checkout via Paystack (mobile money / cards as Paystack enables)
- [ ] digital receipts
- [ ] payment history screen
- [ ] refunds flow
- [ ] QR payment screen
- [ ] merchant-presented QR code
- [ ] customer scans QR code and pays
- [ ] receivable repayment via digital payment
- [ ] supplier payout workflows
- [ ] settlement dashboard
- [ ] future finance rails for loans/repayments

---

## 15. Admin dashboard

### Purpose

Give the internal team visibility and support tools.

- [ ] initialize Next.js admin app
- [ ] add secure admin auth
- [ ] merchant search page
- [ ] merchant detail page
- [ ] payment reconciliation page
- [ ] sync failures page
- [ ] debt review page
- [ ] audit log viewer
- [ ] support notes feature
- [ ] issue escalation tools
- [ ] feature flags later if needed

---

## 16. Notifications and reminders

### Purpose

Keep merchants informed and support habit formation.

- [ ] define notification model if needed server-side
- [ ] in-app low stock alerts
- [ ] debt due reminders
- [ ] debt overdue reminders
- [ ] daily summary reminders
- [ ] payment status alerts
- [ ] sync failed alerts
- [ ] push notifications later
- [ ] SMS integration later
- [ ] WhatsApp reminders later

---

## 17. Security and compliance baseline

### Purpose

Protect merchant data and payment flows.

- [ ] define auth security model
- [ ] protect secrets properly
- [ ] secure admin endpoints
- [ ] verify all payment webhooks
- [ ] add rate limiting where needed
- [ ] add audit logging
- [ ] define backup strategy
- [ ] define restore/recovery plan
- [ ] review data retention policy later

---

## 18. Testing and quality

### Purpose

Make sure the app is trustworthy enough for daily business use.

- [ ] backend unit tests
- [x] backend integration tests _(sync + reports endpoint suites pass, including duplicate-replay consistency check in `test_sync_report_consistency.py`)_
- [ ] mobile widget tests where useful
- [ ] mobile integration tests for core flows
- [x] offline sync test scenarios _(queue-runner status transitions + local-first repository persistence tests added and passing)_
- [ ] payment webhook test scenarios
- [x] dashboard calculation validation tests _(report summary/insights/recent-activity tests + sync-replay consistency assertion)_
- [x] inventory consistency tests _(sales/inventory sync tests cover stock mutation, idempotency, and conflict protection)_
- [x] debt calculation tests _(receivable repayment tests cover partial/full repayment and overpayment rejection)_
- [ ] smoke tests for startup scripts

---

## 19. Deployment and operations

### Purpose

Make the project startup-ready, not just code-ready.

- [ ] define local environment setup
- [ ] define staging environment
- [ ] define production environment
- [ ] configure CI for backend
- [ ] configure CI for mobile
- [ ] configure CI for admin
- [ ] configure database backups
- [ ] configure error monitoring
- [ ] configure logs and alerts
- [ ] document release process

---

## 20. Future product expansion backlog

### Purpose

Keep long-term ideas visible without distracting the MVP.

- [ ] voice-assisted sale entry
- [ ] favorite items / fast repeat sale buttons
- [ ] barcode scanning later
- [ ] printer support later
- [ ] staff permissions and cashier mode
- [ ] multi-store UI
- [ ] supplier ordering workflows
- [ ] accounting exports
- [ ] tax-related exports later
- [ ] merchant performance insights
- [ ] financing readiness score
- [ ] lending partner integrations
- [ ] customer-facing payment link flows
- [ ] richer QR checkout experiences

---

## 21. Execution order summary

Align day-to-day work with **§3.5** and `README.md` (“If you are starting the project now”); this list is the same story in checklist form.

### Best build order

- [x] repo/docs foundation
- [x] backend setup _(Postgres + Alembic upgrade validated locally)_
- [ ] DB/migrations/seed _(migrations verified locally; seed verification still pending in this pass)_
- [x] mobile setup _(§5 scaffold — run `flutter create` + `pub get` locally)_
- [x] auth + onboarding
- [x] inventory foundation
- [x] sales flow
- [x] expense flow
- [x] debt flow
- [x] dashboard + reports
- [x] offline sync hardening
- [ ] admin basics
- [ ] Paystack integration (payment stage 2, then 3)
- [ ] post-MVP improvements (product milestones M2+)

---

## 22. Definition of done for MVP

The MVP is done when:

- [x] merchant can sign in with phone + **PIN** for daily use _(OTP only for first-time / recovery — see `docs/auth/pin-and-otp-flow.md`)_
- [x] merchant can set up business profile
- [x] merchant can create items
- [x] merchant can record sales quickly
- [x] merchant can record expenses
- [x] merchant can manage debts/repayments
- [x] merchant can view dashboard summaries
- [x] merchant can use app while offline for core non-payment actions _(covered by local-first repository tests for sales/expenses/debts)_
- [x] app syncs reliably when back online _(covered by sync queue runner transition tests and backend replay/idempotency tests)_
- [x] data is stored correctly in backend _(covered by backend sync + reports consistency and per-domain integration tests)_
- [x] setup and run instructions are clear in README _(root runbook + backend/mobile startup guides + USB debug docs)_
