import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/core_providers.dart';
import '../data/debt_reminders_repository.dart';
import '../data/models/local_debt_reminder.dart';

final debtRemindersRepositoryProvider =
    Provider<DebtRemindersRepository>((ref) {
  return DebtRemindersRepository(
    appDb: ref.watch(appDatabaseProvider),
    notifications: ref.watch(notificationsServiceProvider),
  );
});

/// Per-receivable reminders list. Auto-disposed so it reflows whenever the
/// debt detail screen is rebuilt (and naturally re-reads after [schedule] /
/// [cancel] invalidations).
final debtRemindersForReceivableProvider = FutureProvider.autoDispose
    .family<List<LocalDebtReminder>, String>((ref, receivableId) async {
  final repo = ref.watch(debtRemindersRepositoryProvider);
  await repo.markPastFired();
  return repo.listForReceivable(receivableId);
});

/// Action surface for the schedule / cancel buttons. Keeps the widget tree
/// from holding direct references to the repository.
class DebtRemindersController {
  DebtRemindersController(this._ref);

  final Ref _ref;

  Future<LocalDebtReminder> schedule({
    required String receivableId,
    required String customerName,
    required String amountDisplay,
    required DateTime fireAt,
    String? message,
  }) async {
    final repo = _ref.read(debtRemindersRepositoryProvider);
    final reminder = await repo.create(
      receivableId: receivableId,
      customerName: customerName,
      amountDisplay: amountDisplay,
      fireAt: fireAt,
      message: message,
    );
    _ref.invalidate(debtRemindersForReceivableProvider(receivableId));
    return reminder;
  }

  Future<void> cancel({
    required String reminderId,
    required String receivableId,
  }) async {
    final repo = _ref.read(debtRemindersRepositoryProvider);
    await repo.cancel(reminderId: reminderId);
    _ref.invalidate(debtRemindersForReceivableProvider(receivableId));
  }
}

final debtRemindersControllerProvider =
    Provider<DebtRemindersController>((ref) {
  return DebtRemindersController(ref);
});
