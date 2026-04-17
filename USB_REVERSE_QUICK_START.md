# USB Reverse Forwarding - Quick Reference Card

**Version:** 1.0  
**Date:** April 16, 2026  
**Project:** BizTrack GH  
**Print this page** and keep it at your desk for daily development.  

---

## Why It Works (Simple Explanation)

**The Problem:**

- Phone can't reach your computer's backend on WiFi
- School WiFi blocks device-to-device communication
- Using `192.168.x.x` doesn't work because of network isolation
- Using `127.0.0.1` makes the phone look for a server ON THE PHONE

**The Solution:**

- USB cable creates a direct tunnel
- Phone's `127.0.0.1` → [tunnel] → Computer's `127.0.0.1`
- No WiFi needed, no IP confusion, works everywhere

---

## Every Session: 3 Simple Commands

### ① Terminal 1: Create USB Tunnel

**Run this:**
```powershell
C:\Users\USER\AppData\Local\Android\Sdk\platform-tools\adb reverse tcp:8000 tcp:8000
```

**Expected Output:**
```
(no output = success)
```

**What it does:**  
Creates a tunnel so your phone's `127.0.0.1:8000` points to your computer's `127.0.0.1:8000`

**Notes:**
- Run once per USB session
- Command returns immediately
- Tunnel stays active in background
- Requires USB cable connected

---

### ② Terminal 2: Start Backend

**Run this:**
```powershell
cd backend
uvicorn app.main:app --reload
```

**Expected Output:**
```
INFO:     Uvicorn running on http://127.0.0.1:8000
INFO:     Application startup complete
```

**What it does:**  
Starts your FastAPI backend and listens for requests from the phone

**Notes:**
- Keep this terminal open (don't close it)
- All API request logs appear here
- If you see errors, check the database is running

---

### ③ Terminal 3: Deploy Mobile App

**Run this:**
```powershell
cd mobile
flutter run
```

**When prompted:**
```
Connected devices:
1 • Your Phone (mobile) • android-arm64 • Android
Select a device by number or name: 1
```

**Expected Output:**
```
✓ Built build/app/outputs/flutter-apk/app-debug.apk
Installing and launching...
✓ Installation successful.
```

**What it does:**  
Builds the Flutter app and deploys it to your phone

**Notes:**
- Select your phone device
- App appears on phone in ~30-60 seconds
- Keep terminal open for live debugging

---

## ✅ Test the Connection

**Step 1:** On your phone, tap any button that calls the backend  
(Example: "Request OTP" in login screen)

**Step 2:** In Terminal 2 (backend logs), look for this:
```
INFO:     127.0.0.1:52341 - "POST /api/v1/auth/otp/request HTTP/1.1" 200 OK
```

**Result:**
- ✅ See the log above? **Connection works!**
- ❌ Don't see it? Check troubleshooting section below

**What the log means:**
- `127.0.0.1:52341` = phone is calling your computer
- `POST` = the request type
- `200 OK` = backend responded successfully

---

## Prerequisites (Do Once)

- ✅ USB Debugging enabled on phone (Settings → Developer Options)
- ✅ Phone connected to computer via USB cable
- ✅ Android SDK installed
- ✅ `mobile/lib/app/env/app_config.dart` uses `http://127.0.0.1:8000` (already configured)

---

## If Something Goes Wrong

| Issue                             | Fix                                                                         |
| --------------------------------- | --------------------------------------------------------------------------- |
| ADB not found                     | Use full path: `C:\Users\USER\AppData\Local\Android\Sdk\platform-tools\adb` |
| Phone shows "Cannot reach server" | Check Terminal 2 is running, USB is connected, app is fresh                 |
| No logs in Terminal 2             | Phone might be caching URL; hot reload app or restart it                    |
| USB unplugged by accident         | Just plug back in; tunnel reactivates automatically                         |

---

## Your Three Terminals Layout

| Terminal | Command | Stays Open? | Shows What |
|----------|---------|-------------|------------|
| **T1** | `adb reverse tcp:8000 tcp:8000` | No (returns immediately) | Nothing (unless error) |
| **T2** | `uvicorn app.main:app --reload` | YES, always | Backend logs + requests |
| **T3** | `flutter run` | YES, always | App build + debug logs |
| **Phone** | (user taps buttons) | YES, always | Running app |

**Important:**
- Keep Terminal 2 and 3 open while developing
- Terminal 1 only needs to run once, then can close
- When you tap a button on phone → you should see logs in Terminal 2

---

## When USB is Unplugged

```
Unplugged USB Cable
  ↓
Phone: "Cannot reach server"
Terminal 2: (no logs)
  ↓
Plug USB back in
  ↓
Tap button on phone again
  ↓
Logs reappear in Terminal 2 ✅
```

**Note:** You only need to run `adb reverse` once per USB connection.

---

## Cheat Sheet (Copy-Paste Ready)

```powershell
# Terminal 1 - Run once
C:\Users\USER\AppData\Local\Android\Sdk\platform-tools\adb reverse tcp:8000 tcp:8000

# Terminal 2 - Keep open
cd backend
uvicorn app.main:app --reload

# Terminal 3 - Keep open
cd mobile
flutter run
```

---

**✅ Print this page and keep it at your desk!**
