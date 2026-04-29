# Supabase Storage Integration

## Purpose

Supabase Storage is used as the CDN for product images in SikaBoafo. It serves two functions:

1. **Official product catalog** — A curated library of product images managed by the SikaBoafo team. Merchants browse and pick from these when adding inventory items.
2. **User-uploaded images** — Merchants can photograph their own products; those images are stored per-user under a private folder.

The backend (FastAPI/PostgreSQL) does **not** interact with Supabase Storage at all. All reads and writes happen directly from the Flutter app using the Supabase Flutter SDK and the public anon key.

---

## Bucket Layout

Single bucket: **`SikaBoafo`**

```
SikaBoafo/
├── Products/              ← official catalog images (team-managed)
│   ├── coca_cola.png
│   ├── indomie_instant-noodles.png
│   └── ...
└── UserUploads/
    └── <user_id>/         ← one folder per merchant
        └── <filename>
```

- The `Products/` folder is **public** — no auth needed to list or download.
- The `UserUploads/` folder should be restricted by RLS policies so each user can only read/write their own subfolder.

---

## Configuration

All Supabase constants live in `AppConfig` (`mobile/lib/app/env/app_config.dart`) and are compiled in at build time via `--dart-define`.

| Constant | Value | Source |
|---|---|---|
| `supabaseUrl` | `https://wrmicvmjlofprdvptsrq.supabase.co` | Hardcoded (project-level, not secret) |
| `supabaseAnonKey` | `''` (empty default) | `--dart-define=SUPABASE_ANON_KEY=<key>` |
| `supabaseBucket` | `SikaBoafo` | Hardcoded |
| `supabaseProductsFolder` | `Products` | Hardcoded |
| `supabaseUserUploadsFolder` | `UserUploads` | Hardcoded |

The anon key is **not** in source control. Pass it at build time:

```bash
flutter run \
  --dart-define=SUPABASE_ANON_KEY=eyJ... \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

For CI/CD or release builds, set `SUPABASE_ANON_KEY` as a build secret/environment variable and forward it via `--dart-define`.

---

## Initialization

`Supabase.initialize()` is called once in `main()` before `runApp()`:

```dart
// mobile/lib/main.dart
await Supabase.initialize(
  url: AppConfig.supabaseUrl,
  anonKey: AppConfig.supabaseAnonKey,
);
```

If `supabaseAnonKey` is empty (e.g. dev build without the define), the SDK initializes but all storage requests will return an "Invalid API key" error. The product catalog sheet surfaces this as a friendly error message with a Retry button.

---

## Core Service

**File:** `mobile/lib/core/services/supabase_storage_service.dart`

### `StorageProduct`

Plain data class returned by the catalog listing:

```dart
class StorageProduct {
  final String name;       // raw filename, e.g. "coca_cola.png"
  final String label;      // display name, e.g. "Coca Cola"
  final String publicUrl;  // CDN URL ready to pass to CachedNetworkImage
}
```

### `StorageService` (abstract)

Interface so the real implementation can be swapped for a fake in tests:

```dart
abstract class StorageService {
  Future<List<StorageProduct>> listOfficialProducts();
  Future<String> uploadUserImage({
    required String userId,
    required Uint8List bytes,
    required String filename,
  });
}
```

### `SupabaseStorageService`

The real implementation. Uses `Supabase.instance.client` (singleton initialized in `main()`).

**`listOfficialProducts()`**
1. Calls `storage.from('SikaBoafo').list(path: 'Products')`.
2. Filters out `.emptyFolderPlaceholder` and any dot-files.
3. Calls `getPublicUrl()` for each file — this is synchronous and builds the CDN URL without an extra network request.
4. Converts the raw filename to a human-readable label via `labelFromFilename()`.

**`uploadUserImage()`**
1. Builds path: `UserUploads/<userId>/<filename>`.
2. Calls `uploadBinary()` with `upsert: true` (overwrites if same path exists).
3. Returns the public CDN URL of the uploaded image.

**`labelFromFilename()` (static, `@visibleForTesting`)**

Strips the file extension, then title-cases each word split by `_`, `-`, or `.`:

| Filename | Label |
|---|---|
| `coca_cola.png` | `Coca Cola` |
| `malt-drink.jpg` | `Malt Drink` |
| `indomie_instant-noodles.png` | `Indomie Instant Noodles` |
| `fan__ice.jpg` | `Fan Ice` |
| `COCA_COLA.PNG` | `Coca Cola` |

---

## Riverpod Providers

**File:** `mobile/lib/shared/providers/storage_providers.dart`

```dart
// Service singleton — swap this in tests to inject a fake
final supabaseStorageServiceProvider = Provider<StorageService>((ref) {
  return SupabaseStorageService();
});

