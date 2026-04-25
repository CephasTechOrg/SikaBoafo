# Paystack Connection Debugging Findings & Implementation Notes

## Context

This system is a Ghana-focused SME business platform where each merchant owns their own Paystack account. The merchant goes to app settings, connects Paystack, and saves their Paystack credentials so the backend can initialize payments, create payment links, receive Paystack webhooks, and verify transactions.

The current problem is that the Paystack connection flow is failing with HTTP 403 or “cannot connect / invalid key” behavior.

The merchant account being tested is reportedly the main merchant owner account, not a worker/cashier account.

---

## High-Level Conclusion

The code currently suggests that the “Connect Paystack” screen is not truly validating the Paystack key with Paystack during save.

Instead, the backend mostly:
1. checks the key prefix,
2. encrypts the provided secret key,
3. stores the encrypted key,
4. sets `verified_at` immediately,
5. marks the connection usable if an encrypted key and `verified_at` exist.

Therefore, if the Save/Connect action returns HTTP 403, the most likely source is not Paystack key validity itself. It is more likely one of these:

1. backend route authorization is rejecting the request;
2. the authenticated user ID does not match `Merchant.owner_user_id`;
3. the router dependency is passing the wrong user ID into `PaymentSettingsService`;
4. the mobile app token/session is not the owner token even though the visible account looks like the owner;
5. the settings endpoint is protected by an owner/admin permission check outside the service;
6. the backend is mapping `PaymentSettingsContextError` or another permission error to HTTP 403.

If the 403 happens during actual Paystack API calls, then the issue could be Paystack-side, such as IP whitelisting or incorrect Paystack client authentication, but the uploaded settings service code does not appear to call Paystack during the save operation.

---

## Files Reviewed

Reviewed uploaded files:

- `payment_settings_service.py`
- `payment_service.py`
- `payment.py`
- `payment_settings.py`
- `connect_paystack_screen.dart`

Important missing files that should still be checked:

- backend payment settings router/controller
- `app/integrations/paystack/client.py`
- `settings_api.dart`
- `app/core/config.py`
- auth/current-user dependency file
- exact backend log for the HTTP 403

---

## Finding 1 — Connection Save Does Not Actually Verify Paystack Key

### What I saw

In `PaymentSettingsService.upsert_paystack_connection`, when `payload.secret_key` is provided, the backend sets:

```python
verified_at = datetime.now(tz=UTC)
encrypted_secret = encrypt_text(
    plaintext=payload.secret_key,
    key=configured.payment_config_encryption_key,
)
secret_key_last4 = payload.secret_key[-4:]
```

Then it stores the encrypted secret and marks the mode usable if encrypted secret and `verified_at` exist.

### Why this matters

This means the backend is not actually calling Paystack to confirm whether the key is valid before marking it verified.

So the text in the Flutter UI saying the key is “confirmed working on your first payment” is more accurate than saying it is verified during connection.

### Risk

A merchant can save a structurally valid but wrong key, and the app may show Paystack as connected. The first real payment initialization will fail later.

### Required fix

Add a real server-side Paystack validation step before saving the key as verified.

Recommended behavior:

1. Receive key on backend only.
2. Normalize/trim key.
3. Validate prefix:
   - test mode requires `sk_test_`
   - live mode requires `sk_live_`
4. Call a safe authenticated Paystack endpoint using that secret key.
5. If Paystack responds successfully, encrypt and save the key.
6. If Paystack rejects the key, return HTTP 400 with a clear message.
7. Do not set `verified_at` unless Paystack validation succeeds.

Example service behavior:

```python
if payload.secret_key is not None:
    configured = self.settings or get_settings()

    # Validate the key with Paystack BEFORE saving it as verified.
    try:
        self._validate_paystack_secret_key_with_provider(
            secret_key=payload.secret_key,
            settings=configured,
        )
    except PaystackClientError as exc:
        raise PaymentSettingsValidationError(
            "Paystack rejected this secret key. Check the key and selected mode."
        ) from exc

    verified_at = datetime.now(tz=UTC)
    encrypted_secret = encrypt_text(
        plaintext=payload.secret_key,
        key=configured.payment_config_encryption_key,
    )
    secret_key_last4 = payload.secret_key[-4:]
```

The validation helper can call a lightweight endpoint such as Paystack’s bank list endpoint or another safe authenticated endpoint supported by your `PaystackClient`.

---

## Finding 2 — HTTP 403 Is Probably Coming From Your Own Backend Authorization

