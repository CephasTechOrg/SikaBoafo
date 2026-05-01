# Keypad Phone / MoMo Number Payment Flow for Ghana

## Purpose

This document explains how to add a keypad-phone-friendly Paystack payment flow to the existing payment system.

The current system already supports smartphone users by generating a Paystack checkout link and turning that link into a QR code. A customer with a smartphone scans the QR code, opens the Paystack checkout page, enters their mobile money details, and completes payment.

The missing flow is for customers who do not have smartphones and cannot scan a QR code or open a checkout page.

For those customers, the best direction is:

> Cashier enters the customer’s MoMo number and provider, then the backend initiates a Paystack Mobile Money charge so the customer receives the authorization prompt directly on their phone.

This should be called **Pay with MoMo Number** or **MoMo Push Payment**, not “QR payment” and not “USSD payment.”

---

## Important Product Decision

Keep both flows.

### 1. Smartphone flow

Use the existing Paystack transaction initialization flow:

```text
Sale checkout → backend initializes Paystack transaction → returns authorization_url → app displays QR code containing the link → customer scans → Paystack checkout opens → customer pays
```

### 2. Keypad phone flow

Add a new Paystack Charge API flow:

```text
Sale checkout → cashier chooses Pay with MoMo Number → cashier enters phone/provider → backend calls Paystack Charge API → customer receives MoMo authorization prompt → customer approves → Paystack webhook confirms payment → sale becomes paid
```

---

## Why This Is The Correct Direction

Paystack’s Ghana mobile-money flow supports charging a customer through their mobile-money phone number. The customer is required to authorize the payment on the mobile phone tied to that number.

This solves the keypad-phone problem because the customer does not need to:

- scan a QR code
- open a browser
- open a Paystack checkout page
- type payment details into a smartphone interface

The cashier enters the phone number and provider on behalf of the customer, and Paystack/MoMo handles the authorization prompt.

---

## What Not To Do

Do not try to force QR code for keypad-phone customers.

Do not call this the main “USSD” flow in the app because Paystack’s public Charge API documents USSD as Nigeria-only, while Ghana’s practical supported flow is mobile money by phone number/provider.

Do not send the Paystack secret key to the mobile app.

Do not trust the frontend as proof of payment.

Do not mark the sale paid until webhook or server-side verification confirms payment.

---

## Existing Code Direction

Your current code already has a strong base:

- `PaymentSettingsService` stores merchant-owned Paystack credentials.
- Merchant credentials are encrypted before saving.
- `PaymentService.initiate_sale_payment()` initializes a normal Paystack transaction and returns `authorization_url`.
- `PaymentService.handle_paystack_webhook()` receives Paystack webhook events, verifies signatures, verifies the transaction, and updates the payment/sale/receivable status.
- The `Payment` model stores provider reference, merchant ID, sale ID, amount, status, provider mode, and raw provider payload.
- `PaymentWebhookEvent` already supports idempotency.

So the keypad-phone flow should be added as a new method, not as a replacement for the existing QR/link flow.

---

## Backend Implementation Plan

## 1. Add New Request/Response Schemas

File: `app/schemas/payment.py`

Add:

```python
from typing import Literal

class SaleMomoChargeIn(BaseModel):
    sale_id: UUID
    phone: str = Field(min_length=8, max_length=20)
    provider: Literal["mtn", "atl", "vod"]


class SaleMomoChargeOut(BaseModel):
    payment_id: UUID
    provider: str
    provider_reference: str
    amount: Decimal = Field(max_digits=18, decimal_places=2)
    currency: str
    status: str
    sale_id: UUID
    display_text: str | None = None
```

Provider codes:

```text
mtn = MTN Ghana
atl = AirtelTigo / ATMoney
vod = Telecel
```

---

## 2. Add Paystack Charge Result Dataclass

File: `app/integrations/paystack/client.py`

Add:

```python
@dataclass(slots=True)
class PaystackChargeResult:
    reference: str
    status: str
    display_text: str | None
    raw_payload: dict[str, Any]
```

---

## 3. Add `charge_mobile_money` To PaystackClient

File: `app/integrations/paystack/client.py`

Add a method similar to `initialize_transaction`, but it should call:

```text
POST /charge
```

Example method:

