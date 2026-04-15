# BizTrack GH — Detailed Project Description

## 1. Project summary

BizTrack GH is a **mobile-first, offline-first financial inventory system** for micro, small, and informal businesses in Ghana. It helps merchants record sales, track inventory, manage expenses, track customer debts, understand profit, and gradually move into digital payment collection and merchant finance.

The product is designed for real-world small business conditions:
- limited or unstable internet
- mixed payment methods (cash, mobile money, bank transfer)
- low time tolerance during busy trading hours
- simple operational habits built around notebooks, memory, calculators, and WhatsApp

This is **not** just a bookkeeping app. It is a **merchant operating system** that becomes the daily control layer for a business.

---

## 2. Why this product exists

Small merchants often do business without reliable records. That creates practical daily pain:
- they do not know actual profit
- they do not know which products are making or losing money
- they lose stock without noticing
- they forget who owes them
- they cannot build trustworthy business history
- they cannot easily move into formal digital payments or future financing

BizTrack GH exists to remove that uncertainty and make the merchant feel in control every day.

---

## 3. Product vision

Build the most trusted mobile business system for everyday merchants in Ghana.

The app should let a trader or shop owner:
- record a sale in seconds
- see stock levels clearly
- know daily sales, expenses, and estimated profit
- track debts and repayments
- eventually request and confirm digital payments via Paystack
- build a clean operational history that can unlock future services

### Vision statement

> Every small merchant should be able to run their entire business confidently from their phone.

---

## 4. Product principles

### 4.1 Mobile-first
The main product is the mobile app. The merchant should not need a laptop or desktop to run the business.

### 4.2 Offline-first
Core business actions must work even without internet. The app saves locally first and syncs later.

### 4.3 Fast interaction
Busy merchants do not have patience for long forms. Common flows should be 2–5 taps when possible.

### 4.4 Trustworthy records
The app must be reliable enough that a merchant trusts it more than paper.

### 4.5 Built for real business behavior
The product should support how people actually work now, then gently improve that workflow.

### 4.6 Start narrow, design wide
The first release should be focused and simple, but the architecture should support payments, QR flows, multi-staff, analytics, and future finance.

### 4.7 Build quality and pace
Delivery is **intentionally step by step**: stabilize **data structures** (Postgres + SQLite + sync fields) before chasing feature count. Prefer clear layers, explicit types, and **comments where behavior is non-obvious** (sync, money, webhooks)—see `architecture.md` §4.6–§4.8 and `README.md` (“If you are starting the project now”).

---

## 5. Target users

### Primary users
- provision shop owners
- mini-mart operators
- kiosks and corner stores
- market traders
- pharmacies and cosmetics sellers
- spare parts sellers
- food vendors
- salon and barber shop owners
- wholesalers and neighborhood retailers

### Secondary users
- store assistants and cashiers
- shop supervisors
- owners of multiple small stores
- internal support/admin teams
- future financial partners reviewing merchant business quality

---

## 6. Core business jobs to solve

The product must help the merchant answer these questions at any time:
- What did I sell today?
- What did I spend today?
- What is my estimated profit today?
- Which items are running low?
- Who owes me money?
- Which customers paid me?
- Which payment method was used?
- Which products move fastest?
- Is my business improving over time?

---

## 7. Product story

Think of a merchant named Ama.

Ama runs a small provisions shop. Every day she sells drinks, bread, milk, rice, toiletries, and phone credit. Some customers pay cash, some send mobile money, and some take goods on credit and promise to pay later. At the end of the day she is tired, but she still does not know:
- how much profit she made
- which products sold best
- whether stock is disappearing
- who still owes her money

BizTrack GH becomes Ama's business brain.

When she sells bread, she records it instantly.
When she buys more rice, she records the restock.
When someone owes her, she records the debt.
When internet is bad, the app still works.
When internet returns, her data syncs safely.
Later, when Paystack collection is enabled, customers can pay more easily and the sale can be matched automatically from verified webhooks.

The product gives Ama clarity, confidence, and control.

---

## 8. MVP scope

The MVP should focus on the highest-frequency merchant actions.

### 8.1 Authentication and onboarding
- phone number sign-up/login
- OTP verification
- merchant profile setup
- business name
- business category/type
- store creation for first store

### 8.2 Dashboard
- today's sales total
- today's expenses total
- today's estimated profit
- low stock summary
- debt summary
- recent activity
- fast action entry points

### 8.3 Sales
- quick sale entry
- item selection
- quantity selection
- unit price or override where allowed
- payment method selection
- note field if needed
- sale confirmation
- inventory reduction when linked item exists
- sale history list

