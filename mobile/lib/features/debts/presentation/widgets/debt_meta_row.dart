import 'package:flutter/material.dart';

import '../../data/models/local_receivable_record.dart';
import '../utils/debts_ui_tokens.dart';
import '../utils/debts_ui_utils.dart';

/// Three-cell info row beneath the balance hero.
///
/// Visual reference: `index (2).html` `.info-row` (Invoice | Created | Due).
/// Optional Note / Overdue badges are appended below as separate chips so
/// the primary 3-cell grid stays clean.
class DebtMetaRow extends StatelessWidget {
  const DebtMetaRow({super.key, required this.record});

  final LocalReceivableRecord record;

  @override
  Widget build(BuildContext context) {
    final isOverdue = DebtsUiUtils.isOverdue(record.dueDateIso) &&
        record.status != 'settled' &&
        record.status != 'cancelled';
    final daysUntilDue = DebtsUiUtils.daysUntilDue(record.dueDateIso);
    final invoice = (record.invoiceNumber ?? '').isNotEmpty
        ? record.invoiceNumber!
        : '—';
    final created = _formatDateMillis(record.createdAtMillis);
    final due = (record.dueDateIso != null && record.dueDateIso!.isNotEmpty)
        ? DebtsUiUtils.formatDueLabel(record.dueDateIso!)
        : '—';
    final note = record.note?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _InfoBox(
              icon: Icons.receipt_long_outlined,
              label: 'INVOICE',
              value: invoice,
            ),
            const SizedBox(width: 10),
            _InfoBox(
              icon: Icons.calendar_today_outlined,
              label: 'CREATED',
              value: created,
            ),
            const SizedBox(width: 10),
            _InfoBox(
              icon: Icons.event_outlined,
              label: 'DUE',
              value: due,
              tone: isOverdue ? DebtsUi.danger : null,
            ),
          ],
        ),
        if (isOverdue && daysUntilDue != null) ...[
          const SizedBox(height: 10),
          _Chip(
            icon: Icons.warning_amber_rounded,
            label: 'Overdue',
            value: '${-daysUntilDue} day${(-daysUntilDue) == 1 ? '' : 's'}',
            tone: DebtsUi.danger,
          ),
        ],
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Chip(
            icon: Icons.sticky_note_2_outlined,
            label: 'Note',
            value: note,
          ),
        ],
      ],
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

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.label,
    required this.value,
    this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone ?? DebtsUi.textMuted;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DebtsUi.surface,
          borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
          border: Border.all(color: DebtsUi.border, width: 1.5),
          boxShadow: DebtsUi.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 11, color: accent),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: DebtsUi.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: tone ?? DebtsUi.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.value,
    this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone ?? DebtsUi.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DebtsUi.surface,
        borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
        border: Border.all(color: DebtsUi.border, width: 1.5),
        boxShadow: DebtsUi.shadowSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 8),
          Text(
            '$label · ',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: DebtsUi.textMuted,
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
