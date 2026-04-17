# Mobile-Backend Debugging Setup with USB Reverse Forwarding

**Document Version:** 1.0  
**Created:** April 16, 2026  
**Last Updated:** April 16, 2026  
**For Project:** BizTrack GH  
**Method:** USB Reverse Forwarding via ADB  

---

## How to Use This Guide

- **Quick setup?** → Jump to "Setup Steps" section
- **Need to understand why?** → Read "The Problem We Solved" first
- **Troubleshooting?** → Search for your issue in "Troubleshooting" section
- **Every day?** → Print/bookmark "Your Three Terminals" table and "Summary" section

---

## Overview

This document explains how to develop and test the BizTrack GH Flutter mobile app on your Android phone while your backend runs locally on your computer.

---

## The Problem We Solved

### Why Initial Setup Failed

When you first tried to run the Flutter app on your phone, it couldn't communicate with your backend. Here's why:

#### The Network Isolation Problem

```
Your Computer                          Your Phone
(Backend running)            ←→       (Flutter app)
Port 8000                    WiFi or USB

When your app tried: http://192.168.x.x:8000
Problem: 192.168.x.x is your COMPUTER's IP
         But from the phone's perspective, it couldn't reach it
         (WiFi might be blocked, IP might be wrong, routing broken)

When your app tried: http://127.0.0.1:8000
Problem: 127.0.0.1 = "myself" (localhost)
         The phone looked for a backend ON THE PHONE ITSELF
         But there's nothing there! ❌
```

### Why School WiFi Made It Worse

School networks often:

- Block direct device-to-device communication (isolated networks)
- Don't allow arbitrary port traffic (8000, 8080, etc.)
- Have CORS restrictions

So even if you got the IP right, the network itself blocked the connection.

---

## The Solution: USB Reverse Forwarding

### How USB Reverse Works

USB reverse forwarding creates a **direct tunnel through the USB cable** that makes the phone's `127.0.0.1:8000` point to your computer's `127.0.0.1:8000`.

```
Before USB Reverse:
  Phone's 127.0.0.1 = THE PHONE ITSELF ❌

After USB Reverse:
  Phone's 127.0.0.1 → [USB Tunnel] → Computer's 127.0.0.1 ✅
```

### Why This Works

1. **Direct connection** — USB cable is physical, not WiFi
2. **No network isolation** — doesn't depend on WiFi settings
3. **School WiFi irrelevant** — USB cable bypasses all network restrictions
4. **Instant routing** — the phone knows exactly where 127.0.0.1 goes (through the USB tunnel)
5. **Zero configuration** — no IP addresses to get wrong, no DNS issues

---

## What's Happening Now (Why It Works)

### The Technical Flow

When you tap a button in your Flutter app:

```
1. User taps "Login" button
   ↓
2. Flutter code: http.post('http://127.0.0.1:8000/api/v1/auth/otp/request')
   ↓
3. Phone OS: "I need to reach 127.0.0.1:8000"
   ↓
4. USB Reverse Tunnel intercepts: "Oh! That's my computer. Route it through USB."
   ↓
5. Request travels through USB cable (at lightspeed, basically)
   ↓
6. Computer receives: "Someone's calling my port 8000"
   ↓
7. FastAPI backend processes the request
   ↓
8. Response travels back through USB cable
   ↓
9. Phone receives response, app updates ✅
```

### Why Your Current Configuration is Perfect

In `mobile/lib/app/env/app_config.dart`:

```dart
static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',  // ✅ Localhost!
);
```

This is perfect because:

- ✅ Uses `127.0.0.1` (localhost) — works with USB tunnel
- ✅ Has a default value — no need to pass flags every time
- ✅ Can be overridden with `--dart-define` if needed for other environments

---

## Setup Steps (Run These Every Development Session)

### Prerequisites (One-Time Setup)

- USB cable connected to your phone
- USB Debugging enabled on phone (Settings → Developer Options → USB Debugging)
- Android SDK installed (you have this)
- Backend code ready
- Mobile code ready

### Every Time You Want to Debug

#### Step 1: Set Up USB Reverse Tunnel

**Terminal 1:**

```powershell
C:\Users\USER\AppData\Local\Android\Sdk\platform-tools\adb reverse tcp:8000 tcp:8000
```

**Output:** No output = success. The tunnel is now active.

**What it does:** Creates a bridge so the phone's `127.0.0.1:8000` reaches your computer's `127.0.0.1:8000`.

---

#### Step 2: Start Your Backend

**Terminal 2:**

```powershell
cd backend
uvicorn app.main:app --reload
```

**Expected output:**

```
INFO:     Uvicorn running on http://127.0.0.1:8000
INFO:     Application startup complete
```

**What it does:** Starts your FastAPI server listening on port 8000.

**Keep this terminal open** — you'll see all API requests here.

---

#### Step 3: Deploy and Run Flutter App

**Terminal 3:**

```powershell
cd mobile
flutter run
```

**When prompted for device:**

```
Connected devices:
1 • Your Phone (mobile) • android-arm64 • Android
Select a device by number or name: 1
```

