# Debt Payment Flow Audit — Paystack Link / QR / Receivables

> **Superseded for planning:** Use the consolidated audit and checklists in  
> [`docs/audits/CODEBASE_AUDIT.md`](docs/audits/CODEBASE_AUDIT.md) (Audit 3 — Debt payment flow).  
> This file is kept for historical detail and code snippets.

## Scope

Reviewed the uploaded backend and Flutter debt-payment files:

- payment_service(3).py
- receivables_service.py
- receivables.py
- client(1).py
- receivable.py
- debt_detail_screen(4).dart
- debts_screen(4).dart
- debt_paystack_qr_sheet.dart
- debt_paystack_momo_sheet.dart
- debt_payment_link_panel.dart
- debt_payment_link_share.dart
- debts_api(2).dart
- debts_payments_api.dart
- debt_balance_hero.dart

## Main User-Reported Issue

When a debt payment link or QR code is generated and the customer pays successfully through Paystack, the mobile app often remains in a “Waiting for payment / Checking / Verifying” state. If the merchant closes the sheet and comes back, the debt may then show as paid.

This strongly suggests the backend eventually settles the payment, but the Flutter debt-detail/payment UI is not reliably refreshing from the authoritative server state at the correct time.

---

# Highest Priority Findings

## 1. Debt QR success path does not directly refresh the debt detail provider before/after closing

### Problem

`DebtPaystackQrSheet._completeSuccess()` applies the server row to the debts controller and starts a background refresh, but it does not directly close the sheet itself and does not directly force the `receivableDetailProvider` to reload before the parent screen continues rendering.

The parent callback `_onSheetPaymentConfirmed()` only calls `Navigator.pop()` and shows a snackbar. It does not invalidate or reload the debt detail provider.

### Why this causes the bug

The sheet may detect payment success, but the visible debt-detail screen can still be holding an older provider snapshot. That makes the merchant feel like the app is still waiting or has not confirmed the payment until they leave and return.

### Fix

In `DebtPaymentLinkPanel._onSheetPaymentConfirmed`, do this:

```dart
void _onSheetPaymentConfirmed(ReceivableDto? serverRow) {
  if (!mounted) return;

  if (serverRow != null) {
    unawaited(
      ref.read(debtsControllerProvider.notifier).applyServerReceivable(serverRow),
    );
  }

  ref.invalidate(receivableDetailProvider(widget.record.receivableId));
  unawaited(ref.read(debtsControllerProvider.notifier).refreshFromServer());

  Navigator.of(context).pop();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(_paymentConfirmedMessage(serverRow))),
  );
}
```

If `receivableDetailProvider` is not imported in `debt_payment_link_panel.dart`, import it.

---

## 2. Active payment links are not cleared after successful settlement

### Problem

When a receivable payment succeeds, `_apply_receivable_settlement()` reduces the outstanding amount and updates the receivable status, but it does not clear:

- `receivable.payment_link`
- `receivable.payment_provider_reference`

### Why this is dangerous

After a successful payment, the old Paystack link is no longer the correct “active” debt collection link.

If the link remains on the receivable:

- the UI can still show “Active link”
- the merchant can reopen/share an already-paid link
- the panel may keep watching an old link
- partial-payment flows can become confusing
- completed debts can look like they still have an active online payment request

### Fix

Inside `_apply_receivable_settlement()`, after applying the settlement, clear the link if it belongs to the payment being settled:

```python
if receivable.payment_provider_reference == payment.provider_reference:
    receivable.payment_link = None
    receivable.payment_provider_reference = None
```

This should happen for both full and partial settlement. For partial settlement, the merchant should generate a new link for the remaining amount.

---

## 3. Cancelled debts can still be mutated by old Paystack payments

### Problem

`ReceivablesService.cancel_receivable()` marks the receivable as cancelled, but it does not clear active payment links or expire pending payment rows.

Separately, `_apply_receivable_settlement()` does not check whether the receivable is already cancelled before applying a Paystack settlement.

### Why this is serious

A merchant can cancel a debt while an old Paystack link is still active. If the customer later pays that old link, the webhook or verify flow may reduce the outstanding balance and change the cancelled debt into a paid/partial-paid state.

That breaks trust.

