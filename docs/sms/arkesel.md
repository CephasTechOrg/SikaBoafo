# Arkesel — SMS & phone verification (integration guide)

This document is the **canonical reference for SikaBoafo** when integrating [Arkesel](https://arkesel.com/) for **phone number verification (OTP)** and related SMS. Always treat the vendor’s live documentation as the source of truth for field names and new API versions:

- **Official API docs:** [https://developers.arkesel.com/](https://developers.arkesel.com/)

https://sms.arkesel.com/sms/api?action=send-sms&api_key=&to=PhoneNumber&from=SenderID&sms=YourMessage
---

## 1. What we use it for

| Use case | Preferred API | Notes |
|----------|---------------|--------|
| **Merchant login / sign-up (OTP)** | **Phone verification (OTP)** | Arkesel generates, sends, and validates the code. BizTrack verifies **on the server** after the user submits the code. |
| **Transactional SMS** (alerts, receipts later) | **SMS API v2** | Optional; separate from auth OTP. |

For **authentication** (see `todo.md` section 6), the primary path is **OTP generate + OTP verify** (not “roll your own” OTP in the `message` field of bulk SMS unless product explicitly requires it).

---

## 2. Base URL & authentication

| Item | Value |
|------|--------|
| **API host** | `https://sms.arkesel.com` |
| **Auth** | HTTP header: `api-key: <your_key>` |
| **Content-Type** | `application/json` for JSON bodies |

**API key rules (important):**

- Create and manage keys in the **Arkesel Dashboard** → **SMS API** (sidebar).
- For **OTP / phone verification**, use the **Main SMS API key**. Vendor docs state that **sub-keys (“Multiple API Keys”) are not supported for OTP** — confirm in the current dashboard/docs before production.
- **Never** expose the API key in the mobile app, public repos, or client-side code. Only the **BizTrack backend** should call Arkesel.

---

## 3. Phone numbers

- Use **international format without `+`**, e.g. Ghana: `233XXXXXXXXX` (see Arkesel examples).
- Normalize user input in the backend (strip spaces, leading `0`, add `233` where appropriate) so `generate` and `verify` use the **same** canonical string.

---

## 4. OTP API (primary for BizTrack auth)

OTP is billed against **Main balance** (Voice and OTP services), not necessarily the same pool as bulk SMS credits — confirm balances in the dashboard.

### 4.1 Generate OTP (send SMS or voice)

| | |
|--|--|
| **Method & path** | `POST /api/otp/generate` |
| **Full URL** | `https://sms.arkesel.com/api/otp/generate` |

**Headers**

| Header | Required | Description |
|--------|----------|-------------|
| `api-key` | Yes | Main SMS API key |
| `Content-Type` | Yes | `application/json` |

**Body (JSON)** — align exact optional fields with [developers.arkesel.com](https://developers.arkesel.com/) Phone Verification section.

| Field | Type | Description |
|-------|------|-------------|
| `number` | string | Recipient phone (e.g. `233XXXXXXXXX`). |
| `expiry` | integer | Code lifetime in **minutes** (vendor range, typically **1–10**). |
| `length` | integer | OTP length (vendor range, typically **6–15**). |
| `type` | string | e.g. `numeric` or `alphanumeric`. |
| `medium` | string | `sms` or `voice`. |
| `sender_id` | string | Sender ID (**max 11 characters** including spaces). |
| `message` | string | SMS template; must include **`%otp_code%`** so Arkesel can inject the code. Some setups allow **`%expiry%`** for expiry text — confirm in docs. |

**Backend responsibilities after a successful generate response**

- Do **not** trust the client to “know” the OTP.
- Apply **rate limits** per phone number and per IP (abuse / SMS pumping).
- Optionally log **request id / correlation** from the response if the API returns one (check latest docs); **never** log the plaintext OTP.

### 4.2 Verify OTP

| | |
|--|--|
| **Method & path** | `POST /api/otp/verify` |
| **Full URL** | `https://sms.arkesel.com/api/otp/verify` |

**Headers:** same as generate (`api-key`, `Content-Type`).

**Body (JSON)**

| Field | Type | Description |
|-------|------|-------------|
| `number` | string | Same canonical number used in `generate`. |
| `code` | string | Code entered by the user. |

On **success**, the backend should issue **BizTrack session tokens** (e.g. JWT / refresh) per `architecture.md`. On failure, return a generic error to the client (avoid leaking whether the number exists).

---

## 5. SMS API v2 (reference — bulk / transactional)

Use when you need **full control of message text** (not the managed OTP product). Auth uses the same **`api-key`** header (v2 passes the key as a **header**, not query).

### 5.1 Send SMS

| | |
|--|--|
| **Method & path** | `POST /api/v2/sms/send` |
| **Full URL** | `https://sms.arkesel.com/api/v2/sms/send` |

**Body (JSON)**

| Field | Required | Description |
|-------|----------|-------------|
| `sender` | Yes | Sender ID, **max 11 characters**. |
| `recipients` | Yes | Array of MSISDN strings, e.g. `["233553995047"]`. |
| `message` | Yes | Message body (~160 chars = 1 page; longer = multiple pages). |
| `callback_url` | No | Delivery webhook; see section 5.3. |
| `scheduled_date` | No | Schedule: format `'Y-m-d H:i A'` (e.g. `2021-03-17 07:00 AM`). |
| `use_case` | No | `promotional` \| `transactional` — **Nigeria traffic only** per vendor. |
| `sandbox` | No | `true` = test send; not delivered to carriers; not billed. |

### 5.2 Template SMS

| | |
|--|--|
| **Path** | `POST /api/v2/sms/template/send` |

- `message` uses placeholders: `<%name%>`, `<%hometown%>`, etc.
- `recipients` is an object map: phone → variable map (see official examples).

### 5.3 Delivery callback (`callback_url`)

If you set `callback_url`, Arkesel calls it with query parameters:

| Parameter | Meaning |
|-----------|---------|
| `sms_id` | 16-character message UUID (also returned when sending with callback). |
| `status` | e.g. `DELIVERED`, `SUBMITTED`, `PROHIBITED`, `QUEUED`, `NOT_DELIVERED`, `EXPIRED`. |

The callback URL must be reachable **without** your app’s user auth (no `401` on the webhook).

### 5.4 Other useful v2 endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v2/clients/balance-details` | GET | SMS balance + main balance |
| `/api/v2/sms/{uuid}` | GET | Single message details / delivery status |
| `/api/v2/sms/message-reports` | POST | Batch status for up to 1000 UUIDs (`msg_ids`) |
| `/api/v2/contacts/groups` | POST | Create contact group |
| `/api/v2/contacts` | POST | Add contacts to a group |

---

## 6. HTTP status codes (v2 / general)

Consolidated from vendor docs (confirm on [developers.arkesel.com](https://developers.arkesel.com/)):

| Code | Meaning |
|------|---------|
|200 | Success (context depends on endpoint) |
| 201 | Created (e.g. some resource creates) |
| 401 | Authentication failed |
| 402 | Insufficient balance |
| 403 | Inactive gateway |
| 422 | Validation errors |
| 500 | Internal error |

Always parse JSON error bodies when present for debugging (server-side only).

---

## 7. Sandbox

- Sandbox/test modes let you exercise APIs **without carrier delivery** and **without** consuming paid quota for those paths (see dashboard and current docs).
- Use sandbox for **integration tests**; still **do not** commit real API keys.

---

## 8. Account setup (summary)

1. Sign up at Arkesel; verify phone and email.
2. Dashboard → **SMS API** → generate **Main API key** (and sub-keys only where supported).
3. Register / approve **sender ID** as required for your traffic (Ghana rules may differ from Nigeria `use_case` rules).
4. Top up **SMS plan** and/or **Main balance** as needed (OTP/Voice typically use **Main balance**).

Support: `support@arkesel.com` (per vendor site).

---

## 9. SikaBoafo backend checklist

When implementing `todo.md` section 6:

- [ ] Add env vars (names illustrative): `ARKESEL_API_KEY`, `ARKESEL_OTP_SENDER_ID`, optional `ARKESEL_BASE_URL=https://sms.arkesel.com`.
- [ ] Implement `POST /api/v1/auth/otp/request` → normalize phone → rate limit → `POST .../api/otp/generate`.
- [ ] Implement `POST /api/v1/auth/otp/verify` → `POST .../api/otp/verify` → on success create/find user → issue tokens.
- [ ] Store **no** long-term copy of OTP in BizTrack DB (Arkesel holds verification truth for the code).
- [ ] Structured logging without OTP plaintext; monitor `402`/`403`/`422` for ops.

---

## 10. Minimal Python examples (backend)

Replace placeholders; run only on the server.

**Generate OTP**

```python
import requests

url = "https://sms.arkesel.com/api/otp/generate"
headers = {
    "api-key": "YOUR_MAIN_API_KEY",
    "Content-Type": "application/json",
}
payload = {
    "number": "233XXXXXXXXX",
    "expiry": 5,
    "length": 6,
    "type": "numeric",
    "medium": "sms",
    "sender_id": "BizTrack",
    "message": "Your BizTrack code is %otp_code%. Valid for %expiry% minutes.",
}
resp = requests.post(url, json=payload, headers=headers, timeout=30)
resp.raise_for_status()
```

**Verify OTP**

```python
import requests

url = "https://sms.arkesel.com/api/otp/verify"
headers = {
    "api-key": "YOUR_MAIN_API_KEY",
    "Content-Type": "application/json",
}
payload = {"number": "233XXXXXXXXX", "code": "123456"}
resp = requests.post(url, json=payload, headers=headers, timeout=30)
resp.raise_for_status()
```

**Send SMS (v2)**

```python
import requests

url = "https://sms.arkesel.com/api/v2/sms/send"
headers = {
    "api-key": "YOUR_MAIN_API_KEY",
    "Content-Type": "application/json",
}
payload = {
    "sender": "BizTrack",
    "recipients": ["233XXXXXXXXX"],
    "message": "Hello from BizTrack.",
}
resp = requests.post(url, json=payload, headers=headers, timeout=30)
resp.raise_for_status()
```

---

## 11. Changelog in this repo

| Date | Change |
|------|--------|
|2026-04-14 | Reformatted for BizTrack; OTP-first; deduplicated v2 reference; added checklist and examples. |

If Arkesel changes paths or fields, update this file and the official link in section 1.