### What I saw

`PaymentSettingsService._get_merchant` looks up the merchant using:

```python
merchant = self.db.scalar(
    select(Merchant).where(Merchant.owner_user_id == owner_user_id)
)
```

If no merchant is found, it raises:

```python
PaymentSettingsContextError("Merchant profile not found.")
```

### Why this matters

Even if the user appears to be the main owner in the UI, the backend can still reject the request if:

1. the JWT subject is not the same ID stored in `Merchant.owner_user_id`;
2. the mobile app is using an old token;
3. the route passes the wrong ID into `owner_user_id`;
4. the merchant row was created with a different owner ID;
5. the user is owner at the store level but not in `Merchant.owner_user_id`;
6. the router has an additional owner-only dependency that is failing before the service runs.

### Required fix

Add debug logging around the payment settings endpoint and service.

Log these values without exposing secrets:

```python
logger.info(
    "Paystack settings update attempt",
    extra={
        "current_user_id": str(current_user.id),
        "merchant_owner_lookup": str(current_user.id),
        "mode": payload.mode,
        "has_secret_key": payload.secret_key is not None,
        "secret_key_prefix": payload.secret_key[:8] if payload.secret_key else None,
    },
)
```

Also log the actual merchant lookup result:

```python
merchant = self.db.scalar(
    select(Merchant).where(Merchant.owner_user_id == owner_user_id)
)

if merchant is None:
    logger.warning(
        "Paystack settings update rejected: no merchant for owner_user_id",
        extra={"owner_user_id": str(owner_user_id)},
    )
    raise PaymentSettingsContextError("Merchant profile not found.")
```

Then verify directly in the database:

```sql
SELECT id, owner_user_id, business_name, created_at
FROM merchants
WHERE owner_user_id = '<current_user_id_from_token>';
```

If that returns no row, the 403 is not a Paystack problem.

---

## Finding 3 — Frontend Treats 403 As Owner Permission Error

### What I saw

In `connect_paystack_screen.dart`, the error handler maps `401` or `403` to:

```dart
'You do not have permission to update payment settings. Only the account owner can do this.'
```

### Why this matters

The frontend already assumes that 403 is a permission/owner issue. So if this message appears, the request likely reached your own backend and was rejected before any Paystack validation.

### Required fix

Improve the error display during development to show the real backend `detail` for 403 too.

Current logic only prioritizes backend `detail` when status is 400. During debugging, change it to show backend detail for 401/403 as well:

```dart
if (data is Map<String, dynamic> && data['detail'] is String) {
  final detail = (data['detail'] as String).trim();
  if (detail.isNotEmpty) {
    return detail;
  }
}
```

This will help identify whether the backend says:
- `Merchant profile not found`
- `Not authorized`
- `Owner role required`
- `Invalid token`
- or something else.

---

## Finding 4 — Missing Import Bug In `payment_service.py`

### What I saw

`payment_service.py` uses:

```python
_PAYSTACK_CHANNEL_MAP: dict[str, str] = {
    "mobile_money": PAYMENT_METHOD_MOBILE_MONEY,
    "bank_transfer": PAYMENT_METHOD_BANK_TRANSFER,
    "bank": PAYMENT_METHOD_BANK_TRANSFER,
}
```

But the import list includes `PAYMENT_METHOD_MOBILE_MONEY` and does not include `PAYMENT_METHOD_BANK_TRANSFER`.

### Why this matters

This will cause a `NameError` when the module loads or when the map is evaluated, depending on import/runtime behavior.

This may not be the current 403, but it is a real bug that can break payment/webhook processing.

### Required fix

Add the missing constant import:

```python
from app.core.constants import (
    DEFAULT_CURRENCY,
    PAYMENT_METHOD_MOBILE_MONEY,
    PAYMENT_METHOD_BANK_TRANSFER,
    PAYMENT_STATUS_FAILED,
    PAYMENT_STATUS_PENDING_PROVIDER,
    PAYMENT_STATUS_SUCCEEDED,
    PAYMENT_PROVIDER_PAYSTACK,
    PAYSTACK_MODE_LIVE,
    PAYSTACK_MODE_TEST,
    PROVIDER_PAYMENT_FAILED,
    PROVIDER_PAYMENT_PENDING,
    PROVIDER_PAYMENT_SUCCEEDED,
    RECEIVABLE_STATUS_CANCELLED,
    RECEIVABLE_STATUS_PARTIALLY_PAID,
    RECEIVABLE_STATUS_SETTLED,
    SALE_STATUS_VOIDED,
)
```

