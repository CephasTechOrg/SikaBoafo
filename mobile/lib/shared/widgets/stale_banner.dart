import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/freshness_providers.dart';
import '../providers/sync_providers.dart';

/// Shows a dismissable warning when the backend has been unreachable for more
/// than 24 hours. Dismissed state persists per-screen per-day in kv_cache.
class StaleBanner extends ConsumerWidget {
  const StaleBanner({super.key, required this.screenKey, required this.kvKey});

  /// Unique key for this screen, used to namespace the dismissal entry.
  final String screenKey;

  /// The kv_cache key for this screen's last-sync timestamp.
  final String kvKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncAsync = ref.watch(syncStatusControllerProvider);
    final tsAsync = ref.watch(freshnessTsProvider(kvKey));
    final snapshot = syncAsync.valueOrNull;

    if (snapshot == null || snapshot.backendReachable) {
      return const SizedBox.shrink();
    }

    final ts = tsAsync.valueOrNull;
    final isStale = ts == null ||
        DateTime.now().difference(ts) > const Duration(hours: 24);

    if (!isStale) return const SizedBox.shrink();

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final dismissKey = 'stale_dismissed_${screenKey}_$today';

    return FutureBuilder<String?>(
      future: ref.read(appDatabaseProvider).kv.get(dismissKey),
      builder: (context, snap) {
        if (snap.data != null) return const SizedBox.shrink();
        return MaterialBanner(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          content: const Text(
            'You are offline and data may be outdated.',
            style: TextStyle(fontSize: 13),
          ),
          leading: const Icon(Icons.cloud_off_rounded, size: 20),
          actions: [
            TextButton(
              onPressed: () async {
                await ref
                    .read(appDatabaseProvider)
                    .kv
                    .put(dismissKey, '"1"');
                ref.invalidate(freshnessTsProvider(kvKey));
              },
              child: const Text('Dismiss'),
            ),
          ],
        );
      },
    );
  }
}
