# AI Integration Strategy — SikaBoafo

> **Document status:** Proposed — approved for Phase 1 implementation  
> **Last updated:** 2026-05-09  
> **Author:** Engineering + Product

---

## Philosophy

> "AI should make the merchant smarter, not replace their judgment."

The merchants using SikaBoafo are running real businesses — market stalls, small shops, kiosks. They know their customers by name and know when market days are. What they **don't** have is time to analyze data, and many lack the financial literacy to interpret raw numbers.

**That is the exact gap AI fills.**

### What AI must NOT do

- Make financial decisions on behalf of the merchant
- Auto-record sales, auto-adjust stock, or auto-create debts
- Require internet to function (must degrade gracefully offline)
- Be another complex thing to configure or set up
- Send raw customer personal data (names, phone numbers) to any external LLM API

### What AI SHOULD do

- Surface patterns the merchant would miss on their own
- Give advice in plain, clear English (short sentences, no jargon)
- Warn **before** something goes wrong, not after
- Feel like a knowledgeable business friend, not a robot
- Work silently in the background — the merchant should barely notice it exists until it says something important

---

## The Data Foundation

SikaBoafo already has excellent, clean, relational data for AI analysis:

| Data | Model | AI Signal |
|---|---|---|
| Every sale, with item, quantity, price, timestamp | `Sale`, `SaleItem` | Sales velocity, peak hours, trends |
| Every inventory movement | `InventoryMovement` | Depletion rate, restock timing |
| Item cost price | `Item.cost_price` | Actual profit margin per item |
| Customer debts and due dates | `Receivable`, `ReceivablePayment` | Collection risk, customer reliability |
| Operating expenses by category | `Expense` | Overhead burn, profit erosion |
| Payment method per sale | `Sale.payment_method_label` | Cash vs. digital payment pattern |
| Sales timestamps | `created_at` on `Sale` | Day-of-week, time-of-day patterns |

Most of the AI value comes from **aggregation and pattern recognition on this data** — not from neural networks or generative models.

---

## The 5 AI Features (Priority Order)

### Feature 1 — Restock Prediction ("Smart Restock Alerts")

**Problem:** A merchant gets a "Low Stock" notification when stock hits 2 units. That's too late — the supplier visit was yesterday.

**AI approach:** Calculates average daily sales velocity per item from `InventoryMovement` + `SaleItem`. Predicts how many days of stock remain at current burn rate. Triggers an alert with enough lead time to restock before stockout.

**Example notification:**
> "Indomie is moving fast — at this rate, you'll run out in **4 days**. You had 31 sales this month. Consider restocking before the weekend."

**Implementation:**
- Backend Celery/cron job — runs nightly per store
- Pure arithmetic — no LLM required
- Sends via existing `NotificationsService`
- Offline: device can run a simplified version using local SQLite movement data

**Trust level: HIGH** — Deterministic math on your own data. No hallucination risk.

---

### Feature 2 — Debt Collection Risk ("Customer Health Score")

**Problem:** Merchants extend credit without any way to know which customers are reliable payers.

**AI approach:** Computes a simple risk score per customer from `Receivable` + `ReceivablePayment`:
- Number of open debts
- Average days overdue
- Whether outstanding amount is growing over time
- Whether they pay in full or only partial amounts

Displayed as a **traffic-light indicator** (🟢 / 🟡 / 🔴) on the customer profile — no numeric score, no jargon, just a color and a one-line reason.

**Example:**
> 🔴 "This customer has 3 unpaid debts totalling ₵450. Last payment was 45 days ago."

**Implementation:**
- Computed server-side and synced to mobile
- Can also be computed locally in Dart from SQLite data (works offline)
- No LLM required

**Trust level: HIGH** — Fully deterministic.

---

### Feature 3 — Pricing Intelligence ("Is this price right?")

**Problem:** Merchants set prices by gut feel and rarely revisit them. Some items are being sold below cost without the merchant knowing.