### Fix A — when cancelling a debt

When cancelling a receivable:

1. mark the receivable cancelled;
2. clear `payment_link`;
3. clear `payment_provider_reference`;
4. mark pending payment rows for that receivable as failed/cancelled locally.

Example:

```python
receivable.status = RECEIVABLE_STATUS_CANCELLED
receivable.payment_link = None
receivable.payment_provider_reference = None

pending_payments = self.db.scalars(
    select(Payment).where(
        Payment.receivable_id == receivable.id,
        Payment.status == PROVIDER_PAYMENT_PENDING,
    )
).all()

for p in pending_payments:
    p.status = PROVIDER_PAYMENT_FAILED
    p.raw_provider_payload = {
        **(p.raw_provider_payload or {}),
        "failure_reason": "receivable_cancelled",
        "cancelled_at": datetime.now(tz=UTC).isoformat(),
    }
    self.db.add(p)
```

### Fix B — before applying settlement

In `_apply_receivable_settlement()` or before calling it, add:

```python
if receivable.status == RECEIVABLE_STATUS_CANCELLED:
    payment.status = PROVIDER_PAYMENT_FAILED
    return
```

Better: handle this before settlement and log a clear audit event like `payment.ignored_cancelled_receivable`.

---

## 4. Cash repayment does not expire existing online payment links

### Problem

`record_repayment()` reduces `outstanding_amount` and updates status, but it does not clear/expire an existing pending Paystack payment link.

### Why this matters

Example:

1. Merchant generates a Paystack debt link for GHS 300.
2. Customer later pays GHS 300 in cash.
3. Debt is settled.
4. Old Paystack link may still exist.
5. Customer later pays the old link too.
6. The system may double-collect or create confusing payment state.

### Fix

After any manual/cash repayment:

- if the receivable is fully settled, expire all pending online payment rows and clear the payment link;
- if the receivable is partially paid, expire the old pending payment link because the amount is now stale and a new link should be generated for the new remaining balance.

---

## 5. Passive payment watcher only fetches receivable; it does not verify Paystack

### Problem

`DebtPaymentLinkPanel._watchServerPaymentProgress()` fetches the receivable every 6 seconds. That catches updates only if the webhook has already settled the debt on the backend.

It does not call `verifyPayment(paymentId)` if the receivable has not changed.

### Why this causes “stuck waiting”

If Paystack payment succeeds but the webhook is delayed/missed, the server receivable stays open until the verify endpoint is called.

The QR sheet calls verify, but the panel watcher does not. So if the link was shared and the QR sheet is closed, the UI depends mostly on webhook.

### Fix

Inside `_watchServerPaymentProgress()`:

1. fetch receivable;
2. if no progress and `widget.record.paymentId != null`, call `verifyPayment`;
3. fetch receivable again after verify;
4. apply server row if status/outstanding changed.

---

## 6. Payment schema appears outdated for amount-based debt links

### Problem

The Flutter `DebtsPaymentsApi.initiatePayment()` sends an optional `amount`, but the uploaded backend `PaymentInitiateIn` schema only includes `receivable_id`.

### Why this matters

If this is the actual schema used by your FastAPI route, the backend may ignore the amount sent from the mobile app. That means:

- partial debt links may accidentally charge the full outstanding amount;
- UI amount and Paystack amount can disagree;
- verification and remaining balance logic may feel inconsistent.

### Fix

Update backend schema:

```python
class PaymentInitiateIn(BaseModel):
    receivable_id: UUID
    amount: Decimal | None = Field(default=None, gt=0, max_digits=18, decimal_places=2)
```

Then ensure the route passes it:

```python
service.initiate_receivable_payment(
    user_id=current_user.id,
    receivable_id=payload.receivable_id,
    amount=payload.amount,
)
```

---

## 7. Latest payment context returns latest payment regardless of status

### Problem

`_latest_payment_context_for_receivable()` returns the latest payment row for a receivable, regardless of whether it is pending, succeeded, or failed. It only sets `expires_at` when pending.

### Why this can confuse the UI

The frontend receives:

- `payment_id`
- `payment_amount`
- `payment_link`
- `payment_provider_reference`

But `payment_link` is stored on the receivable separately and may remain even when the latest payment is already succeeded or failed.

