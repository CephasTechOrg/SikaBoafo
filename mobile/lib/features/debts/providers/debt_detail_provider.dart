import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/local_receivable_detail.dart';
import 'debts_providers.dart';

/// Reads the full detail (customer + receivable + repayments) for a single
/// debt. Watches the debts controller so the detail invalidates whenever the
/// list refreshes (e.g. after a repayment is recorded).
final receivableDetailProvider = FutureProvider.autoDispose
    .family<LocalReceivableDetail?, String>((ref, receivableId) async {
  ref.watch(debtsControllerProvider);
  final repo = ref.read(debtsRepositoryProvider);
  return repo.getReceivableDetail(receivableId);
});
