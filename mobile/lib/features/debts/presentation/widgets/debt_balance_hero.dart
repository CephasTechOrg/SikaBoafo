import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../data/models/local_receivable_record.dart';
import '../utils/debts_ui_utils.dart';

/// Big "balance" card at the top of the debt detail screen. Surfaces
/// outstanding amount, original amount, and the current status pill.
class DebtBalanceHero extends StatelessWidget {
  const DebtBalanceHero({super.key, required this.record});

  final LocalReceivableRecord record;

  @override
  Widget build(BuildContext context) {
    final outstandingMinor =
        DebtsUiUtils.amountToMinor(record.outstandingAmount);
    final originalMinor = DebtsUiUtils.amountToMinor(record.originalAmount);
    final paidMinor = (originalMinor - outstandingMinor).clamp(0, originalMinor);
    final progress =
        originalMinor == 0 ? 0.0 : paidMinor / originalMinor;
    final status = DebtsUiUtils.statusVisualFor(
      status: record.status,
      dueDateIso: record.dueDateIso,
    );
    final isSettled = record.status == 'settled';
    final isCancelled = record.status == 'cancelled';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'OUTSTANDING',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: status.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    color: status.foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isSettled
                ? 'Cleared'
                : DebtsUiUtils.formatMinor(outstandingMinor),
            style: TextStyle(
              color: isSettled ? AppColors.success : AppColors.ink,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              fontFamily: isSettled ? null : 'Constantia',
              letterSpacing: -0.8,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          if (!isCancelled) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: isSettled ? 1.0 : progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isSettled ? AppColors.success : AppColors.forest,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _MiniMetric(
                  label: 'Original',
                  value: DebtsUiUtils.formatMinor(originalMinor),
                  icon: Icons.receipt_long_rounded,
                ),
                const SizedBox(width: 12),
                _MiniMetric(
                  label: 'Paid',
                  value: DebtsUiUtils.formatMinor(paidMinor),
                  icon: Icons.check_circle_outline_rounded,
                  tone: paidMinor > 0
                      ? AppColors.success
                      : AppColors.inkSoft,
                ),
              ],
            ),
          ] else
            const Text(
              'This debt was cancelled and will not be collected.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: tone ?? AppColors.inkSoft),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: tone ?? AppColors.ink,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
