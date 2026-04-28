import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/supabase_storage_service.dart';

final supabaseStorageServiceProvider = Provider<StorageService>((ref) {
  return SupabaseStorageService();
});

/// Fetches official product images from Supabase Storage.
/// Riverpod caches the result for the provider's lifetime.
final officialProductsProvider =
    FutureProvider<List<StorageProduct>>((ref) async {
  return ref.watch(supabaseStorageServiceProvider).listOfficialProducts();
});
