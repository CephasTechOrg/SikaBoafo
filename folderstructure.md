# SikaBoafo — Complete Folder Structure

This file defines the **startup-ready folder structure** for the project.

The goal is to make the repository easy to understand, easy to scale, and clear enough that future features do not create chaos.

---

## 1. Top-level structure

Repository root (clone root; e.g. `SikaBoafo/`):

```text
./
├── README.md
├── project_description.md
├── architecture.md
├── folderstructure.md
├── todo.md
├── .gitignore
├── docs/
├── mobile/
├── backend/
├── admin/
├── scripts/
├── infra/
└── .github/
```

**Terminology:** **Payment stages** 1–3 = Paystack rollout. **Product milestones** M2–M5 = broader waves in `project_description.md`.

### What each top-level folder is for

- `docs/` -> product docs, architecture notes, UI assets, ADRs, API notes
- `mobile/` -> Flutter application
- `backend/` -> FastAPI application
- `admin/` -> internal admin dashboard in Next.js
- `scripts/` -> local helper scripts, seeding, export/import tools
- `infra/` -> Docker, deployment, infrastructure templates, env examples
- `.github/` -> CI/CD workflows, repo templates

---

## 2. Docs structure

```text
docs/
├── mockups/
│   └── sikaboafo_mockups_v1.png
├── product/
│   ├── user_flows.md
│   ├── screen_specs.md
│   └── pricing_notes.md
├── architecture/
│   ├── decisions/
│   ├── api_contracts/
│   ├── sync_rules.md
│   ├── payment_flows.md
│   └── id_strategy.md
└── research/
    └── ghana_market_notes.md
```

### Notes

- `docs/mockups/` stores the generated UI references.
- `sikaboafo_mockups_v1.png` is the visual starting point for implementation.
- `docs/product/` contains product-specific docs and user journeys.
- `docs/architecture/` contains deeper implementation notes that may grow beyond the main architecture file.

---

## 3. Mobile structure

```text
mobile/
├── pubspec.yaml
├── analysis_options.yaml
├── assets/
│   ├── icons/
│   ├── images/
│   └── fonts/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart
│   │   ├── router.dart
│   │   ├── theme/
│   │   └── env/
│   ├── core/
│   │   ├── constants/
│   │   ├── errors/
│   │   ├── utils/
│   │   ├── services/
│   │   └── widgets/
│   ├── data/
│   │   ├── api/
│   │   ├── local/
│   │   ├── models/
│   │   └── repositories/
│   ├── domain/
│   │   ├── entities/
│   │   ├── repositories/
│   │   └── usecases/
│   ├── features/
│   │   ├── auth/
│   │   ├── onboarding/
│   │   ├── dashboard/
│   │   ├── sales/
│   │   ├── expenses/
│   │   ├── inventory/
│   │   ├── receivables/
│   │   ├── reports/
│   │   ├── payments/
│   │   ├── sync/
│   │   └── settings/
│   └── shared/
│       ├── providers/
│       ├── components/
│       └── formatters/
├── test/
├── integration_test/
└── android/ ios/
```

### Why this mobile structure is good

- feature-based, so screens and logic stay grouped
- still keeps shared layers for consistency
- supports clean growth into payments and sync logic
- easy to onboard new developers into

### Important mobile notes

- SQLite implementation belongs under `lib/data/local/`
- sync queue and local operation models belong under `features/sync/` and/or `data/local/`
- reusable UI components belong under `shared/components/`
- app theme and design tokens belong under `app/theme/`

---

## 4. Backend structure

```text
backend/
├── app/
│   ├── main.py
│   ├── api/
│   │   ├── deps.py
│   │   ├── router.py
│   │   └── v1/
│   │       ├── auth.py
│   │       ├── merchants.py
│   │       ├── stores.py
│   │       ├── items.py
│   │       ├── sales.py
│   │       ├── expenses.py
│   │       ├── receivables.py
│   │       ├── reports.py
│   │       ├── payments.py
│   │       ├── sync.py
│   │       └── webhooks.py
│   ├── core/
│   │   ├── config.py
│   │   ├── security.py
│   │   ├── logging.py
│   │   └── constants.py
│   ├── db/
│   │   ├── base.py
│   │   └── session.py
│   ├── models/
│   ├── schemas/
│   ├── repositories/
│   ├── services/
│   ├── domain/
│   ├── integrations/
│   │   ├── paystack/
│   │   ├── sms/
│   │   └── whatsapp/
│   ├── workers/
│   ├── tasks/
│   ├── events/
│   └── tests/
├── alembic/
│   ├── env.py
│   ├── script.py.mako
│   └── versions/
├── scripts/
│   ├── seed_dev.py
│   ├── create_admin.py
│   └── reset_local_db.py
├── alembic.ini
├── requirements.txt
├── pyproject.toml
├── Dockerfile
└── .env.example
```

