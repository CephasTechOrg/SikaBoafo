import 'package:flutter/material.dart';

import '../../../debts/presentation/utils/debts_ui_tokens.dart';
import '../../../debts/presentation/utils/debts_ui_utils.dart';

/// Floating summary card on the customer detail screen (parity with debt
/// detail `DebtBalanceHero`).
class CustomerBalanceHero extends StatelessWidget {
  const CustomerBalanceHero({
    super.key,
    required this.outstandingMinor,
    required this.openDebtCount,
    required this.totalDebtCount,
    this.bridgesIntoHeader = false,
  });

  final int outstandingMinor;
  final int openDebtCount;
  final int totalDebtCount;
  final bool bridgesIntoHeader;

  bool get _cleared => outstandingMinor == 0;

  @override
  Widget build(BuildContext context) {
    final overlapShadow = <BoxShadow>[
      const BoxShadow(
        color: Color(0x180D3D2B),
        blurRadius: 28,
        offset: Offset(0, 10),
        spreadRadius: -2,
      ),
    ];

    final badge = _cleared
        ? const _BadgeStyle(
            label: 'All cleared',
            bg: DebtsUi.settledBg,
            fg: DebtsUi.settledFg,
            border: DebtsUi.settledBorder,
          )
        : const _BadgeStyle(
            label: 'Active balance',
            bg: DebtsUi.openBg,
            fg: DebtsUi.openFg,
            border: DebtsUi.openBorder,
          );

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
                  children: [
                    const Text(
                      'TOTAL OUTSTANDING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: DebtsUi.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _cleared
                          ? 'Cleared'
                          : DebtsUiUtils.formatMinor(outstandingMinor),
                      style: TextStyle(
                        fontFamily: 'Constantia',
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: _cleared
                            ? DebtsUi.textSecondary
                            : DebtsUi.textPrimary,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(badge: badge),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatBox(
                icon: Icons.receipt_long_outlined,
                label: 'OPEN DEBTS',
                value: '$openDebtCount',
              ),
              const SizedBox(width: 10),
              _StatBox(
                icon: Icons.history_rounded,
                label: 'ALL TIME',
                value: '$totalDebtCount',
              ),
            ],
          ),
        ],
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
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: DebtsUi.surface,
          borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
          border: Border.all(color: DebtsUi.border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: DebtsUi.textMuted),
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: DebtsUi.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
