# Paystack Integration Reference for BizTrack GH

## Purpose

This document defines the **correct, complete, and realistic payment architecture** for BizTrack GH.

It ensures:

- we do not make wrong assumptions
- we build a system that works in Ghana
- we clearly separate recording vs verification

---

# 🔥 0. Payment Modes in BizTrack GH (CRITICAL)

BizTrack GH supports **three payment types**:

## 1. Cash Payment

- Customer pays physically
- Merchant confirms manually
- System records payment
- ❌ Not verified

---

## 2. External Payment (MoMo / Bank Transfer)

- Customer pays outside BizTrack
- Merchant confirms manually
- System records payment
- ❌ Not verified

---

## 3. Verified Digital Payment (Paystack)

- Customer pays through BizTrack (QR / link / MoMo checkout)
- Backend verifies with Paystack
- System records payment
- ✅ Verified

---

## 🔑 Core Rule

> **Not all payments are verified — only Paystack payments are verified**

---

# 🧠 1. Confirmed Model

BizTrack GH must **NOT hold merchant funds**.

System behavior:

- BizTrack GH owns the main Paystack integration
- Each merchant has a Paystack subaccount
- BizTrack GH initializes payments
- Paystack processes & settles funds
- BizTrack GH verifies and records

---

# 🚫 Important Product Rule

A merchant must **NOT** accept digital payments unless onboarding is complete.

If not onboarded:

- disable Paystack payments
- allow only Cash / External

---

# 🏦 2. Merchant Payment Onboarding

## Required Information

- business name
- bank name / bank code
- account number

---

## Backend Flow

1. Merchant submits payout details
2. Backend calls **Create Subaccount (Paystack)**
3. Store `subaccount_code`
4. Set `payments_enabled = true`

---

## Required DB Fields

- `merchant_id`
- `payments_enabled`
- `paystack_subaccount_code`
- `payout_bank_code`
- `payout_account_number_masked`
- `payout_account_name`
- `created_at`
- `updated_at`

---

## Rule

> ❗ No payout details → No digital payments

---

# 🔗 3. Subaccount Concept

Subaccount = **merchant payout mapping**

Used to:

- route merchant money
- enable split payments

---

## ⚠️ Important Truth

Routing does **NOT** come from QR.

Routing comes from:

- merchant context
- database lookup
- `subaccount_code` passed to Paystack

---

# ⚙️ 4. Payment Initialization Flow

1. Merchant creates sale or debt payment
2. Backend creates **internal payment record (pending)**
3. Backend initializes Paystack transaction
4. Include:
   - amount
   - email
   - reference
   - `subaccount_code`
5. Receive `authorization_url`
6. Customer pays
7. Backend verifies (webhook)
8. Update system

---

## 🔒 Rule

> ❗ Frontend must NEVER finalize payment

---

# 💳 5. Payment Entry Methods

BizTrack must support:

- QR (smartphones)
- Payment link (SMS / WhatsApp)
- Mobile money checkout

---

## Clarification

> QR is NOT the payment system — it is just an entry method

---

# 📩 6. SMS Usage

SMS is ONLY for:

- sending payment links
- notifications
- confirmations

---

## ❌ SMS must NOT:

- process payments
- verify payments

---

# 🔁 7. Webhooks & Verification

## Backend must:

- receive webhook
- verify authenticity
- match reference
- update payment
- prevent duplicates

---

## Payment statuses:

- pending
- processing
- paid
- failed
- cancelled

---

# 💼 8. Use Cases

## A. Sale Payment

- create sale
- initialize payment
- verify
- mark paid

---

## B. Debt Payment

- select debt
- initialize payment
- verify
- reduce balance

---

# 📱 9. Merchant UI Flow

Merchant must choose:

- Cash
- External Payment
- Pay with BizTrack

---

## If "Pay with BizTrack":

Require:

- `payments_enabled = true`
- valid `subaccount_code`

---

# 🚨 10. Safeguards

## ❌ Never allow:

- payment without `subaccount_code`
- frontend-only confirmation
- duplicate webhook processing

---

## ✅ Always ensure:

- backend is source of truth
- idempotent processing

---

# ✅ 11. Implementation Checklist

## 🧩 Product Level

- [ ] Add merchant onboarding screen
- [ ] Collect payout details before enabling payments
- [ ] Add “Pay with BizTrack” option
- [ ] Support:
  - Cash
  - External
  - Verified

---

## ⚙️ Backend Level

- [ ] Create merchant payment config table
- [ ] Implement create-subaccount service
- [ ] Store `subaccount_code`
- [ ] Implement initialize-payment endpoint
- [ ] Create internal payment record BEFORE Paystack call
- [ ] Implement webhook handler
- [ ] Verify payment via Paystack
- [ ] Ensure idempotent webhook handling

---

## 📱 Mobile/App Level

- [ ] Show payment options clearly
- [ ] Disable Paystack option if not onboarded
- [ ] Never mark payment successful locally
- [ ] Sync payment result from backend
- [ ] Display correct payment status

---

## 🔐 Safety Rules

- [ ] No payment without `subaccount_code`
- [ ] No frontend-only confirmation
- [ ] No duplicate processing
- [ ] Backend is always source of truth

---

# 🧠 Final Truth

Money goes to the correct merchant because:

- payout details were collected
- subaccount was created
- `subaccount_code` was stored
- backend passed it during payment
- Paystack handled settlement

---

# ⚡ One-line System Definition

> **BizTrack GH does not move money — it controls flow, verifies, and records.**