Database migrations live under **`alembic/versions/`** (standard Alembic layout). Point `alembic.ini` at `app` models as usual; do not use a separate `app/db/migrations/` tree unless you standardize that across the team.

### Why this backend structure is good

- API layer stays separated from business logic
- integrations are isolated cleanly
- workers and tasks do not pollute route logic
- scripts folder makes local setup easier
- scales well as the product grows

### Key backend notes

- `api/` only handles request/response concerns
- `services/` handles business logic
- `repositories/` handles DB access
- `events/` and `tasks/` support async processing
- `integrations/paystack/` contains **Paystack-only** API and webhook handling

---

## 5. Admin structure

```text
admin/
├── package.json
├── next.config.js
├── src/
│   ├── app/
│   ├── components/
│   ├── features/
│   │   ├── auth/
│   │   ├── merchants/
│   │   ├── payments/
│   │   ├── sync/
│   │   ├── support/
│   │   └── audit/
│   ├── lib/
│   └── styles/
└── public/
```

### Admin purpose

The admin app is for internal operations, not merchants.

Use it for:

- merchant lookup
- payment reconciliation
- sync failures
- support review
- audit logs
- future issue management

---

## 6. Infra structure

```text
infra/
├── docker/
│   ├── docker-compose.local.yml
│   └── nginx/
├── env/
│   ├── backend.env.example
│   ├── mobile.env.example
│   └── admin.env.example
├── aws/
│   ├── networking/
│   ├── database/
│   ├── cache/
│   └── app/
└── monitoring/
    ├── alerts.md
    └── dashboards/
```

### Infra notes

- start simple locally with Docker Compose for DB and Redis
- production infra can mature later
- keep example env files versioned, but never real secrets

---

## 7. Scripts structure

```text
scripts/
├── bootstrap_project.sh
├── bootstrap_project.ps1
├── copy_mockups.sh
├── run_local_backend.sh
├── run_local_worker.sh
├── run_local_mobile.md
└── seed_notes.md
```

### Script purpose

These are helper files to make startup easier and keep repetitive commands out of people’s heads.

---

## 8. GitHub structure

```text
.github/
├── workflows/
│   ├── backend-ci.yml
│   ├── mobile-ci.yml
│   └── admin-ci.yml
├── ISSUE_TEMPLATE/
└── pull_request_template.md
```

---

## 9. Recommended repo root docs

Keep these root files visible and maintained:

- `README.md` -> how to start and understand the repo (includes **what to build first**)
- `project_description.md` -> what we are building and why
- `architecture.md` -> technical direction, system logic, and **§4.6–§4.8 data/code/comment discipline**
- `folderstructure.md` -> startup-ready structure and explanations
- `todo.md` -> execution roadmap, **§3.5 execution spine**, and backlog

Code should follow the **layering** shown in this file and the **data-first** rules in `architecture.md` so folders do not fill with one-off shortcuts.

---

## 10. Mockup asset rule

The generated mockup image should stay in:

```text
docs/mockups/sikaboafo_mockups_v1.png
```

This gives the team a clear UI reference from the start.

If more mockups are created later, name them like:

- `sikaboafo_mockups_v2.png`
- `record_sale_flow_v1.png`
- `dashboard_refinement_v1.png`

---

## 11. Final summary

This structure is designed to be:

- easy to start with
- clear for future contributors
- clean enough for startup growth
- organized around the real product lifecycle

It is intentionally structured so future additions like:

- Paystack payment flows
- QR collection
- notifications
- analytics
- voice input
- finance features

can be added without turning the repo into a mess.
