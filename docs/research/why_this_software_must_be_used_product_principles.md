# Why This Software Must Be Used (BizTrack GH)

## Purpose of this document

This document exists to keep one thing clear at all times:

> If a merchant can ignore this app, we have failed.

This is not just a feature checklist. It is a **product truth guide**.
Every future feature, UI change, or integration must answer:

> “Does this make the user feel stupid for not using the app?”

---

# Core Principle

## The app must protect or increase money

Merchants do not care about:
- organization
- clean UI
- technology

They care about:
- money
- speed
- stress reduction

### Product rule

Every core screen must answer at least one:
- “Am I making money?”
- “Am I losing money?”
- “Where is my money going?”

If not → remove or redesign.

---

# 1. Money Clarity (Non-negotiable)

## Goal
The user must understand their financial state in seconds.

## Implementation rules

- Dashboard must show:
  - Today’s sales
  - Today’s expenses
  - Today’s profit (simple: sales - expenses)

- Profit must be visually dominant
- No navigation required to see it

## Future enforcement

- Add comparison:
  - vs yesterday
  - vs last week

- Add signals:
  - "You are doing better than yesterday"
  - "Profit is dropping"

---

# 2. Loss Detection (Critical Feature)

## Goal
The app must warn the user when money is being lost.

## Examples

- “Expenses are too high today”
- “Stock is reducing without matching sales”
- “You are selling but profit is low”

## Implementation notes

- Requires backend aggregation + rules
- Should trigger simple alerts, not complex charts

## Rule

> If the app knows something is wrong and says nothing → failure

---

# 3. Speed Above Everything

## Goal
Recording a sale must be faster than writing in a notebook.

## Target

- 2–5 taps per sale
- < 3 seconds interaction time

## Required features

- Recent items
- Favorite items
- Repeat last sale
- Large touch targets

## Rule

> If a user hesitates while using the app → redesign the flow

---

# 4. Habit Formation (Daily Use)

## Goal
User must open the app every day without being forced

## Mechanisms

### Daily summary

At end of day:

- show:
  - total sales
  - total expenses
  - profit

- add insight:
  - "You did better than yesterday"

### Morning trigger (future)

- "You have unpaid debts"
- "Low stock items"

## Rule

> If user can skip a day without consequence → weak product

---

# 5. Debt Pressure System

## Goal
Make unpaid money visible and uncomfortable

## Required behavior

- Show total outstanding debts clearly
- Highlight overdue debts

## Examples

- “Kojo owes you GHS 120 (3 days overdue)”
- “You have GHS 500 unpaid”

## Future integrations

- SMS reminders
- WhatsApp reminders

## Rule

> Money owed must feel real, not hidden

---

# 6. Inventory as Loss Prevention

## Goal
Prevent missed sales and hidden loss

## Required signals

- Low stock alerts
- Fast-moving items tracking

## Example

- “Bread is running out — you may lose sales tomorrow”

## Rule

> Inventory is not just tracking — it is protection

---

# 7. Offline Trust

## Goal
User must trust the app in poor network conditions

## Required UX

- Show sync state clearly
- Show offline mode clearly
- Never block user action due to network

## Messaging

- “Works without internet”
- “Your data is safe”

## Rule

> If the app feels unreliable → user returns to notebook

---

# 8. Simplicity Over Features

## Goal
Reduce thinking required to use the app

## Rules

- No long forms
- No unnecessary fields
- No complex settings in MVP

## Guideline

> If a feature requires explanation → it is too complex

---

# 9. Emotional Design (Hidden Layer)

## Goal
Make the app feel like a business partner

## Techniques

- Use simple language
- Show insights, not raw data
- Highlight wins
n
## Example

- “You made more money today than yesterday”

## Rule

> The app should feel helpful, not technical

---

# 10. What This App Is NOT

Do NOT turn this into:

- accounting software
- complex ERP
- spreadsheet replacement

This app is:

> A fast, daily money tool

---

# Final Product Test

Before shipping any feature, ask:

1. Does this save time?
2. Does this make or protect money?
3. Does this reduce stress?
4. Will the user notice if it is missing?

If the answer is NO → do not build it.

---

# Final Reminder

> The goal is not to build features.

> The goal is to build something a trader cannot live without.

---

# One-line Product Truth

> If they don’t use it, they lose money.