This creates inconsistent states like:

- link exists
- payment ID points to a succeeded payment
- expiry is null
- UI still treats it as active because `_hasLink` checks only the link

### Fix

Change the snapshot logic so active payment fields are only returned for an active pending payment.

Preferred backend rule:

```text
A receivable has an active payment link only when:
- receivable.payment_link is not null
- receivable.payment_provider_reference matches a Payment row
- that Payment row status is pending
- the payment is not expired
```

Return `payment_link = None`, `payment_id = None`, and `payment_link_expires_at = None` otherwise.

---

## 8. Webhook handler should reuse the same receivable-settlement helper as manual verify

### Problem

`verify_receivable_payment()` uses `_apply_paystack_verify_to_receivable_payment()`, which contains better safety logic:

- idempotency check
- metadata mismatch check
- amount handling
- settlement application

But `handle_paystack_webhook()` manually repeats receivable settlement logic instead of using that helper.

### Why this matters

Two paths settle the same debt:

1. webhook path
2. manual verify path

If they do not use the same helper, bugs will appear in one path and not the other.

### Fix

After verifying the transaction in webhook, if target is receivable, call:

```python
paystack_status = self._apply_paystack_verify_to_receivable_payment(
    user_id=None,
    merchant=merchant,
    payment=payment,
    receivable=receivable,
    verified=verified,
)
```

You may need to allow `user_id: UUID | None` in the helper.

---

## Recommended Clean Payment State Machine

Use this for receivable online payment links:

### Payment statuses

```text
initialized
pending
succeeded
failed
expired
cancelled
```

### Receivable statuses

```text
open
partially_paid
settled
cancelled
```

### Rules

1. A pending payment may update a receivable only if the receivable is open or partially_paid.
2. A cancelled receivable must not be mutated by later Paystack callbacks.
3. Any manual repayment invalidates old online payment links.
4. Successful online payment clears the active payment link.
5. Partial successful online payment also clears the active link; generate a fresh one for remaining balance.
6. Frontend must never infer success only from Paystack redirect. It must use backend fetch/verify.
7. The detail provider must be invalidated immediately after confirmed payment.

---

## Files Still Needed For A Complete Deep Review

To finish the review properly, provide these files:

1. Backend payments router file  
   The file that defines:
   - `/payments/initiate`
   - `/payments/receivable-payments/{payment_id}/verify`
   - `/payments/receivables/{receivable_id}/momo-charge`
   - `/payments/receivable-payments/{payment_id}/submit-momo-otp`

2. `debts_providers.dart`  
   Needed to verify:
   - `initiatePaymentLink`
   - `applyServerReceivable`
   - `refreshFromServer`
   - `cancelReceivable`
   - local cache update behavior

3. `debt_detail_provider.dart`  
   Needed to confirm why detail screen stays stale after payment.

4. Local models:
   - `local_receivable_record.dart`
   - `local_receivable_detail.dart`

5. Exact backend logs for:
   - successful Paystack webhook
   - manual verify endpoint after successful payment
   - debt cancellation attempt
   - payment link generation

6. Paystack webhook route file  
   Needed to confirm the webhook endpoint passes raw body and `x-paystack-signature` correctly.

---

## Immediate Fix Order

1. Invalidate/reload `receivableDetailProvider` in `_onSheetPaymentConfirmed`.
2. Clear receivable payment link/reference after successful payment.
3. Prevent cancelled receivables from being settled by old Paystack links.
4. Expire pending online payment rows on cash repayment and cancellation.
5. Add verify fallback to `_watchServerPaymentProgress`.
6. Update `PaymentInitiateIn` schema to accept `amount`.
7. Make webhook settlement reuse `_apply_paystack_verify_to_receivable_payment`.
8. Return active payment context only for pending non-expired payments.
9. Add backend tests for paid, partial, cancelled, cash-paid, stale-link, duplicate-webhook cases.

---

## Most Likely Reason The App Shows Paid Only After Closing And Reopening

The payment likely succeeds on the backend, but the debt detail provider/local cache is stale. Closing and reopening forces a reload, so the correct server state appears.

The payment flow needs an explicit “payment confirmed → update local row → invalidate detail provider → refresh from server → close sheet” path.