**AI approach:** Cross-references `Item.cost_price` vs `Item.default_price`. Flags items with:
- Negative margin (selling below cost)
- Margin below a configurable threshold (e.g. < 10%)
- Price unchanged for 90+ days (may no longer reflect supplier price increases)

**Example (shown on inventory item card):**
> "⚠️ **Cooking Oil** — you're selling at ₵28 but your recorded cost is ₵25. That's only 11% margin. You may want to review this price."

**Implementation:**
- Computed entirely from existing item data
- No LLM, no network required
- Surface as a subtle flag on the inventory item card and a filter ("Show margin concerns")

**Trust level: HIGH** — Pure arithmetic.

---

### Feature 4 — Natural Language Daily Digest

**Problem:** Most micro-merchants don't read financial reports. A screen full of charts means nothing to someone who just wants to know "was today good?"

**AI approach:** Uses a lightweight LLM (Gemini Flash or GPT-4o mini) to convert the day's aggregated numbers from `reports_service.py` into 3–4 plain English sentences. Delivered as a push notification each evening, and displayed on the dashboard for the next morning.

**Example:**
> "Good day! You made **₵340** today — that's your best Tuesday this month. Malt was your top seller (12 units). Your expenses were ₵45, so your estimated profit is about ₵295. One customer (Kofi) still owes ₵80 from last week."

**Important:** The LLM only narrates numbers that your `reports_service.py` computed. It cannot invent or modify data. Prompt always instructs: "Summarize these numbers. Do not add any information not present in the data."

**Implementation:**
- Scheduled Celery task: runs at ~8 PM per store timezone
- Fetches summary from `reports_service.py` (aggregated, anonymized)
- Calls LLM API with a structured prompt template
- Stores the generated text in the DB (for audit + offline display)
- Sends via push notification

**Offline behavior:** Shows cached digest from the previous day.

**Trust level: HIGH** — LLM is narrating your numbers, not generating facts.

---

### Feature 5 — Business Q&A Chat ("Ask SikaBoafo")

**Problem:** A merchant wants to know "which product made me the most profit this month?" but doesn't know where to find it in the app.

**AI approach:** A simple chat interface in the "More" section. User asks a natural language question. Backend uses LLM function-calling to select the right read-only data function, executes it safely, and narrates the result.

**Example:**
> **User:** "Which item gave me the most profit last week?"  
> **AI:** "That was **Malt** — you sold 28 units at ₵20 each, and your cost price is ₵13. Estimated profit from Malt alone was **₵196** last week."

**Architecture — the key safety design:**

```
User question
    ↓
LLM (function-calling mode)
    ↓ selects from approved tools only
[get_top_items_by_profit(period)]  ← Python executes this
[get_expense_breakdown(month)]
[get_debt_summary()]
[get_stockout_forecast()]
[get_sales_summary(period)]
    ↓
LLM narrates the tool result
    ↓
Response shown to user
```

**The LLM never reads raw DB rows.** It only calls pre-defined, read-only Python functions that return aggregated data.

**Offline behavior:** Shows "Chat is available when connected to internet."

**Trust level: MEDIUM** — Safe by design (tool-use only), but requires a live internet connection.

---

## Guardrails: What AI Cannot Do

| Action | AI Permitted? | Reason |
|---|---|---|
| Read any store's aggregated data | ✅ Yes | Safe, read-only |
| Generate summaries and alerts | ✅ Yes | Narrating computed facts |
| Suggest restock quantities | ✅ Yes (labeled "Suggested") | Merchant confirms before acting |
| Auto-record a sale | ❌ Never | Financial record — must be human-initiated |
| Auto-adjust inventory stock | ❌ Never | Can cause permanent data corruption |
| Auto-write off a debt | ❌ Never | Legal and financial consequence |
| Send messages to a customer | ❌ Never | Privacy, relationship management |
| Predict exact future revenue | ❌ No | Too unreliable — can mislead business decisions |

**Rule of thumb:** AI can *suggest* or *summarize*. It can never *write* to financial records.

