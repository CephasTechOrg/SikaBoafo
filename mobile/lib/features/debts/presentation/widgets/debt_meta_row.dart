import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../data/models/local_receivable_record.dart';
import '../utils/debts_ui_utils.dart';

/// Compact horizontally-scrollable meta strip under the balance hero:
/// invoice number, created date, due date, days overdue.
class DebtMetaRow extends StatelessWidget {
  const DebtMetaRow({super.key, required this.record});

  final LocalReceivableRecord record;

  @override
  Widget build(BuildContext context) {
    final daysUntilDue = DebtsUiUtils.daysUntilDue(record.dueDateIso);
    final createdLabel = _formatDateMillis(record.createdAtMillis);
    final isOverdue = DebtsUiUtils.isOverdue(record.dueDateIso) &&
        record.status != 'settled' &&
        record.status != 'cancelled';
    final chips = <Widget>[];

    if (record.invoiceNumber != null && record.invoiceNumber!.isNotEmpty) {
      chips.add(_Chip(
        icon: Icons.receipt_long_rounded,
        label: 'Invoice',
        value: record.invoiceNumber!,
      ));
    }
    chips.add(_Chip(
      icon: Icons.event_available_rounded,
      label: 'Created',
      value: createdLabel,
    ));
    if (record.dueDateIso != null && record.dueDateIso!.isNotEmpty) {
      chips.add(_Chip(
        icon: Icons.calendar_today_rounded,
        label: 'Due',
        value: DebtsUiUtils.formatDueLabel(record.dueDateIso!),
        tone: isOverdue ? AppColors.danger : null,
      ));
    }
    if (isOverdue && daysUntilDue != null) {
      chips.add(_Chip(
        icon: Icons.warning_amber_rounded,
        label: 'Overdue',
        value: '${-daysUntilDue} day${(-daysUntilDue) == 1 ? '' : 's'}',
        tone: AppColors.danger,
      ));
    }
    if (record.note != null && record.note!.trim().isNotEmpty) {
      chips.add(_Chip(
        icon: Icons.sticky_note_2_outlined,
        label: 'Note',
        value: record.note!.trim(),
        wide: true,
      ));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            chips[i],
          ],
        ],
      ),
    );
  }

  String _formatDateMillis(int millis) {
    if (millis == 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    return DebtsUiUtils.formatDueLabel(
      dt.toIso8601String().substring(0, 10),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.value,
    this.tone,
    this.wide = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? tone;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final accent = tone ?? AppColors.inkSoft;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: wide ? 260 : 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 1),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
