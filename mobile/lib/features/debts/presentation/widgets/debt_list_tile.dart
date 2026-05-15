import 'package:flutter/material.dart';

import '../../data/models/local_receivable_record.dart';
import '../utils/debts_ui_tokens.dart';
import '../utils/debts_ui_utils.dart';

/// Single row in the debts list, modelled after `index (2).html` `.debt-card`:
/// rounded-square avatar (green for settled, gold for open/overdue) → name +
/// `INV · date` meta → amount with status pill stacked beneath → chevron.
class DebtListTile extends StatelessWidget {
  const DebtListTile({
    super.key,
    required this.record,
    required this.onTap,
  });

  final LocalReceivableRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outstanding = DebtsUiUtils.formatAmount(record.outstandingAmount);
    final isSettled = record.status == 'settled';
    final isCancelled = record.status == 'cancelled';
    final isOverdue = !isSettled &&
        !isCancelled &&
        DebtsUiUtils.isOverdue(record.dueDateIso);
    final unsynced =
        record.syncStatus == 'pending' || record.syncStatus == 'sending';

    final customerInitial = (record.customerName ?? '?').isNotEmpty
        ? record.customerName![0].toUpperCase()
        : '?';

    final badge = _resolveBadge(
      isSettled: isSettled,
      isCancelled: isCancelled,
      isOverdue: isOverdue,
      isPartial: record.status == 'partially_paid',
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DebtsUi.surface,
            borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
            border: Border.all(color: DebtsUi.border, width: 1.5),
            boxShadow: DebtsUi.shadowSm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(initial: customerInitial, settled: isSettled),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      record.customerName ?? 'Unknown customer',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: DebtsUi.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _MetaLine(record: record, unsynced: unsynced),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    outstanding,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSettled
                          ? DebtsUi.textMuted
                          : DebtsUi.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 6),
                  _StatusBadge(badge: badge),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: DebtsUi.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  _BadgeStyle _resolveBadge({
    required bool isSettled,
    required bool isCancelled,
    required bool isOverdue,
    required bool isPartial,
  }) {
    if (isCancelled) {
      return const _BadgeStyle(
        label: 'Cancelled',
        bg: DebtsUi.surface2,
        fg: DebtsUi.textMuted,
        border: DebtsUi.border,
      );
    }
    if (isSettled) {
      return const _BadgeStyle(
        label: 'Settled',
        bg: DebtsUi.settledBg,
        fg: DebtsUi.settledFg,
        border: DebtsUi.settledBorder,
      );
    }
    if (isOverdue) {
      return const _BadgeStyle(
        label: 'Overdue',
        bg: DebtsUi.overdueBg,
        fg: DebtsUi.overdueFg,
        border: DebtsUi.overdueBorder,
      );
    }
    return _BadgeStyle(
      label: isPartial ? 'Partial' : 'Open',
      bg: DebtsUi.openBg,
      fg: DebtsUi.openFg,
      border: DebtsUi.openBorder,
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.record, required this.unsynced});

  final LocalReceivableRecord record;
  final bool unsynced;

  @override
  Widget build(BuildContext context) {
    final invoice = record.invoiceNumber;
    final dueIso = record.dueDateIso;
    final pieces = <String>[
      if (invoice != null && invoice.isNotEmpty) invoice,
      if (dueIso != null && dueIso.isNotEmpty)
        DebtsUiUtils.formatDueLabel(dueIso),
    ];
    return Row(
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              for (var i = 0; i < pieces.length; i++) ...[
                if (i > 0)
                  const SizedBox(
                    width: 3,
                    height: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: DebtsUi.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Text(
                  pieces[i],
                  style: const TextStyle(
                    fontSize: 12,
                    color: DebtsUi.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (unsynced)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: DebtsUi.accentGoldSoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: DebtsUi.accentGoldBorder),
                  ),
                  child: const Text(
                    'Unsynced',
                    style: TextStyle(
                      fontSize: 10,
                      color: DebtsUi.accentGoldInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.settled});

  final String initial;
  final bool settled;

  @override
  Widget build(BuildContext context) {
    final bg = settled ? DebtsUi.avatarGreenBg : DebtsUi.avatarGoldBg;
    final fg = settled ? DebtsUi.avatarGreenFg : DebtsUi.avatarGoldFg;
    final border = settled ? DebtsUi.avatarGreenBorder : DebtsUi.avatarGoldBorder;
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: 'Constantia',
          fontSize: 20,
          fontWeight: FontWeight.w400,
          color: fg,
        ),
      ),
    );
  }
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
  });

  final String label;
  final Color bg;
  final Color fg;
  final Color border;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.badge});

  final _BadgeStyle badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: badge.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badge.border),
      ),
      child: Text(
        badge.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: badge.fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
