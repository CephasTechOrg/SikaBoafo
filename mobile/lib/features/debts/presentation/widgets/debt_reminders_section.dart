import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/utils/user_friendly_error.dart';
import '../../data/models/local_debt_reminder.dart';
import '../../data/models/local_receivable_record.dart';
import '../../providers/debt_reminders_provider.dart';
import '../utils/debts_ui_utils.dart';
import 'debt_reminder_row.dart';
import 'schedule_reminder_sheet.dart';

/// Reminders section under a debt detail screen. Lists scheduled / sent /
/// cancelled reminders and hosts the "Set reminder" CTA.
class DebtRemindersSection extends ConsumerWidget {
  const DebtRemindersSection({
    super.key,
    required this.record,
    required this.customerName,
  });

  final LocalReceivableRecord record;
  final String customerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync =
        ref.watch(debtRemindersForReceivableProvider(record.receivableId));
    final reminders = remindersAsync.valueOrNull ?? const <LocalDebtReminder>[];
    final canSchedule = !record.isTerminal;
    final activeCount = reminders.where((r) => r.isActive).length;
    final isEmpty = !remindersAsync.isLoading &&
        !remindersAsync.hasError &&
        reminders.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Reminders',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: 8),
            if (activeCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$activeCount active',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forestDark,
                  ),
                ),
              ),
            const Spacer(),
            if (canSchedule && !isEmpty)
              TextButton.icon(
                onPressed: () => _openSheet(context, ref),
                icon: const Icon(Icons.add_alarm_rounded, size: 16),
                label: const Text('Set reminder'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.forestDark,
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (remindersAsync.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 1.8),
              ),
            ),
          )
        else if (remindersAsync.hasError)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              userFriendlyError(remindersAsync.error!),
              style: const TextStyle(fontSize: 12.5, color: AppColors.danger),
            ),
          )
        else if (reminders.isEmpty)
          _EmptyReminders(canSchedule: canSchedule)
        else
          ...reminders.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DebtReminderRow(
                reminder: r,
                onCancel: () => _handleCancel(context, ref, r),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    await showScheduleReminderSheet(
      context,
      receivableId: record.receivableId,
      customerName: customerName,
      amountDisplay: DebtsUiUtils.formatAmount(record.outstandingAmount),
    );
  }

  Future<void> _handleCancel(
    BuildContext context,
    WidgetRef ref,
    LocalDebtReminder reminder,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(debtRemindersControllerProvider).cancel(
            reminderId: reminder.id,
            receivableId: reminder.receivableId,
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Reminder cancelled.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(userFriendlyError(error))),
      );
    }
  }
}

class _EmptyReminders extends StatelessWidget {
  const _EmptyReminders({required this.canSchedule});

  final bool canSchedule;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            size: 20,
            color: AppColors.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              canSchedule
                  ? 'No reminders yet. Set one so you don\'t forget to follow up.'
                  : 'Reminders aren\'t available for settled or cancelled debts.',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