```python
def charge_mobile_money(
    self,
    *,
    secret_key: str,
    email: str,
    amount_kobo: int,
    reference: str,
    currency: str,
    phone: str,
    provider: str,
    metadata: dict[str, Any] | None = None,
) -> PaystackChargeResult:
    url = f"{self.base_url.rstrip('/')}/charge"
    payload: dict[str, Any] = {
        "email": email,
        "amount": amount_kobo,
        "reference": reference,
        "currency": currency,
        "mobile_money": {
            "phone": phone,
            "provider": provider,
        },
    }

    if metadata:
        payload["metadata"] = metadata

    raw = self._post_json(
        url=url,
        headers={
            "Authorization": f"Bearer {secret_key}",
            "Content-Type": "application/json",
        },
        payload=payload,
    )

    data = raw.get("data")
    if raw.get("status") is not True or not isinstance(data, dict):
        msg = str(raw.get("message") or "Paystack mobile money charge failed.")
        raise PaystackClientError(msg, response_body=raw)

    provider_reference = data.get("reference")
    if not isinstance(provider_reference, str) or not provider_reference.strip():
        provider_reference = reference

    status = data.get("status")
    status = status.strip().lower() if isinstance(status, str) else "pending"

    display_text = data.get("display_text")
    if display_text is not None and not isinstance(display_text, str):
        display_text = None

    return PaystackChargeResult(
        reference=provider_reference,
        status=status,
        display_text=display_text,
        raw_payload=raw,
    )
```

Expected Paystack state for this flow is usually pending/offline behavior. Do not treat the initial response as final success.

---

## 4. Add New Service Method In PaymentService

File: `app/services/payment_service.py`

Add a new dataclass:

```python
@dataclass(slots=True)
class SaleMomoChargeSnapshot:
    payment_id: UUID
    provider: str
    provider_reference: str
    amount: Decimal
    currency: str
    status: str
    sale_id: UUID
    display_text: str | None = None
```

Add a method:

```python
def initiate_sale_momo_charge(
    self,
    *,
    user_id: UUID,
    sale_id: UUID,
    phone: str,
    provider: str,
) -> SaleMomoChargeSnapshot:
    ...
```

The method should:

1. Get merchant/store context.
2. Load the sale with the customer if available.
3. Validate sale state using `_validate_sale_state`.
4. Load connected Paystack connection.
5. Resolve merchant-specific secret key.
6. Build a unique reference.
7. Convert amount to kobo/pesewas unit.
8. Call `PaystackClient.charge_mobile_money`.
9. Create `Payment` row with:
   - merchant_id
   - sale_id
   - provider = Paystack
   - provider_reference
   - internal_reference
   - provider_mode
   - amount
   - currency
   - status = pending
   - raw_provider_payload
10. Set `sale.payment_status = PAYMENT_STATUS_PENDING_PROVIDER`.
11. Save audit log.
12. Commit and return snapshot.

Example core logic:

```python
result = self._client(configured).charge_mobile_money(
    secret_key=secret_key,
    email=_sale_contact_email(sale=sale),
    amount_kobo=int((amount * 100).to_integral_value(rounding=ROUND_HALF_UP)),
    reference=reference,
    currency=merchant.currency_code or DEFAULT_CURRENCY,
    phone=normalized_phone,
    provider=provider,
    metadata={
        "sale_id": str(sale.id),
        "merchant_id": str(merchant.id),
        "store_id": str(store.id),
        "cashier_id": str(sale.cashier_id) if sale.cashier_id is not None else None,
        "payment_method_label": PAYMENT_METHOD_MOBILE_MONEY,
        "payment_flow": "momo_number_charge",
        "momo_provider": provider,
    },
)
```

---

## 5. Add New Router Endpoint

File: payment router, likely `app/api/.../payment.py`

Add:

```http
POST /api/v1/payments/sales/{sale_id}/momo-charge
```

Request body:

```json
{
  "phone": "0551234987",
  "provider": "mtn"
}
```

Response:

```json
{
  "payment_id": "...",
  "provider": "paystack",
  "provider_reference": "BTGH_...",
  "amount": "300.00",
  "currency": "GHS",
  "status": "pending",
  "sale_id": "...",
  "display_text": "..."
}
```

---

## 6. Reuse Existing Webhook Handler

The existing webhook handler should remain the source of truth.

When Paystack sends `charge.success`, the current logic should:

1. Extract provider reference.
2. Load the `Payment`.
3. Resolve merchant secret.
4. Verify Paystack signature.
5. Verify transaction server-side.
6. Check amount.
7. Mark `Payment` succeeded.
8. Mark `Sale.payment_status` succeeded.
9. Commit.
10. Audit log the success.

This flow already exists for sale payments and should work for the MoMo number charge flow as long as the `Payment` record is created with the same reference Paystack returns.

---

## 7. Add Optional “Check Status” Endpoint

Because mobile-money authorization is offline and webhook delivery may not be instant, add:

```http
POST /api/v1/payments/{payment_id}/verify
```

This endpoint should:

1. Load the payment in the merchant/store scope.
2. Resolve merchant secret.
3. Call Paystack verify transaction with `provider_reference`.
4. If success, apply the same logic used by webhook.
5. Return latest status.

This is useful when the cashier is waiting and wants to tap **Check Status**.

---

## Frontend / Cashier UX

At checkout, show payment options:

```text
1. Pay by QR / Link
2. Pay with MoMo Number
3. Cash
```

When cashier taps **Pay with MoMo Number**:

Fields:

```text
Customer MoMo Number
Provider: MTN / AirtelTigo / Telecel
Amount: GHS xxx.xx
```

Button:

```text
Send MoMo Prompt
```

After sending:

```text
Waiting for customer approval...
Ask the customer to check their phone and approve the MoMo prompt.
```

Actions:

```text
Check Status
Cancel / Retry
```

When webhook or verify succeeds:

```text
Payment received.
Sale marked as paid.
Receipt sent.
```

If failed or timeout:

```text
Payment not completed yet.
Ask customer to approve, retry, or choose another payment method.
```

---

## SMS / Akasel Role

Akasel should not process the payment.

Use Akasel only for communication, for example:

```text
A GHS 300 payment request has been sent to 0551234987. Please approve the MoMo prompt to complete payment at Nana Electricals.
```

After success:

```text
Payment received: GHS 300. Thank you for shopping at Nana Electricals. Ref: BTGH_...
```

---

## Database Notes

The current `Payment` model can support this flow because it already stores:

- merchant_id
- sale_id
- provider
- provider_reference
- internal_reference
- provider_mode
- amount
- currency
- status
- initiated_at
- confirmed_at
- raw_provider_payload

Optional future improvement:

Add explicit fields:

```python
payment_flow = "checkout_link" | "momo_number_charge"
payment_channel = "mobile_money" | "card" | "bank_transfer"
momo_provider = "mtn" | "atl" | "vod"
customer_phone_snapshot = "0551234987"
```

---

## Status Handling Rules

Never mark payment successful immediately after calling `/charge`.

Initial response means:

```text
Payment request has been created/sent.
Customer still needs to approve.
```

Final success comes from:

1. Paystack webhook, preferably `charge.success`;
2. or backend verify endpoint returning transaction status `success`.

---

## Test Cases

Test these cases:

1. MTN number, valid test key, customer approves.
2. MTN number, customer ignores prompt.
3. Wrong phone number.
4. Wrong provider selected.
5. Existing sale already paid.
6. Sale voided.
7. Merchant has no Paystack connection.
8. Merchant test key saved but app is in live mode.
9. Webhook arrives twice.
10. Webhook arrives before cashier refreshes screen.
11. Webhook never arrives but manual verify succeeds.
12. Paystack returns failure.
13. Amount mismatch.
14. Cashier retries after timeout.

---

## Final Product Language

Use this language in the app:

- Pay by QR / Link
- Pay with MoMo Number
- Send MoMo Prompt
- Waiting for customer approval
- Ask customer to approve on their phone
- Payment received
- Payment not completed yet

Avoid this language for Ghana:

- Pay by USSD
- Scan with keypad phone
- Offline QR
- Manual Paystack USSD

---

## Final Implementation Summary

Do not replace the current QR/link payment flow.

Add a second payment initiation method:

```text
initiate_sale_momo_charge()
```

This method calls Paystack `/charge` with:

```json
{
  "email": "customer@example.com",
  "amount": 30000,
  "currency": "GHS",
  "reference": "BTGH_...",
  "mobile_money": {
    "phone": "0551234987",
    "provider": "mtn"
  }
}
```

Then rely on the existing webhook verification architecture to mark the sale as paid.

This is the correct direction for Ghana keypad-phone customers.
