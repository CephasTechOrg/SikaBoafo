import 'package:flutter/material.dart';

import '../../data/debt_reminders_repository.dart';
import '../../data/models/local_debt_reminder.dart';
import '../utils/debts_ui_tokens.dart';

/// Single reminder tile inside the debt detail screen. Active reminders get
/// a green-tinted leading + Cancel button; fired/cancelled ones are muted.
/// Styled with the shared debts mockup design language.
class DebtReminderRow extends StatelessWidget {
  const DebtReminderRow({
    super.key,
    required this.reminder,
    required this.onRemove,
  });

  final LocalDebtReminder reminder;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final isCancelled = reminder.status == 'cancelled';
    final isFired = reminder.status == 'fired' || reminder.isPast;
    final isActive = reminder.isActive;

    final visuals = _statusVisuals(
      isActive: isActive,
      isFired: isFired,
      isCancelled: isCancelled,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DebtsUi.surface,
        borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
        border: Border.all(color: DebtsUi.border, width: 1.5),
        boxShadow: DebtsUi.shadowSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: visuals.background,
              borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
              border: Border.all(color: visuals.border, width: 1.5),
            ),
            child: Icon(visuals.icon, size: 18, color: visuals.foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reminderFireLabel(reminder.fireAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: DebtsUi.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: visuals.background,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: visuals.border, width: 1),
                      ),
                      child: Text(
                        visuals.label,
                        style: TextStyle(
                          fontSize: 10,
                          color: visuals.foreground,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reminder.message ?? 'Default reminder message',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isActive
                        ? DebtsUi.textSecondary
                        : DebtsUi.textMuted,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    fontStyle: reminder.message == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: isActive ? 'Cancel & remove reminder' : 'Remove reminder',
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: DebtsUi.textMuted,
            ),
            onPressed: () => onRemove(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  _ReminderVisuals _statusVisuals({
    required bool isActive,
    required bool isFired,
    required bool isCancelled,
  }) {
    if (isCancelled) {
      return const _ReminderVisuals(
        foreground: DebtsUi.textMuted,
        background: DebtsUi.surface2,
        border: DebtsUi.border,
        label: 'Cancelled',
        icon: Icons.notifications_off_outlined,
      );
    }
    if (isFired) {
      return const _ReminderVisuals(
        foreground: DebtsUi.textSecondary,
        background: DebtsUi.surface2,
        border: DebtsUi.border,
        label: 'Sent',
        icon: Icons.notifications_active_outlined,
      );
    }
    if (isActive) {
      return const _ReminderVisuals(
        foreground: DebtsUi.greenMid,
        background: DebtsUi.greenPale,
        border: DebtsUi.greenLight,
        label: 'Scheduled',
        icon: Icons.notifications_active_rounded,
      );
    }
    return const _ReminderVisuals(
      foreground: DebtsUi.textMuted,
      background: DebtsUi.surface2,
      border: DebtsUi.border,
      label: 'Inactive',
      icon: Icons.notifications_outlined,
    );
  }
}

class _ReminderVisuals {
  const _ReminderVisuals({
    required this.foreground,
    required this.background,
    required this.border,
    required this.label,
    required this.icon,
  });

  final Color foreground;
  final Color background;
  final Color border;
  final String label;
  final IconData icon;
}