If that constant does not exist, create it in `app.core.constants`, for example:

```python
PAYMENT_METHOD_BANK_TRANSFER = "bank_transfer"
```

---

## Finding 5 — Webhook Design Is Mostly Correct, But Setup Must Match Merchant-Owned Accounts

### What I saw

The backend webhook handler:

1. parses Paystack payload;
2. extracts transaction reference;
3. loads the internal payment by `provider_reference`;
4. resolves the correct merchant secret;
5. verifies Paystack signature;
6. checks for duplicate event processing;
7. verifies transaction server-side;
8. updates sale or receivable payment state.

This is the right direction.

### Important issue

Because this architecture uses merchant-owned Paystack accounts, each merchant’s Paystack dashboard may need to send events to the same backend webhook URL:

```text
https://biztrackgh-api.onrender.com/api/v1/webhooks/paystack
```

Your Flutter UI already shows a webhook setup card instructing the merchant to paste the webhook URL into their Paystack dashboard.

### Required fix

Keep this webhook setup, but make it clear in the product:

- this is a one-time Paystack dashboard setup;
- it is required for automatic payment confirmation;
- without it, payment links may open and collect money, but the app may not automatically update until manual verification or polling is done.

### Optional improvement

Add a backend “webhook health” status:

- `not_configured`
- `waiting_for_first_event`
- `received_test_event`
- `active`

---

## Finding 6 — `.env` Paystack Keys Are Not The Main Requirement For Merchant-Owned Payments

### What I saw

`payment_service.py` resolves the merchant-specific encrypted secret first. It only falls back to `.env` Paystack secret keys in non-production.

The production behavior requires merchant-specific Paystack credentials.

### What this means

For merchant-owned payments, the backend does not need one global Paystack secret key for all merchant transactions.

The backend still needs environment variables for:

```env
DATABASE_URL=
JWT_SECRET=
PAYMENT_CONFIG_ENCRYPTION_KEY=
PAYSTACK_API_BASE_URL=https://api.paystack.co
PAYSTACK_HTTP_TIMEOUT_SECONDS=
```

Optional development fallback only:

```env
PAYSTACK_SECRET_KEY_TEST=
PAYSTACK_SECRET_KEY_LIVE=
```

But for production merchant payments, the merchant’s own encrypted secret key should be used.

### Required fix

Do not mix platform Paystack keys and merchant Paystack keys during production payment initiation.

The logic should be:

```text
If merchant-specific secret exists:
    use merchant-specific secret
Else if non-production fallback key exists:
    use env fallback
Else:
    fail clearly
```

Your current code appears to follow this direction. Confirm with tests.

---

## Finding 7 — Current UI Copy May Mislead During Connection

### What I saw

The UI says:

```text
Format is validated on save; the key is confirmed working on your first payment.
```

This is technically accurate, but the overall “Connected” state may make the merchant think the key was already verified with Paystack.

### Required fix

After implementing real backend validation, update the copy to:

```text
Your secret key is validated with Paystack, encrypted, and stored securely on the server.
```

If you do not implement real validation yet, show:

```text
Your key format is saved securely. It will be confirmed with Paystack when you create your first payment.
```

Do not show “Verified” unless a real Paystack API validation succeeds.

---

## Finding 8 — Public Key Is Optional, But Secret Key Is The Real Backend Requirement

### What I saw

Both frontend and backend allow `public_key` to be optional. That is fine for backend transaction initialization because Paystack API calls require the secret key.

### Required decision

For this merchant-owned backend-driven flow, only the secret key is required for backend payment creation and verification.

Recommended UX:

- Public key: optional / advanced
- Secret key: required
- Mode: required
- Account label: optional

Do not ask merchants for unnecessary information unless the app truly needs it.

---

## Finding 9 — Add A Dedicated “Test Paystack Connection” Endpoint

### Why

Right now, save and verification are mixed. A cleaner design is:

```text
POST /api/v1/payment-settings/paystack/test
```

Input:

```json
{
  "mode": "test",
  "secret_key": "sk_test_xxx"
}
```

Output:

```json
{
  "ok": true,
  "message": "Paystack key is valid."
}
```

Then `upsert_paystack_connection` can use the same internal validator.

### Recommended behavior

- If key prefix is wrong: return 400.
- If Paystack rejects key: return 400.
- If Paystack cannot be reached: return 503.
- If authenticated user is not merchant owner: return 403.
- If merchant profile missing: return 403 or 404, but be consistent.

