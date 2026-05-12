import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../data/models/local_receivable_payment_record.dart';
import '../utils/debts_ui_utils.dart';

/// Single repayment tile in the payment history list.
class DebtPaymentCard extends StatelessWidget {
  const DebtPaymentCard({super.key, required this.payment});

  final LocalReceivablePaymentRecord payment;

  @override
  Widget build(BuildContext context) {
    final unsynced =
        payment.syncStatus == 'pending' || payment.syncStatus == 'sending';
    final created = payment.createdAtMillis == 0
        ? '—'
        : _formatTime(
            DateTime.fromMillisecondsSinceEpoch(payment.createdAtMillis)
                .toLocal(),
          );

    final iconData = _iconForMethod(payment.paymentMethodLabel);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.successSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, size: 18, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DebtsUiUtils.paymentMethodLabel(
                        payment.paymentMethodLabel,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.ink,
                      ),
                    ),
                    if (unsynced) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warningSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Unsynced',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  created,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+ ${DebtsUiUtils.formatAmount(payment.amount)}',
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.success,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForMethod(String method) {
    switch (method) {
      case 'cash':
        return Icons.payments_rounded;
      case 'mobile_money':
        return Icons.smartphone_rounded;
      case 'bank_transfer':
        return Icons.account_balance_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final dateLabel = DebtsUiUtils.formatDueLabel(
      dt.toIso8601String().substring(0, 10),
    );
    return '$dateLabel · $h:$m';
  }
}