---

## Implementation Architecture

### Provider Recommendation

| Provider | Cost | Offline? | Notes |
|---|---|---|---|
| **Google Gemini Flash 2.0** | ~$0.001/1k tokens | No | ✅ Recommended — cheapest, strong Ghana infra |
| OpenAI GPT-4o mini | Cheap | No | Good alternative, strong function-calling |
| Anthropic Claude Haiku | Cheap | No | Best at following structured prompt instructions |
| On-device (Gemma 2B) | Free | ✅ Yes | Only for simple pattern detection (Phase 4+) |

**Estimated cost:** Under $10/month for 1,000 active merchants (daily digests + occasional Q&A).

### Stack Position

```
Mobile App (Flutter)
    │
    │  User receives push / taps "Ask SikaBoafo"
    ▼
FastAPI Backend  ──── existing stack
    │
    ├── reports_service.py       (already exists — provides numbers)
    ├── inventory_service.py     (already exists — provides stock data)
    ├── receivables_service.py   (already exists — provides debt data)
    │
    └── [NEW] app/services/ai_service.py
            ├── summarise_day(store_id, date) → str
            ├── answer_question(store_id, question) → str
            └── predict_stockout(store_id) → List[StockoutPrediction]
```

### New Files Required

```
backend/
  app/
    services/
      ai_service.py          # LLM orchestration + tool definitions
    api/
      v1/
        ai.py                # POST /ai/ask, GET /ai/digest

mobile/
  lib/
    features/
      ai/
        presentation/
          chat_screen.dart   # "Ask SikaBoafo" UI
        providers/
          ai_providers.dart  # Riverpod providers for digest + chat
```

---

## Data Privacy Rules

These are non-negotiable:

1. **Never send raw customer names or phone numbers to any LLM API** — use anonymized IDs or aggregate counts only
2. **Never send individual sale records** — only aggregated summaries (totals, counts, percentages)
3. **Store all AI-generated content** (daily digests, question answers) in the database for audit purposes
4. **Add a data notice in Settings:** "SikaBoafo uses AI to analyze your business performance. No personal customer information is shared with AI services."
5. **Merchants opt out at any time** — a toggle in Settings disables all AI features

---

## Offline Behavior Summary

| Feature | Online | Offline |
|---|---|---|
| Restock alerts | ✅ Full backend prediction | ⚡ Simplified local velocity from SQLite |
| Debt risk score | ✅ Full backend score | ⚡ Computed locally from SQLite receivables |
| Margin alerts | ✅ Backend-computed | ⚡ Computed locally from SQLite item data |
| Daily Digest | ✅ Fresh LLM summary | 📦 Shows cached digest from last sync |
| Q&A Chat | ✅ Full LLM | 🚫 "Available when connected" |

---

## Phased Rollout Plan

### Phase 1 — No LLM Required (Implement Now)
**Features:** Restock prediction, Debt risk score, Margin alerts  
**Cost:** $0 — pure backend logic  
**Goal:** Prove value; measure merchant engagement with AI alerts

### Phase 2 — LLM Summaries
**Features:** Daily Digest push notification, Weekly business summary on dashboard  
**Cost:** ~$2–5/month at scale  
**Dependency:** Phase 1 engagement metrics look positive

### Phase 3 — Conversational AI
**Features:** "Ask SikaBoafo" chat in More section  
**Cost:** ~$0.01–0.05 per conversation  
**Dependency:** Phase 2 live and stable

### Phase 4 — Predictive Intelligence
**Features:** Seasonal demand detection (market days, payweeks in Ghana), category-level forecasting  
**Dependency:** Minimum 6 months of sales history per store  
**Note:** This is when on-device models become worth evaluating

---

## Related Documents

- [`architecture.md`](../architecture.md) — System architecture and sync design
- [`docs/architecture/sync_rules.md`](../architecture/sync_rules.md) — Offline sync rules
- [`docs/product/pricing_notes.md`](pricing_notes.md) — Pricing strategy notes