Type `1` and press Enter.

**Expected output:**

```
✓ Built build/app/outputs/flutter-apk/app-debug.apk
Installing and launching...
✓ Installation successful.
```

The app appears on your phone. ✅

---

#### Step 4: Test the Connection

**On your phone:**

1. Tap any button that calls the backend (e.g., "Request OTP" in login)

**In Terminal 2 (backend logs), you should see:**

```
INFO:     127.0.0.1:52341 - "POST /api/v1/auth/otp/request HTTP/1.1" 200 OK
```

**If you see that log, the connection works!** ✅

---

## Your Three Terminals (Always Running Together)

| Terminal 1         | Terminal 2                      | Terminal 3                |
| ------------------ | ------------------------------- | ------------------------- |
| `adb reverse...`   | `uvicorn app.main:app --reload` | `flutter run`             |
| Manages USB tunnel | Backend API server              | App on phone              |
| (stays quiet)      | (shows request logs)            | (shows build/deploy logs) |

---

## Troubleshooting

### Problem: "ADB is not recognized"

**Solution:** Use the full path:

```powershell
C:\Users\USER\AppData\Local\Android\Sdk\platform-tools\adb reverse tcp:8000 tcp:8000
```

Or add it to your PATH (one-time setup):

- Windows Key → "Environment Variables"
- Add: `C:\Users\USER\AppData\Local\Android\Sdk\platform-tools` to PATH
- Restart PowerShell

### Problem: Phone Says "Cannot reach server"

**Checklist:**

- [ ] USB cable connected
- [ ] `adb reverse tcp:8000 tcp:8000` ran with no errors
- [ ] Backend is running on Terminal 2
- [ ] Terminal 2 shows `Uvicorn running on http://127.0.0.1:8000`
- [ ] Phone app is fresh (hot reload or restart)

If all checked, try:

```powershell
C:\Users\USER\AppData\Local\Android\Sdk\platform-tools\adb reverse --list
```

Should show:

```
127.0.0.1 tcp:8000 127.0.0.1 tcp:8000
```

### Problem: Backend Doesn't See Requests

If you tap buttons in the app but no logs appear in Terminal 2:

- Phone might be caching old API URL
- Hot reload the app: press `r` in Terminal 3
- Or restart the app on your phone

### Problem: Unplug USB Cable Accidentally

If you unplug:

- The tunnel breaks
- The app shows "Cannot reach server"
- Plug back in
- The tunnel is still active (adb stays connected)
- Refresh the app on your phone
- It works again

---

## When to Use Other Methods

### Local IP (192.168.x.x:8000)

- ✅ Fast
- ✅ Works at home on your personal WiFi
- ❌ Doesn't work on school WiFi
- ❌ Requires both devices on same network

### Render Blueprint Deployment

- ✅ Production-like testing
- ✅ Works anywhere (including school)
- ❌ Slower (2–3 minute deploy)
- ❌ Costs money
- **Use this:** For final integration testing, not daily development

### ngrok Tunneling

- ✅ Works anywhere
- ✅ Fast enough for testing
- ❌ Creates public URL (potential security concern)
- **Use this:** If USB doesn't work and you need mobile testing without Render

---

## Summary

### Why USB Reverse Is Best for Daily Development

| Aspect               | USB Reverse | Local IP | Render | ngrok |
| -------------------- | ----------- | -------- | ------ | ----- |
| Works on school WiFi | ✅          | ❌       | ✅     | ✅    |
| Instant feedback     | ✅          | ✅       | ❌     | ✅    |
| No network tricks    | ✅          | ❌       | ✅     | ⚠️    |
| Production-like      | ❌          | ❌       | ✅     | ❌    |
| Cost                 | Free        | Free     | $7/mo  | Free  |

---

## Quick Reference Card

**Each development session:**

```powershell
# Terminal 1 - Set up tunnel
C:\Users\USER\AppData\Local\Android\Sdk\platform-tools\adb reverse tcp:8000 tcp:8000

# Terminal 2 - Start backend
cd backend
uvicorn app.main:app --reload

# Terminal 3 - Run Flutter app
cd mobile
flutter run
```

**Then on your phone:**

- Tap any API button
- Check Terminal 2 for logs

**If it works:** You see `INFO:     127.0.0.1:XXXXX - "POST /api/v1/... HTTP/1.1" 200 OK`

✅ **Ready to develop!**

---

## Key Insights

1. **USB reverse is a tunnel** — It doesn't change your code; it changes how the network works
2. **Localhost (127.0.0.1) is perfect** — Your app config already uses it, so no changes needed
3. **USB cable is the key** — It bypasses all WiFi complexity
4. **Three terminals, always together** — Tunnel + Backend + App is the standard setup
5. **School WiFi is no longer a blocker** — USB doesn't care about network restrictions

---

**Created:** April 16, 2026  
**For:** BizTrack GH Project  
**Method:** USB Reverse Forwarding  
**Stack:** Flutter + FastAPI + Android SDK
