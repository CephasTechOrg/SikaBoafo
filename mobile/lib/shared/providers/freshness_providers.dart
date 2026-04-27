import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/kv_cache_repository.dart';
import 'core_providers.dart';

/// Reads the last-synced timestamp for a given kv key (e.g.
/// [KvCacheRepository.kInventoryTs]). Auto-disposes so it re-reads from
/// the database each time the consuming widget mounts.
final freshnessTsProvider =
    FutureProvider.autoDispose.family<DateTime?, String>((ref, key) async {
  final appDb = ref.watch(appDatabaseProvider);
  return appDb.kv.getTimestamp(key);
});