---

## Finding 10 — Add Precise Error Mapping

### Backend should return

For invalid key format:

```json
{
  "detail": "Test mode requires an sk_test_ secret key."
}
```

For Paystack rejection:

```json
{
  "detail": "Paystack rejected this secret key. Check the key and selected mode."
}
```

For no merchant profile:

```json
{
  "detail": "Merchant profile not found for this user."
}
```

For wrong account role:

```json
{
  "detail": "Only the merchant owner can update payment settings."
}
```

For server encryption config issue:

```json
{
  "detail": "Server payment encryption is not configured."
}
```

Frontend should display the backend `detail` for all 400/401/403/503 debugging cases.

---

## Exact Implementation Checklist For AI Agent

### Step 1 — Inspect route/controller

Open the backend router that handles:

```text
GET /payment-settings/paystack
PUT/PATCH /payment-settings/paystack
DELETE /payment-settings/paystack
```

Check:
- what dependency gets the current user;
- what ID is passed into `owner_user_id`;
- how `PaymentSettingsContextError` is converted to HTTP;
- whether there is an additional owner-only dependency causing 403.

### Step 2 — Fix missing import

In `payment_service.py`, import `PAYMENT_METHOD_BANK_TRANSFER`.

### Step 3 — Add real Paystack validation on save

In `PaymentSettingsService`, add a helper:

```python
def _validate_paystack_secret_key_with_provider(
    self,
    *,
    secret_key: str,
    settings: Settings,
) -> None:
    client = PaystackClient(
        base_url=settings.paystack_api_base_url,
        timeout_seconds=settings.paystack_http_timeout_seconds,
    )
    client.validate_secret_key(secret_key=secret_key)
```

Then implement `validate_secret_key` inside `PaystackClient`.

Example:

```python
def validate_secret_key(self, *, secret_key: str) -> None:
    response = self._request(
        method="GET",
        path="/bank",
        secret_key=secret_key,
    )
    # If the request succeeds, the key is valid enough for authenticated API usage.
```

Use the actual request style of the existing `PaystackClient`.

### Step 4 — Only set `verified_at` after real validation

Do not set `verified_at = datetime.now(tz=UTC)` before Paystack validation succeeds.

### Step 5 — Improve frontend error display

In `connect_paystack_screen.dart`, return backend `detail` for all error statuses, not only 400.

### Step 6 — Add temporary debug logs

Add logs around:
- current user ID
- merchant lookup result
- mode
- whether secret key exists
- key prefix only, never full key
- route permission result

### Step 7 — Test with controlled cases

Test these cases:

1. owner user + correct `sk_test_` key
2. owner user + `pk_test_` key
3. owner user + live key while mode is test
4. owner user + random `sk_test_`-shaped invalid key
5. worker user + correct key
6. user with no merchant row
7. missing encryption env var
8. Paystack IP whitelisting enabled
9. webhook event after successful payment

---

## Priority Fix Order

1. Confirm whether the 403 is from your backend router/auth or from Paystack.
2. Show raw backend `detail` in the Flutter error message.
3. Inspect router/controller and current-user dependency.
4. Add missing `PAYMENT_METHOD_BANK_TRANSFER` import.
5. Add real Paystack key validation before marking connection verified.
6. Add debug logs around merchant lookup and permission checks.
7. Add tests for owner vs worker vs no-merchant account.
8. Add Paystack client test endpoint or connection validator.
9. Keep webhook setup instructions for merchant-owned accounts.
10. Re-test payment initiation after connection succeeds.

---

## Most Likely Root Cause

Because the Save/Connect flow does not appear to call Paystack directly, the HTTP 403 is most likely caused by backend authorization or merchant-owner lookup, not by the Paystack key itself.

Since the account being used is reportedly the main merchant owner, the next most important thing to verify is not “are you a staff member?” but:

```text
Does the authenticated user ID in the current JWT exactly equal Merchant.owner_user_id in the database?
```

If those two IDs do not match, the service will fail to find the merchant and the router may return 403.

---

## Final Instruction To AI Agent

Do not redesign the payment architecture.

Keep the merchant-owned Paystack account model.

Fix the connection flow by:
1. confirming route authorization and owner lookup;
2. showing exact backend error details;
3. validating the secret key with Paystack before saving it as verified;
4. keeping merchant credentials encrypted;
5. keeping Paystack webhooks backend-only;
6. using merchant-specific secrets for all merchant payment initialization and verification.
