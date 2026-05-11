# Debts Feature — Implementation Plan

Rebuilding the mobile Debts feature from scratch on top of the existing backend.

## Context

- Backend receivables + Paystack initiation + webhook settlement are **already implemented and ready to use** — no backend work needed for Phases 0–4.
- The previous mobile debts module was deleted in full (23 files). The app currently does not compile because `customers_screen.dart`, `customer_detail_screen.dart`, and `router.dart` still import the deleted files.
- Local SQLite tables (`customers_local`, `receivables_local`, `receivable_payments_local`) are still present in `app_database.dart` — schema is intact.
- Sync dispatcher already routes `customer.create`, `receivable.create`, `receivable_payment.create`.

## Design principles

- **Offline-first.** Every write goes to SQLite first, then enqueues a sync op. Reads come from SQLite. UI never blocks on network.
- **One file per concern.** No mega-files. Separate: model, API DTO, repository, provider, screen, form, sheet, widget.
- **Mirror the sales payment flow.** Paystack QR + share link reuses the exact pattern from `paystack_qr_sheet.dart` and `paystack_momo_sheet.dart` so the merchant has a consistent experience.
- **Design language.** Match dashboard / sales / inventory: forest-green hero, navy chips, `AppRadii.heroRadius` clipped surface, `AppShadows.subtle` cards, danger-soft / success-soft status pills.
- **Decimal money.** Store and transmit as `String` (e.g. `"125.50"`). Parse to minor units only for display math.

---

## Phase 0 — Unbreak the build (foundation only, no UI)

**Goal:** Restore the data + provider layer so `customers/` compiles and the app runs.

**Files to create:**

```
mobile/lib/features/debts/
├── data/
│   ├── debts_api.dart                          // HTTP client → /receivables endpoints
│   ├── debts_payments_api.dart                 // HTTP client → /payments/initiate (receivable)
│   └── models/
│       ├── local_debt_customer.dart            // SQLite row + JSON mappers
│       ├── local_receivable_record.dart        // open/settled debt row
│       ├── local_receivable_detail.dart        // customer + receivables aggregate
│       └── local_receivable_payment_record.dart // repayment history row
├── providers/
│   └── debts_providers.dart                    // debtsRepositoryProvider, debtsControllerProvider
└── data/
    └── debts_repository.dart                   // listCustomers, getCustomerById, createCustomer,
                                                // listReceivablesForCustomer, createReceivable,
                                                // recordRepayment, refresh, etc.
```

