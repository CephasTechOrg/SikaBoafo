import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/sync_providers.dart';
import '../data/expenses_repository.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository(
    appDb: ref.watch(appDatabaseProvider),
    syncQueueRunner: ref.watch(syncQueueRunnerProvider),
  );
});

final expensesControllerProvider =
    AsyncNotifierProvider<ExpensesController, List<LocalExpenseRecord>>(
  ExpensesController.new,
);

class ExpensesController extends AsyncNotifier<List<LocalExpenseRecord>> {
  ExpensesRepository get _repo => ref.read(expensesRepositoryProvider);

  @override
  Future<List<LocalExpenseRecord>> build() async {
    try {
      await _repo.syncPendingQueue();
    } catch (_) {
      // Keep local mode available while queue rows stay for retry.
    }
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    return _repo.listRecentExpenses();
  }

  Future<void> refresh() async {
    await _repo.syncPendingQueue();
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    state = AsyncValue.data(await _repo.listRecentExpenses());
  }

  Future<void> createExpense({
    required String category,
    required String amount,
    String? note,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.createExpenseLocal(
        category: category,
        amount: amount,
        note: note,
      );
      await _repo.syncPendingQueue();
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.data(await _repo.listRecentExpenses());
    } catch (error, stackTrace) {
      await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}
