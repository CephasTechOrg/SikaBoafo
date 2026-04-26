import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/sync_providers.dart';
import '../data/sales_payments_api.dart';
import '../data/sales_repository.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(
    appDb: ref.watch(appDatabaseProvider),
    syncQueueRunner: ref.watch(syncQueueRunnerProvider),
  );
});

final salesControllerProvider =
    AsyncNotifierProvider.autoDispose<SalesController, List<LocalSaleRecord>>(
  SalesController.new,
);

final salesPaymentsApiProvider = Provider<SalesPaymentsApi>((ref) {
  return SalesPaymentsApi(ref.watch(apiClientProvider));
});

class SalesController extends AutoDisposeAsyncNotifier<List<LocalSaleRecord>> {
  SalesRepository get _repo => ref.read(salesRepositoryProvider);
  bool _includeVoided = false;

  Future<List<LocalSaleRecord>> _loadSales() {
    return _repo.listRecentSales(includeVoided: _includeVoided);
  }

  @override
  Future<List<LocalSaleRecord>> build() async {
    try {
      await _repo.syncPendingQueue();
    } catch (_) {
      // Keep offline mode resilient; failed queue rows remain for retry.
    }
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    return _loadSales();
  }

  Future<void> refresh({bool? includeVoided}) async {
    if (includeVoided != null) {
      _includeVoided = includeVoided;
    }
    await _repo.syncPendingQueue();
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    state = AsyncValue.data(await _loadSales());
  }

  Future<void> recordSale({
    required String paymentMethodLabel,
    required List<SaleDraftLine> lines,
    String? note,
  }) async {
    await recordSaleReturningId(
      paymentMethodLabel: paymentMethodLabel,
      lines: lines,
      note: note,
    );
  }

  Future<String> recordSaleReturningId({
    required String paymentMethodLabel,
    required List<SaleDraftLine> lines,
    String? note,
  }) async {
    state = const AsyncLoading();
    try {
      final saleId = await _repo.createSaleLocal(
        paymentMethodLabel: paymentMethodLabel,
        lines: lines,
        note: note,
      );
      await _repo.syncPendingQueue();
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.data(await _loadSales());
      return saleId;
    } catch (error, stackTrace) {
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> updateSale({
    required String saleId,
    required String paymentMethodLabel,
    required List<SaleQuantityUpdateDraft> lines,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.updateSaleLocal(
        saleId: saleId,
        paymentMethodLabel: paymentMethodLabel,
        lines: lines,
      );
      await _repo.syncPendingQueue();
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.data(await _loadSales());
    } catch (error, stackTrace) {
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> voidSale({
    required String saleId,
    String? reason,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.voidSaleLocal(saleId: saleId, reason: reason);
      await _repo.syncPendingQueue();
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.data(await _loadSales());
    } catch (error, stackTrace) {
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<LocalSaleEditable?> loadSaleEditable({required String saleId}) {
    return _repo.loadSaleEditable(saleId: saleId);
  }
}