// Cached product list — lives as long as the provider is watched
final officialProductsProvider = FutureProvider<List<StorageProduct>>((ref) async {
  return ref.watch(supabaseStorageServiceProvider).listOfficialProducts();
});
```

`officialProductsProvider` is an `AsyncValue` — the catalog sheet handles all three states (loading spinner, error with retry, data grid).

To force a refresh (e.g. after an error retry tap): `ref.invalidate(officialProductsProvider)`.

---

## Product Catalog Sheet

**File:** `mobile/lib/shared/widgets/product_catalog_sheet.dart`

Entry point: `showProductCatalogSheet(BuildContext context)` — returns `Future<String?>` where the string is the selected product's public CDN URL, or `null` if dismissed.

The sheet is a `DraggableScrollableSheet` (88 % initial, 96 % max) containing:
- Search bar that filters by `label` and `name` (case-insensitive, client-side).
- 3-column `GridView` of `_ProductTile` widgets backed by `CachedNetworkImage`.
- Tapping a tile calls `Navigator.pop(url)` — the caller receives the URL.

Error states:
- **"Invalid API key"** → `"Supabase anon key not configured. Add SUPABASE_ANON_KEY to your build config."`
- **Network error** → `"No internet connection. Check your network and try again."`
- **Other** → `"Failed to load product catalog. Tap to retry."`

---

## Adding New Official Products

Upload images directly to the `Products/` folder in the Supabase dashboard or via the Supabase CLI:

```bash
supabase storage cp ./my_product.png ss:///SikaBoafo/Products/my_product.png
```

Naming convention: `snake_case` or `kebab-case`, lowercase, descriptive.  
Example: `peak_milk_tin.png` → displays as **"Peak Milk Tin"**.

No app release is needed — the catalog sheet fetches live from Storage on every open.

---

## Row Level Security (RLS) Policies

All policies live on `storage.objects`. Run this block once in the Supabase SQL editor whenever the bucket is recreated or policies are wiped.

```sql
-- 1. Anyone (including unauthenticated) can list the official Products catalog
CREATE POLICY "Public read Products folder"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (
  bucket_id = 'SikaBoafo'
  AND (storage.foldername(name))[1] = 'Products'
);

-- 2. Authenticated users can list only their own uploads folder
CREATE POLICY "Users read own uploads"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'SikaBoafo'
  AND (storage.foldername(name))[1] = 'UserUploads'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- 3. Authenticated users can upload into their own folder only
CREATE POLICY "Users insert own uploads"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'SikaBoafo'
  AND (storage.foldername(name))[1] = 'UserUploads'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- 4. Authenticated users can overwrite (upsert) their own files
CREATE POLICY "Users update own uploads"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'SikaBoafo'
  AND (storage.foldername(name))[1] = 'UserUploads'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- 5. Authenticated users can delete their own files
CREATE POLICY "Users delete own uploads"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'SikaBoafo'
  AND (storage.foldername(name))[1] = 'UserUploads'
  AND (storage.foldername(name))[2] = auth.uid()::text
);
```

| # | Who | Folder | Operation |
|---|---|---|---|
| 1 | Everyone (anon + authenticated) | `Products/` | List & read catalog |
| 2 | Logged-in user | `UserUploads/<their-id>/` | List own uploads only |
| 3 | Logged-in user | `UserUploads/<their-id>/` | Upload new files |
| 4 | Logged-in user | `UserUploads/<their-id>/` | Overwrite existing files (`upsert: true`) |
| 5 | Logged-in user | `UserUploads/<their-id>/` | Delete own files |

**Key points:**
- Policy 1 uses `TO anon, authenticated` so the catalog sheet works before a merchant logs in.
- Policies 2–5 use `auth.uid()::text` which matches the user's UUID against the second path segment — merchant A cannot touch merchant B's folder.
- `getPublicUrl()` calls bypass RLS entirely (CDN serving) — no policy needed for downloads from a public bucket.
- A broad `SELECT` policy covering the whole bucket will trigger a Supabase security warning; these scoped policies avoid that.

---

## Dependencies

`pubspec.yaml`:

```yaml
supabase_flutter: ^2.9.0
cached_network_image: ^3.x   # used in _ProductTile for CDN image caching
```

---

## Testing

`mobile/test/core/services/supabase_storage_service_test.dart` covers `labelFromFilename` with 8 cases (extension stripping, separator variants, consecutive separators, case normalisation).

For widget/integration tests that use `officialProductsProvider`, override `supabaseStorageServiceProvider` with a fake:

```dart
final fakeStorage = FakeStorageService(products: [
  StorageProduct(name: 'test.png', label: 'Test', publicUrl: 'https://example.com/test.png'),
]);

await tester.pumpWidget(
  ProviderScope(
    overrides: [
      supabaseStorageServiceProvider.overrideWithValue(fakeStorage),
    ],
    child: const MyWidget(),
  ),
);
```
