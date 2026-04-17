import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/sync_providers.dart';
import '../data/debts_repository.dart';

class DebtsViewData {
  const DebtsViewData({
    required this.customers,
    required this.receivables,
  });

  final List<LocalDebtCustomer> customers;
  final List<LocalReceivableRecord> receivables;
}

final debtsRepositoryProvider = Provider<DebtsRepository>((ref) {
  return DebtsRepository(
    appDb: ref.watch(appDatabaseProvider),
    syncQueueRunner: ref.watch(syncQueueRunnerProvider),
  );
});

final debtsControllerProvider = AsyncNotifierProvider<DebtsController, DebtsViewData>(
  DebtsController.new,
);

final receivableDetailProvider = FutureProvider.family<LocalReceivableDetail?, String>((
  ref,
  receivableId,
) {
  return ref.watch(debtsRepositoryProvider).getReceivableDetail(receivableId);
});

class DebtsController extends AsyncNotifier<DebtsViewData> {
  DebtsRepository get _repo => ref.read(debtsRepositoryProvider);

  @override
  Future<DebtsViewData> build() async {
    try {
      await _repo.syncPendingQueue();
    } catch (_) {
      // Keep local mode resilient while failed rows remain for retry.
    }
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    return _loadViewData();
  }

  Future<void> refresh() async {
    await _repo.syncPendingQueue();
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    state = AsyncValue.data(await _loadViewData());
  }

  Future<void> createCustomer({
    required String name,
    String? phoneNumber,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.createCustomerLocal(name: name, phoneNumber: phoneNumber);
      await _repo.syncPendingQueue();
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.data(await _loadViewData());
    } catch (error, stackTrace) {
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> createReceivable({
    required String customerId,
    required String originalAmount,
    String? dueDateIso,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.createReceivableLocal(
        customerId: customerId,
        originalAmount: originalAmount,
        dueDateIso: dueDateIso,
      );
      await _repo.syncPendingQueue();
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.data(await _loadViewData());
    } catch (error, stackTrace) {
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> recordRepayment({
    required String receivableId,
    required String amount,
    required String paymentMethodLabel,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.recordRepaymentLocal(
        receivableId: receivableId,
        amount: amount,
        paymentMethodLabel: paymentMethodLabel,
      );
      await _repo.syncPendingQueue();
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.data(await _loadViewData());
    } catch (error, stackTrace) {
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<DebtsViewData> _loadViewData() async {
    final customers = await _repo.listCustomers();
    final receivables = await _repo.listReceivables();
    return DebtsViewData(customers: customers, receivables: receivables);
  }
}
