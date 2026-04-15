# BizTrack GH — Detailed To-Do Roadmap

This is the master execution file.

It includes:
- immediate work
- startup setup work
- MVP implementation work
- post-MVP work
- future integrations and long-term ideas

The goal is to make sure we do not forget anything important.

**Terms:** **Payment stages** 1–3 = Paystack rollout (see `README.md` / `architecture.md`). **Product milestones** M2–M5 = broader feature waves in `project_description.md`. Digital collection is **Paystack-only** for BizTrack GH.

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
- [ ] copy mockup image to `docs/mockups/biztrack_gh_mockups_v1.png`
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

- [ ] review generated mockups screen by screen
- [ ] name each mockup screen explicitly
- [ ] create screen list from mockups:
  - [ ] splash / welcome
  - [ ] login / OTP
  - [ ] dashboard
  - [ ] record sale
  - [ ] choose payment method
  - [ ] manage debts
  - [ ] inventory
  - [ ] receive payment
  - [ ] daily report
- [ ] document which mockup parts are reference only vs required MVP behavior
- [ ] define design tokens
  - [ ] colors
  - [ ] spacing
  - [ ] typography
  - [ ] icon set
  - [ ] card styles
  - [ ] input styles
  - [ ] button hierarchy
- [ ] define reusable components
  - [ ] primary button
  - [ ] secondary button
  - [ ] summary stat card
  - [ ] quick action card
  - [ ] list tile
  - [ ] empty state
  - [ ] offline banner
  - [ ] sync status pill
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
- [ ] create Python virtual environment inside `backend/.venv` *(run locally: `python -m venv .venv`)*
- [ ] activate virtual environment
- [x] create `requirements.txt` or `pyproject.toml`
- [x] install FastAPI and core dependencies *(see `requirements.txt`)*
- [x] install DB driver
- [x] install Alembic
- [x] install Redis client *(dependency present; wire in §4.4)*
- [ ] install worker dependencies *(deferred to Celery/Dramatiq in §4.4)*
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
- [ ] set up PostgreSQL locally *(use Docker: `infra/docker/docker-compose.local.yml` or install Postgres)*
- [x] configure DB session
- [x] configure SQLAlchemy models **with sync fields on all offline-capable writes** (`source_device_id`, `local_operation_id`, timestamps as in `architecture.md` §7.3)
- [x] configure Alembic
- [x] create initial migration(s); revision `001` uses `metadata.create_all` once; later use autogenerate
- [ ] run `alembic upgrade head` *(requires Postgres running + `.env`)*
- [x] create seed script in `backend/scripts/seed_dev.py`
- [x] add sample merchant/store/items seed data
- [ ] review indexes for list/hot paths *(add when sync/report endpoints land)*

#### 4.4 Redis and workers
- [ ] set up Redis locally *(compose file includes Redis)*
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
- [x] initialize Flutter app in `mobile/` *(Dart sources + `pubspec`; run `flutter create .` locally for `android/` / `ios/` — see `mobile/README.md`)*
- [ ] run `flutter pub get` *(on dev machine after Flutter install)*
- [ ] set up environments/flavors *(baseline: `--dart-define=API_BASE_URL=...` in `AppConfig`)*
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

- [x] define auth domain model *(phone normalization + OTP provider adapter + token shape)*
- [x] implement phone number input screen
- [x] implement OTP request endpoint
- [x] implement OTP verification endpoint
- [x] create token issuance flow
- [x] add secure token storage on mobile
- [x] create login state restoration
- [x] build merchant onboarding flow
- [x] capture business name
- [x] capture business type/category
- [x] create first store automatically
- [x] create logout flow

---

## 7. Merchant/store domain

### Purpose
Represent the merchant cleanly from the start.

- [ ] create merchant entity/model
- [ ] create store entity/model
- [ ] support single-store MVP cleanly
- [ ] design multi-store compatibility without exposing it in MVP UI
- [ ] store default currency and locale info
- [ ] store simple location metadata

---

## 8. Inventory module

### Purpose
Give merchants visibility into what they have and what is running out.

- [ ] define item entity/model
- [ ] define inventory balance model
- [ ] define inventory movement model
- [ ] implement create item flow
- [ ] implement edit item flow
- [ ] implement stock-in flow
- [ ] implement stock adjustment flow
- [ ] implement low stock threshold
- [ ] show inventory list
- [ ] show low stock widgets on dashboard
- [ ] create inventory history / audit trail
- [ ] support search/filter later if needed