### 8.4 Expenses
- add expense
- category
- amount
- note
- timestamp
- expense history

### 8.5 Inventory
- create item
- edit item
- stock quantity
- stock-in / restock
- stock adjustment
- low stock threshold
- low stock alerts
- inventory list and search

### 8.6 Receivables / debts
- create customer
- create debt/receivable
- due date
- partial payment
- full payment
- debt status
- outstanding balance views

### 8.7 Reports
- daily report
- weekly report
- monthly report
- top-selling items
- payment method breakdown
- debt summary

### 8.8 Offline-first foundation
- local save before server sync
- sync queue
- sync status indicators
- background retry

### 8.9 MVP metric definitions (clarity for merchants)

**Estimated profit** (dashboard and reports, MVP): for a given period (e.g. “today” in the store’s timezone), `estimated_profit = total_sales − total_expenses`. This is a simple operating view—not full cost-of-goods sold, tax, or formal accounting. COGS and richer profit definitions can come in a later milestone.

---

## 9. Post-MVP product milestones

These are **product milestones (M2–M5)**. They are intentionally numbered separately from **payment stages 1–3** in §10 so “M3” is never confused with “payment stage 3.”

### Milestone M2 — collaboration and reporting depth
- staff roles
- multi-user support
- multi-store support foundation
- customer reminders
- better analytics
- export/share reports

### Milestone M3 — Paystack live in the product
- Paystack integration (initiate collection from the app; customer completes payment via Paystack-supported channels in Ghana)
- webhook-driven payment confirmation (backend is source of truth)
- digital receipts
- payment history and reconciliation in-app and in admin

### Milestone M4 — richer checkout and operations
- QR and other Paystack-supported checkout patterns where applicable
- merchant-presented payment flows where the stack allows
- supplier payouts (as product + Paystack capabilities mature)
- stronger analytics
- voice-assisted data entry
- merchant financing readiness

### Milestone M5 — formalization and scale
- advanced lending integrations
- marketplace / supplier ordering
- cashier mode / POS peripherals
- tax and accounting exports

---

## 10. Payment roadmap summary (Paystack)

**Paystack** is the sole digital payment provider for BizTrack GH: charges, references, and **verified webhooks** on the backend. Stage 1 does not call Paystack; stages 2–3 do.

### Payment stage 1 — recorded payment method only
The merchant records whether payment was cash, mobile money, or transfer. No live Paystack transaction.

### Payment stage 2 — Paystack collection
The merchant can start a **Paystack** payment from the app when online. The customer pays through Paystack-supported methods. The backend confirms success or failure using **Paystack webhooks** (and related verification), then updates internal `payments` and the linked sale or receivable.

### Payment stage 3 — deep Paystack-backed operations
Payment history, settlements, refunds where supported, reconciliation, Paystack-backed QR or other flows as available, supplier payouts, and future finance features.

---

## 11. Why offline-first matters

Offline mode is not for online mobile money transactions themselves. It is for **business continuity**.

Examples:
- record a cash sale when there is no internet
- record an expense while traveling
- record stock movement in a poor network area
- keep the dashboard usable without blocking the merchant

The goal is simple: **the merchant should never stop working because the network is bad**.

---

## 12. UI source of truth

The generated mockups are part of the project source-of-truth for initial interface direction.

Mockup asset location (repository root):

- `docs/mockups/biztrack_gh_mockups_v1.png`

These mockups guide:
- dashboard layout
- login and onboarding direction
- sale recording flow
- debt management flow
- inventory screen layout
- payment and daily report screen direction

They are not final design specifications, but they are the visual baseline for implementation.

---

## 13. Success criteria

### Merchant success
- can record a sale in seconds
- can understand daily profit quickly
- can trust stock numbers
- can track debts accurately
- can continue working when offline

### Product success
- daily active usage from real merchants
- repeat usage after first week
- low abandonment during sale flow
- good sync reliability
- clean foundation for payment rollout

---

## 14. Non-goals for the first release

The first release should **not** try to become all of these at once:
- full accounting suite
- lending platform
- tax engine
- full ERP
- advanced BI platform
- hardware-heavy POS system

Those can come later. The first release must win daily merchant trust.

---

## 15. Final summary

BizTrack GH is a merchant operating system disguised as a simple mobile app.

It starts with:
- sales
- expenses
- inventory
- debts
- reports
- offline reliability

Then expands into:
- Paystack-powered digital collection
- QR and deeper checkout where Paystack supports it
- reconciliation
- analytics
- future finance

The project wins if merchants feel:
> “I finally know what is happening in my business.”
