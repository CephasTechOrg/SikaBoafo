import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../data/models/local_receivable_record.dart';
import '../utils/debts_ui_tokens.dart';
import '../utils/debts_ui_utils.dart';

/// Single debt row in the [DebtsScreen] list. Tap navigates to detail.
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
    final status = DebtsUiUtils.statusVisualFor(
      status: record.status,
      dueDateIso: record.dueDateIso,
    );
    final outstanding =
        DebtsUiUtils.formatAmount(record.outstandingAmount);
    final original = DebtsUiUtils.formatAmount(record.originalAmount);
    final isPartial = record.status == 'partially_paid';
    final hasDueDate =
        record.dueDateIso != null && record.dueDateIso!.isNotEmpty;
    final unsynced =
        record.syncStatus == 'pending' || record.syncStatus == 'sending';
    final customerInitial = (record.customerName ?? '?').isNotEmpty
        ? record.customerName![0].toUpperCase()
        : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(DebtsUiTokens.tileRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(DebtsUiTokens.tileRadius),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.subtle,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Text(
                  customerInitial,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
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
                            record.customerName ?? 'Unknown customer',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(visual: status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          outstanding,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (isPartial) ...[
                          const SizedBox(width: 6),
                          Text(
                            'of $original',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (record.invoiceNumber != null &&
                            record.invoiceNumber!.isNotEmpty) ...[
                          Icon(Icons.receipt_long_rounded,
                              size: 11.5,
                              color: AppColors.muted.withValues(alpha: 0.7)),
                          const SizedBox(width: 3),
                          Text(
                            record.invoiceNumber!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (hasDueDate) ...[
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 11,
                            color: status.foreground == AppColors.danger
                                ? AppColors.danger
                                : AppColors.muted.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              DebtsUiUtils.formatDueLabel(record.dueDateIso!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: status.foreground == AppColors.danger
                                    ? AppColors.danger
                                    : AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (unsynced) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warningSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Unsynced',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.mutedSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.visual});

  final DebtStatusVisual visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        visual.label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: visual.foreground,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
