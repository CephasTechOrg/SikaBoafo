import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../shared/utils/user_friendly_error.dart';
import '../../data/models/local_debt_reminder.dart';
import '../../data/models/local_receivable_record.dart';
import '../../providers/debt_reminders_provider.dart';
import '../utils/debts_ui_tokens.dart';
import '../utils/debts_ui_utils.dart';
import 'debt_reminder_row.dart';
import 'debt_section_card.dart';
import 'schedule_reminder_sheet.dart';

/// Reminders block on the debt detail screen, wrapped in a [DebtSectionCard]
/// so it matches the mockup's `.section-card` chrome (header + divider +
/// padded body + count badge / inline action).
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

    return DebtSectionCard(
      title: 'Reminders',
      icon: LucideIcons.bell,
      countBadge: activeCount > 0 ? activeCount : null,
      trailing: (activeCount == 0 && canSchedule && !isEmpty)
          ? _SetReminderButton(onTap: () => _openSheet(context, ref))
          : null,
      child: _buildBody(
        context: context,
        ref: ref,
        remindersAsync: remindersAsync,
        reminders: reminders,
        canSchedule: canSchedule,
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required WidgetRef ref,
    required AsyncValue<List<LocalDebtReminder>> remindersAsync,
    required List<LocalDebtReminder> reminders,
    required bool canSchedule,
  }) {
    if (remindersAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: DebtsUi.greenMid,
            ),
          ),
        ),
      );
    }
    if (remindersAsync.hasError) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DebtsUi.dangerSoft,
          borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
          border: Border.all(color: DebtsUi.dangerBorder),
        ),
        child: Text(
          userFriendlyError(remindersAsync.error!),
          style: const TextStyle(fontSize: 13, color: DebtsUi.danger),
        ),
      );
    }
    if (reminders.isEmpty) {
      return DebtSectionEmptyState(
        icon: LucideIcons.bell,
        title: canSchedule ? 'No reminders set' : 'Reminders unavailable',
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < reminders.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          DebtReminderRow(
            reminder: reminders[i],
            onCancel: () => _handleCancel(context, ref, reminders[i]),
          ),
        ],
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

class _SetReminderButton extends StatelessWidget {
  const _SetReminderButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(LucideIcons.bell, size: 16),
      label: const Text('Set reminder'),
      style: TextButton.styleFrom(
        foregroundColor: DebtsUi.greenMid,
        textStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
