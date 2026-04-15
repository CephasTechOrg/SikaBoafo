# BizTrack GH — Mobile (Flutter)

Offline-first client. Layout follows `folderstructure.md`; `todo.md` §5 tracks setup tasks.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable), `flutter` on your `PATH`.
- For Android: Android Studio / SDK; for iOS (macOS): Xcode.

## First-time bootstrap (platform folders)

This repo contains `lib/`, `pubspec.yaml`, and assets. **Android / iOS / web / desktop** host projects are created by the Flutter tool:

```bash
cd mobile
flutter create . --org com.biztrackgh.app --project-name biztrack_gh
```

Flutter merges with existing files; keep `lib/` as the source of truth. The `UI MockUps/` folder stays as reference only.

```bash
flutter pub get
flutter analyze
flutter test
```

### Run

```bash
# Android emulator (API base URL for emulator loopback)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Physical device on same LAN as your PC (use the PC's LAN IP)
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
```

Default API base is `http://127.0.0.1:8000` (works for desktop/web; use `10.0.2.2` on Android emulator).

## What is wired (§5 foundation)

| Area | Notes |
|------|--------|
| **Routing** | `go_router`: splash → auth placeholder → dashboard shell |
| **State** | `flutter_riverpod` + `core_providers.dart` |
| **HTTP** | `dio` + `ApiClient` (`AppConfig.apiV1`) + bearer from `SecureTokenStorage` |
| **Secrets** | `flutter_secure_storage` for access/refresh tokens |
| **Local DB** | `sqflite`: `local_meta` + `sync_queue` (idempotency: `source_device_id` + `local_operation_id`) |
| **Theme** | `app/theme/app_theme.dart` (teal seed; extend with design tokens in §2) |

Domain tables (items, sales, …) will be added incrementally; the **sync queue** is the first persistence slice aligned with `docs/architecture/id_strategy.md`.

## Commands cheat sheet

| Command | Purpose |
|---------|---------|
| `flutter pub get` | Resolve dependencies |
| `flutter analyze` | Static analysis |
| `flutter test` | Unit/widget tests |
| `dart format lib test` | Format Dart sources |
