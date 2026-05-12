import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/sync_providers.dart';
import '../data/debts_repository.dart';

final debtsRepositoryProvider = Provider<DebtsRepository>((ref) {
  return DebtsRepository(
    appDb: ref.watch(appDatabaseProvider),
    syncQueueRunner: ref.watch(syncQueueRunnerProvider),
  );
});

final debtsControllerProvider =
    AsyncNotifierProvider.autoDispose<DebtsController, DebtsViewData>(
  DebtsController.new,
);

class DebtsController extends AutoDisposeAsyncNotifier<DebtsViewData> {
  DebtsRepository get _repo => ref.read(debtsRepositoryProvider);

  @override
  Future<DebtsViewData> build() async {
    try {
      await _repo.syncPendingQueue();
    } catch (_) {
      // Stay in local mode; queue rows will retry on the next cycle.
    }
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    return _readSnapshot();
  }

  Future<void> refresh() async {
    try {
      await _repo.syncPendingQueue();
    } catch (_) {
      // ignore — keep local snapshot fresh regardless
    }
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    state = AsyncValue.data(await _readSnapshot());
  }

  Future<String> createCustomer({
    required String name,
    String? phoneNumber,
    String? whatsappNumber,
    String? email,
    String? notes,
    bool useLoadingState = true,
  }) async {
    if (useLoadingState) state = const AsyncLoading();
    try {
      final customerId = await _repo.createCustomerLocal(
        name: name,
        phoneNumber: phoneNumber,
        whatsappNumber: whatsappNumber,
        email: email,
        notes: notes,
      );
      try {
        await _repo.syncPendingQueue();
      } catch (_) {
        // offline — record stays pending, will sync later
      }
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.data(await _readSnapshot());
      return customerId;
    } catch (error, stackTrace) {
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<String> createReceivable({
    required String customerId,
    required String originalAmount,
    String? dueDateIso,
    String? note,
    bool useLoadingState = true,
  }) async {
    if (useLoadingState) state = const AsyncLoading();
    try {
      final receivableId = await _repo.createReceivableLocal(
        customerId: customerId,
        originalAmount: originalAmount,
        dueDateIso: dueDateIso,
        note: note,
      );
      try {
        await _repo.syncPendingQueue();
      } catch (_) {
        // offline — record stays pending
      }
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.data(await _readSnapshot());
      return receivableId;
    } catch (error, stackTrace) {
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Cancels a debt server-side via the receivables API. This is an online
   /// operation — there's no offline queue entry for cancel today; the
   /// caller should handle network errors with a snackbar.
  Future<void> cancelReceivable({required String receivableId}) async {
    state = const AsyncLoading();
    try {
      await ref.read(debtsApiProvider).cancelReceivable(receivableId);
      try {
        await _repo.syncPendingQueue();
      } catch (_) {
        // ignore — server already cancelled; local snapshot will reconcile
      }
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.data(await _readSnapshot());
    } catch (error, stackTrace) {
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<String> recordRepayment({
    required String receivableId,
    required String amount,
    required String paymentMethodLabel,
  }) async {
    state = const AsyncLoading();
    try {
      final paymentId = await _repo.recordRepaymentLocal(
        receivableId: receivableId,
        amount: amount,
        paymentMethodLabel: paymentMethodLabel,
      );
      try {
        await _repo.syncPendingQueue();
      } catch (_) {
        // offline — record stays pending
      }
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.data(await _readSnapshot());
      return paymentId;
    } catch (error, stackTrace) {
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<DebtsViewData> _readSnapshot() async {
    final customers = await _repo.listCustomers();
    final receivables = await _repo.listReceivables();
    return DebtsViewData(customers: customers, receivables: receivables);
  }
}
