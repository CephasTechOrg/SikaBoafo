import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/sync_providers.dart';
import '../data/sales_repository.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(
    appDb: ref.watch(appDatabaseProvider),
    syncQueueRunner: ref.watch(syncQueueRunnerProvider),
  );
});

final salesControllerProvider =
    AsyncNotifierProvider<SalesController, List<LocalSaleRecord>>(
  SalesController.new,
);

class SalesController extends AsyncNotifier<List<LocalSaleRecord>> {
  SalesRepository get _repo => ref.read(salesRepositoryProvider);

  @override
  Future<List<LocalSaleRecord>> build() async {
    try {
      await _repo.syncPendingQueue();
    } catch (_) {
      // Keep offline mode resilient; failed queue rows remain for retry.
    }
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    return _repo.listRecentSales();
  }

  Future<void> refresh() async {
    await _repo.syncPendingQueue();
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    state = AsyncValue.data(await _repo.listRecentSales());
  }

  Future<void> recordSale({
    required String paymentMethodLabel,
    required List<SaleDraftLine> lines,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.createSaleLocal(
        paymentMethodLabel: paymentMethodLabel,
        lines: lines,
      );
      await _repo.syncPendingQueue();
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.data(await _repo.listRecentSales());
    } catch (error, stackTrace) {
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}