---

## 9. Sales module

### Purpose
This is the highest-frequency flow and must feel excellent.

- [ ] define sale model
- [ ] define sale item model
- [ ] build quick sale entry screen from mockup reference
- [ ] allow item selection
- [ ] allow quantity entry
- [ ] allow unit price override where appropriate
- [ ] allow payment method tagging
- [ ] save sale locally first
- [ ] update local inventory immediately
- [ ] queue sale for sync
- [ ] sync sale to backend
- [ ] show sale history
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

- [ ] define expense model
- [ ] create expense categories
- [ ] build add expense screen
- [ ] save expense locally first
- [ ] queue expense for sync
- [ ] sync expense to backend
- [ ] show expense history
- [ ] decide edit/delete policy

---

## 11. Receivables / debt module

### Purpose
Help the merchant track who owes them and when money comes back.

- [ ] define customer model
- [ ] define receivable model
- [ ] define receivable payment model
- [ ] build customer creation flow
- [ ] build add debt flow
- [ ] capture customer name and phone
- [ ] capture due date
- [ ] support partial repayment
- [ ] support full repayment
- [ ] show outstanding balances
- [ ] show debt status clearly
- [ ] create debt detail screen
- [ ] create receive repayment screen from mockup direction
- [ ] add future reminder hooks
- [ ] add future SMS/WhatsApp reminder plan

---

## 12. Dashboard and reports

### Purpose
Turn raw records into immediate clarity for the merchant.

- [ ] implement dashboard summary cards
- [ ] calculate today's sales
- [ ] calculate today's expenses
- [ ] calculate today's estimated profit (`sales − expenses` per `project_description.md` §8.9)
- [ ] show low stock summary
- [ ] show debt summary
- [ ] show recent activity
- [ ] build daily report screen
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

- [ ] define local SQLite schema
- [ ] define sync queue table
- [ ] define sync status enum
- [ ] define device ID strategy
- [ ] define local operation ID strategy
- [ ] save all core write actions locally first
- [ ] detect connectivity changes
- [ ] process queued operations in order
- [ ] make sync operations idempotent
- [ ] handle retry behavior
- [ ] display sync states in UI
- [ ] support manual retry on failed sync
- [ ] implement conflict handling per `architecture.md` §8.3 (MVP: server wins, client refresh)
- [ ] test no-network scenarios thoroughly
- [ ] test reconnect scenarios thoroughly

---

## 14. Payment engine — Paystack (current and future)

### Purpose
Prepare the system properly so **Paystack** collection and webhooks are safe and idempotent.

#### 14.1 Current foundation
- [ ] define internal payment domain model
- [ ] record payment method labels on sales
- [ ] support cash
- [ ] support manually recorded mobile money
- [ ] support manually recorded bank transfer
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
- [ ] backend integration tests
- [ ] mobile widget tests where useful
- [ ] mobile integration tests for core flows
- [ ] offline sync test scenarios
- [ ] payment webhook test scenarios
- [ ] dashboard calculation validation tests
- [ ] inventory consistency tests
- [ ] debt calculation tests
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
- [x] backend setup *(mostly done — finish Postgres + `alembic upgrade`)*
- [ ] DB/migrations/seed *(verify locally)*
- [x] mobile setup *(§5 scaffold — run `flutter create` + `pub get` locally)*
- [ ] auth + onboarding
- [ ] inventory foundation
- [ ] sales flow
- [ ] expense flow
- [ ] debt flow
- [ ] dashboard + reports
- [ ] offline sync hardening
- [ ] admin basics
- [ ] Paystack integration (payment stage 2, then 3)
- [ ] post-MVP improvements (product milestones M2+)

---

## 22. Definition of done for MVP

The MVP is done when:
- [ ] merchant can sign in with phone and OTP
- [ ] merchant can set up business profile
- [ ] merchant can create items
- [ ] merchant can record sales quickly
- [ ] merchant can record expenses
- [ ] merchant can manage debts/repayments
- [ ] merchant can view dashboard summaries
- [ ] merchant can use app while offline for core non-payment actions
- [ ] app syncs reliably when back online
- [ ] data is stored correctly in backend
- [ ] setup and run instructions are clear in README
