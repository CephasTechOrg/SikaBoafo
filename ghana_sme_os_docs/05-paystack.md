# Paystack Payment Flow

## Purpose
This document defines how payments work in version 1 of the system.

This is one of the most important source-of-truth documents in the project.

## Core Product Decision
Version 1 uses:
- merchant-owned Paystack accounts
- a simple merchant setup flow inside our app
- payment links as the main customer payment experience
- WhatsApp and SMS for invoice and reminder delivery
- backend webhook verification as the source of truth for payment success
- one payment provider first, with abstraction for future providers

## Why We Chose Merchant-Owned Accounts
We considered:
1. split/subaccount model
2. merchant-owned account model

We chose merchant-owned accounts for version 1 because:
- simpler compliance model
- clearer merchant trust
- cleaner reconciliation
- easier separation of money flows
- lower operational complexity for an early product

## Important Payment Rule
The app does not hold merchant money.

The payment provider processes payment and settles funds according to the merchant's own Paystack account configuration.

The app only:
- creates payment requests
- stores references
- listens for status updates
- verifies transactions
- updates invoices, sales, and customer balances

## Merchant Connection Flow

### Merchant-facing flow
Inside the app:
1. Merchant opens Settings
2. Merchant selects Payments
3. Merchant clicks Connect Paystack
4. Merchant sees simple guided steps:
   - Create or log into Paystack
   - Verify business account
   - Complete connection details
   - Finish setup
5. App validates connection
6. Merchant is marked payment-ready

### Internal implementation notes
For version 1:
- assume lightweight manual linking behind a guided UI
- hide technical language as much as possible
- do not present raw API concepts unless needed
- secure merchant credentials using encrypted storage
- connection test must happen before enabling live payments

## Payment Methods In Scope
Version 1 should primarily support:
- hosted payment links
- mobile money-friendly checkout
- smartphone path through link opening
- SMS fallback for reminder delivery
- offline/USSD-friendly provider-supported path where available

QR can exist later as a convenience path, but it is not the primary path in version 1.

## Main Payment Use Cases

### 1. Pay now during sale
Use when customer is paying immediately.
Flow:
1. Cashier records items
2. System computes total
3. Backend creates payment request
4. Payment link returned
5. Customer pays
6. Webhook confirms success
7. Sale becomes paid
8. Stock is reduced
9. Receipt is sent

### 2. Debt or invoice payment later
Use when customer pays later.
Flow:
1. Merchant creates invoice
2. Invoice linked to customer
3. Backend creates payment request
4. Link sent through WhatsApp or SMS
5. Customer pays later
6. Webhook confirms success
7. Invoice balance updates
8. Customer balance updates
9. Confirmation/receipt is sent

### 3. Partial payment
Flow:
1. Invoice exists
2. Customer pays part of amount
3. Verified payment updates amount_paid
4. balance_remaining recalculated
5. Invoice becomes partially_paid until full settlement

## Payment Entities To Track
For every payment request we must track:
- internal invoice or sale ID
- business ID
- customer ID if applicable
- provider name
- provider reference
- internal reference
- amount
- currency
- status
- payment channel if available
- created time
- paid time
- raw provider response

## Backend Payment Lifecycle

### Step 1: Create invoice or payment intent
The backend receives:
- business_id
- customer_id optional
- sale_id or invoice purpose
- amount
- channel preference if applicable

### Step 2: Generate internal payment record
Create a payment row with:
- internal_reference
- status = initialized

### Step 3: Call provider
The payment service calls Paystack using merchant-specific configuration and receives:
- provider reference
- hosted checkout link or payment instructions

### Step 4: Persist provider data
Update payment row:
- provider_reference
- status = pending
- link/instruction metadata if needed

### Step 5: Notify customer
Send:
- WhatsApp payment message for smartphone-friendly flow
- SMS fallback if required

### Step 6: Receive webhook
Webhook endpoint receives provider event.
Important checks:
- validate signature
- confirm event type
- extract provider reference
- find matching payment row
- verify with provider if required

### Step 7: Update business state
If payment succeeds:
- mark payment = succeeded
- update invoice amount_paid
- update balance_remaining
- if fully settled, invoice status = paid
- if partial, invoice status = partially_paid
- if linked to immediate sale, mark sale paid
- trigger receipt notification
- create audit log entry

If payment fails:
- mark payment = failed
- retain invoice state
- optionally notify merchant

## Verification Rules
- backend webhook is the main trigger
- payment success must never be trusted from frontend redirect alone
- provider reference must be unique and tracked
- optional verify call may be made server-side before finalizing success
- every success mutation must be idempotent

## Reminder Flow
1. Invoice becomes due or remains unpaid
2. Reminder job selects unpaid invoices
3. System chooses delivery channel
4. Reminder message is sent
5. Message includes payment link when available
6. Notification log is written

Example message:
> Hello Kojo, your outstanding balance is GHS 300. Tap here to pay by MoMo: [payment link]

## Customer Channel Strategy

### Smartphone customer
- WhatsApp preferred
- hosted payment link opens checkout

### Non-smartphone or fallback path
- SMS reminder/instruction
- provider-supported offline-friendly payment flow where applicable
- merchant can also follow up manually if needed

## Security Requirements
- encrypt merchant payment configuration
- restrict access to payment connection settings
- validate all webhooks
- use idempotency protection on webhook processing
- never expose secret credentials in frontend
- log all payment state changes

## Product UX Rule
Do not expose technical payment language to merchants unless necessary.

The merchant should experience:
- Connect Paystack
- Verify account
- Finish setup
- Start receiving payments

not:
- copy secret key
- configure raw API settings
- manually debug integration terminology

## Future Payment Extensions
Later versions can add:
- second provider for redundancy
- branch-level payment configuration
- refunds
- split settlements if business model changes
- customer portal for viewing invoices and payments