**Acceptance:** `flutter analyze` clean. App boots. Customers tab renders again (it'll just read from the restored repository). No new screens yet.

---

## Phase 1 — Debts list + create-debt flow

**Goal:** Merchant can see all open debts, search/filter, and create a new debt against an existing or newly-created customer.

**Files to create:**

```
mobile/lib/features/debts/presentation/
├── debts_screen.dart                           // SliverAppBar hero + tabs + list
├── utils/
│   ├── debts_ui_tokens.dart                    // colour/spacing constants reused across debts
│   └── debts_ui_utils.dart                     // money formatting, status → label, status → colour
└── widgets/
    ├── debts_header.dart                       // hero KPIs: total outstanding, customer count
    ├── debts_search_bar.dart                   // search by customer name / invoice
    ├── debts_tab_filter.dart                   // All | Open | Overdue | Settled
    ├── debts_empty_state.dart                  // "No debts yet" card
    ├── debt_list_tile.dart                     // single row in the list
    └── new_debt_sheet/                         // create-debt flow split across files
        ├── new_debt_sheet.dart                 // entry bottom sheet, hosts the steps
        ├── customer_picker_step.dart           // search + select customer (or "Add new")
        ├── customer_inline_create.dart         // mini form for new customer
        └── debt_form_step.dart                 // amount, due date, optional note
```

**Backend used:** `GET /receivables`, `GET /receivables/customers`, `POST /receivables/customers` (offline-queued), `POST /receivables` (offline-queued).

**Acceptance:**
- Tapping `+` opens the picker → select customer → fill amount + due date + note → save.
- Save writes to SQLite immediately, enqueues `receivable.create`, returns to the list.
- List shows the new debt with an "Unsynced" pill while pending, clears when synced.
- Filtering and search work locally without round-trips.

---

## Phase 2 — Debt detail + manual repayment (cash / momo / bank)

**Goal:** Tap a debt → see its full state → record an in-person repayment.

**Files to create:**

```
mobile/lib/features/debts/presentation/
├── debt_detail_screen.dart                     // top-level, composes the widgets below
└── widgets/
    ├── debt_balance_hero.dart                  // hero card: outstanding, original, status pill
    ├── debt_customer_summary.dart              // customer name, phone, call/whatsapp shortcuts
    ├── debt_meta_row.dart                      // invoice no., created, due date, days overdue
    ├── debt_payment_card.dart                  // single repayment history tile
    ├── debt_payments_history.dart              // list of debt_payment_card
    └── receive_payment_sheet/                  // split flow, no monolith
        ├── receive_payment_sheet.dart          // entry bottom sheet
        ├── receive_payment_amount_field.dart   // amount input with quick-fill (full / half)
        ├── receive_payment_method_selector.dart // cash | mobile money | bank transfer
        └── receive_payment_confirm_button.dart // submit + loading state
```

**Backend used:** `GET /receivables/{id}`, `POST /receivables/{id}/repayments` (offline-queued as `receivable_payment.create`), `POST /receivables/{id}/cancel`.

**Acceptance:**
- Detail screen renders balance hero, customer card, meta strip, payment history.
- "Receive payment" sheet validates amount ≤ outstanding, prevents overpayment.
- Repayment immediately decrements outstanding locally; status flips to `partially_paid` or `settled`.
- Cancel debt action (with confirm dialog) for `open` / `partially_paid` debts.

---

## Phase 3 — Paystack QR + share-link (mirror sales)

**Goal:** Generate a Paystack-hosted payment link for the customer. Cashier shows it as a QR or shares it via WhatsApp/SMS. Backend webhook auto-settles when paid.

**Files to create:**

```
mobile/lib/features/debts/presentation/widgets/
├── debt_payment_link_panel.dart                // entry button + state ("Generate" / "Active link")
├── debt_paystack_qr_sheet.dart                 // QR + copy + share + auto-poll status
│                                               // (mirrors paystack_qr_sheet.dart)
└── debt_payment_link_share.dart                // share-only entry point if a link already exists
```

**Backend used:** `POST /payments/initiate` (already returns `checkout_url`, `provider_reference`). Webhook handles settlement server-side. Polling: re-fetch `GET /receivables/{id}` every 3s while sheet open; outstanding updates → settled.

**Acceptance:**
- "Generate payment link" → API returns `checkout_url`, persisted on the receivable row.
- QR sheet shows the QR, the link text, Copy and Share buttons (same UX as sales).
- While open, polls `/receivables/{id}`; when `outstanding_amount = 0`, auto-dismisses with success.
- Sheet survives backgrounding (timer guard like sales).
- Cached link is reused on next open (don't re-initiate while one is active).

---

## Phase 4 — Reminders & polish

**Goal:** Set local reminders for outstanding debts. Final visual polish.

**Files to create:**

```
mobile/lib/features/debts/
├── data/
│   └── models/
│       └── local_debt_reminder.dart            // SQLite row: receivable_id, fire_at, message
├── data/
│   └── debt_reminders_repository.dart          // CRUD on a new local_debt_reminders table
├── providers/
│   └── debt_reminders_provider.dart            // exposes per-debt reminders + schedule action
└── presentation/widgets/
    ├── debt_reminder_row.dart                  // single reminder tile (time, status, cancel)
    ├── debt_reminders_section.dart             // list inside debt detail
    └── schedule_reminder_sheet.dart            // pick date+time, optional message
```

**Local DB migration:** bump `_schemaVersion` to 17, add `_createDebtRemindersSchema(db)`:
```
local_debt_reminders (
  id TEXT PK,
  receivable_id TEXT NOT NULL,
  fire_at INTEGER NOT NULL,
  message TEXT,
  status TEXT NOT NULL DEFAULT 'scheduled',  -- scheduled | fired | cancelled
  notification_id INTEGER NOT NULL,
  created_at INTEGER NOT NULL
)
```

**Wiring:** Use existing `flutter_local_notifications` (already imported by `notifications_service.dart`). Reminders are device-local only — no backend.

**Acceptance:**
- "Set reminder" button in debt detail.
- Sheet picks date + time + optional message ("Hi Ama, gentle reminder…").
- Schedules a local notification. Tapping it deep-links into the debt.
- Reminders list under each debt with cancel action.
- Stale banner, empty state, error retry all consistent with dashboard/sales/inventory.

---

## Phase 5 — Paystack MoMo push for debts

**Goal:** Cashier enters customer phone + network → Paystack pushes a prompt to the customer's handset (no smartphone needed). Mirror of sales `paystack_momo_sheet.dart`.

**Backend work required:**
- New endpoint `POST /payments/receivables/{id}/momo-charge` in `app/api/v1/payments.py`
- New method `PaymentService.initiate_receivable_momo_charge(...)` mirroring `initiate_sale_momo_charge`
- New endpoint `POST /payments/{id}/verify-receivable` (or extend the existing verify to handle receivable-linked payments)

**Mobile files:** `debt_paystack_momo_sheet.dart`, `debt_momo_phone_field.dart`, `debt_momo_provider_selector.dart`, `debt_momo_otp_field.dart`.

Required for full parity with the sales payment experience.

---

## Order of execution

| Phase | What ships | Build status | User-visible? |
|-------|------------|--------------|---------------|
| 0 | Data layer + providers | App compiles again | No |
| 1 | Debts list, create-debt | List + new-debt sheet | Yes |
| 2 | Detail + manual repay | Cash/MoMo/bank record | Yes |
| 3 | QR + share link | Paystack auto-settle | Yes |
| 4 | Reminders + polish | Production-ready | Yes |
| 5 | Direct MoMo push | Parity with sales | Yes |

Each phase ends with: `flutter analyze` clean, manual smoke test, screenshot review.

## Not in scope (now)

- Debt reminders via SMS (server-side).
- Bulk-import debts from CSV.
- Customer-facing portal.
- Aging report changes (already in `/reports`).
