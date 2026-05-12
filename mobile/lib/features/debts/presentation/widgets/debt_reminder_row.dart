import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../data/debt_reminders_repository.dart';
import '../../data/models/local_debt_reminder.dart';

/// Single reminder tile inside the debt detail screen. Active reminders get
/// a forest-tinted leading + Cancel button; fired/cancelled ones are muted.
class DebtReminderRow extends StatelessWidget {
  const DebtReminderRow({
    super.key,
    required this.reminder,
    required this.onCancel,
  });

  final LocalDebtReminder reminder;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    final isCancelled = reminder.status == 'cancelled';
    final isFired = reminder.status == 'fired' || reminder.isPast;
    final isActive = reminder.isActive;

    final (foreground, background, label, icon) = _statusVisuals(
      isActive: isActive,
      isFired: isFired,
      isCancelled: isCancelled,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: foreground),
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
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
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
                        color: background,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: foreground,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reminder.message ?? 'Default reminder message',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? AppColors.inkSoft : AppColors.muted,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    fontStyle: reminder.message == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Cancel reminder',
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.muted,
              ),
              onPressed: () => onCancel(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ],
      ),
    );
  }

  (Color foreground, Color background, String label, IconData icon)
      _statusVisuals({
    required bool isActive,
    required bool isFired,
    required bool isCancelled,
  }) {
    if (isCancelled) {
      return (
        AppColors.muted,
        AppColors.surfaceAlt,
        'Cancelled',
        Icons.notifications_off_outlined,
      );
    }
    if (isFired) {
      return (
        AppColors.inkSoft,
        AppColors.surfaceAlt,
        'Sent',
        Icons.notifications_active_outlined,
      );
    }
    if (isActive) {
      return (
        AppColors.forestDark,
        AppColors.successSoft,
        'Scheduled',
        Icons.notifications_active_rounded,
      );
    }
    return (
      AppColors.muted,
      AppColors.surfaceAlt,
      'Inactive',
      Icons.notifications_outlined,
    );
  }
}
