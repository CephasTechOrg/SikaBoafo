import 'package:flutter/material.dart';

import '../../data/models/local_receivable_record.dart';
import '../utils/debts_ui_tokens.dart';
import '../utils/debts_ui_utils.dart';

/// Floating "status card" for the debt detail screen.
///
/// Visual reference: `index (2).html` `.status-card`. Shows the outstanding
/// label + amount (or "Cleared"), status badge, progress bar, and a two-cell
/// row of Original / Paid amount boxes. Designed to overlap the green hero
/// from above; the parent screen handles the negative-margin layout.
class DebtBalanceHero extends StatelessWidget {
  const DebtBalanceHero({
    super.key,
    required this.record,
    this.bridgesIntoHeader = false,
  });

  final LocalReceivableRecord record;

  /// When true, the card sits over the green hero; use a slightly deeper
  /// shadow so it reads as one continuous surface with the header.
  final bool bridgesIntoHeader;

  @override
  Widget build(BuildContext context) {
    final outstandingMinor =
        DebtsUiUtils.amountToMinor(record.outstandingAmount);
    final originalMinor = DebtsUiUtils.amountToMinor(record.originalAmount);
    final paidMinor =
        (originalMinor - outstandingMinor).clamp(0, originalMinor);
    final progress = originalMinor == 0 ? 0.0 : paidMinor / originalMinor;
    final isSettled = record.status == 'settled';
    final isCancelled = record.status == 'cancelled';
    final isOverdue =
        !isSettled && !isCancelled && DebtsUiUtils.isOverdue(record.dueDateIso);

    final badge = _resolveBadge(
      isSettled: isSettled,
      isCancelled: isCancelled,
      isOverdue: isOverdue,
      isPartial: record.status == 'partially_paid',
    );

    final overlapShadow = <BoxShadow>[
      const BoxShadow(
        color: Color(0x180D3D2B),
        blurRadius: 28,
        offset: Offset(0, 10),
        spreadRadius: -2,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DebtsUi.surface,
        borderRadius: BorderRadius.circular(DebtsUi.radiusLg),
        border: Border.all(color: DebtsUi.border, width: 1.5),
        boxShadow: bridgesIntoHeader
            ? <BoxShadow>[...DebtsUi.shadowMd, ...overlapShadow]
            : DebtsUi.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'OUTSTANDING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: DebtsUi.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSettled
                          ? 'Cleared'
                          : DebtsUiUtils.formatMinor(outstandingMinor),
                      style: TextStyle(
                        fontFamily: 'Constantia',
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color:
                            isSettled ? DebtsUi.greenMid : DebtsUi.textPrimary,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusBadge(badge: badge),
            ],
          ),
          const SizedBox(height: 14),
          if (!isCancelled) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 5,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: DebtsUi.greenLight),
                    ),
                    FractionallySizedBox(
                      widthFactor:
                          isSettled ? 1.0 : progress.clamp(0.0, 1.0).toDouble(),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: DebtsUi.progressGradient,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _AmountBox(
                  icon: Icons.receipt_long_outlined,
                  label: 'ORIGINAL',
                  value: DebtsUiUtils.formatMinor(originalMinor),
                ),
                const SizedBox(width: 10),
                _AmountBox(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: DebtsUi.greenBright,
                  label: 'PAID',
                  value: DebtsUiUtils.formatMinor(paidMinor),
                  valueColor:
                      paidMinor > 0 ? DebtsUi.greenMid : DebtsUi.textPrimary,
                ),
              ],
            ),
          ] else
            const Text(
              'This debt was cancelled and will not be collected.',
              style: TextStyle(
                fontSize: 13,
                color: DebtsUi.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
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
        bg: DebtsUi.surface,
        fg: DebtsUi.textMuted,
        border: DebtsUi.borderNeutral,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: badge.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badge.border),
      ),
      child: Text(
        badge.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: badge.fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _AmountBox extends StatelessWidget {
  const _AmountBox({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: DebtsUi.surface,
          borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
          border: Border.all(color: DebtsUi.borderNeutral, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: iconColor ?? DebtsUi.textMuted),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: DebtsUi.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: valueColor ?? DebtsUi.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
