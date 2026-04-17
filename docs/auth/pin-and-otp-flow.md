# BizTrack GH — Phone, OTP, and PIN authentication

This document is the **source of truth** for how merchants sign in, how SMS cost is controlled, and how the mobile and backend pieces fit together.

## Goals

- **Low SMS cost:** OTP over SMS is used only when it adds real security (first-time setup, recovery), not on every app open.
- **Fast daily login:** Returning merchants use **phone number + PIN**, similar to common mobile-money patterns in Ghana.
- **Simple mental model:** One phone number = one account. “Create account” and “Sign in” differ only by the first screen; the server still creates the user on first successful OTP if needed.

## Roles of each factor

| Mechanism | When it is used |
|-----------|-----------------|
| **SMS OTP** | New device / new account path: prove control of the phone number. **Forgot PIN:** same OTP flow, then set a new PIN. |
| **PIN (4–6 digits)** | **Normal login:** after onboarding and PIN setup, day-to-day sign-in is phone + PIN only (no SMS). |
| **Access / refresh tokens** | API session after any successful login (OTP or PIN). Mobile stores these in secure storage; a valid access token skips the login UI on cold start (see splash). |

## End-to-end flows

### 1) Create account (new merchant)

1. User chooses **Create account**, enters phone number.
2. `POST /api/v1/auth/otp/request` sends OTP (Arkesel) or uses dev mock.
3. User enters OTP → `POST /api/v1/auth/otp/verify` returns tokens and `onboarding_required`.
4. If onboarding is required → complete business profile → `POST /api/v1/auth/onboarding/complete`.
5. User sets a PIN → `POST /api/v1/auth/pin/set` (Bearer access token).
6. Client navigates to home.

### 2) Sign in (returning merchant)

1. User chooses **Sign in**, enters phone + PIN.
2. `POST /api/v1/auth/pin/login` returns tokens (no SMS).
3. If onboarding is still incomplete (`onboarding_required: true`), client sends user to onboarding, then PIN setup if needed.

### 3) Forgot PIN

1. From sign-in, user opens **Forgot PIN?** and enters phone number.
2. Same OTP request/verify as create-account path.
3. With a valid session, user sets a new PIN via `POST /api/v1/auth/pin/set` (overwrites previous hash).

### 4) Cold start / session still valid

- If secure storage has a non-expired **access** token, the app can open **home** directly (splash).
- When access expires, implement **refresh** (future) or send the user back to **Sign in** (phone + PIN). OTP is not required unless the user is locked out or chooses recovery.

## API summary

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/api/v1/auth/otp/request` | None | Send OTP |
| POST | `/api/v1/auth/otp/verify` | None | Verify OTP → tokens + `onboarding_required` + `pin_set` |
| POST | `/api/v1/auth/pin/login` | None | Phone + PIN → tokens + `onboarding_required` + `pin_set` |
| POST | `/api/v1/auth/pin/set` | Bearer access | Set or replace PIN hash |
| POST | `/api/v1/auth/onboarding/complete` | Bearer access | Business + default store |

## Response flags (client routing)

- **`onboarding_required`:** merchant profile not completed → onboarding screen.
- **`pin_set`:** if `false` after OTP, client must show **Set PIN** before home (covers new accounts and legacy users without a PIN).

## Security notes

- **PIN storage:** Server stores only a **scrypt** hash (salt per user); never store plaintext PINs.
- **PIN login errors:** Wrong phone or wrong PIN returns the same generic message to reduce user enumeration.
- **PIN not set:** If the user has never set a PIN, PIN login returns a distinct error so the app can offer OTP verification.
- **HTTPS:** Production must terminate TLS in front of the API; PIN and tokens must never go over plain HTTP.

## Operational / cost

- Budget SMS for: signups, Forgot PIN, and any future “step-up” challenges—not for daily opens.
- Monitor Arkesel usage; alert on spikes (possible abuse or client bug calling OTP too often).

## Related files

- Backend: `app/services/auth_service.py`, `app/services/pin_hash.py`, `app/api/v1/auth.py`, `app/models/user.py`
- Mobile: `lib/features/auth/`, `lib/features/onboarding/`, set-PIN route in `lib/app/router.dart`

## Changelog

- **2026-04-15:** Initial PIN + OTP split documented; aligns with MVP merchant UX and SMS cost control.
