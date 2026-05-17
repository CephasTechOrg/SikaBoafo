import 'package:flutter/material.dart';

import '../../data/models/local_receivable_payment_record.dart';
import '../utils/debts_ui_tokens.dart';
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
        color: DebtsUi.surface,
        borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
        border: Border.all(color: DebtsUi.border, width: 1.5),
        boxShadow: DebtsUi.shadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: DebtsUi.greenPale,
              borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
              border: Border.all(color: DebtsUi.greenLight, width: 1.5),
            ),
            child: Icon(iconData, size: 18, color: DebtsUi.greenMid),
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
                        color: DebtsUi.textPrimary,
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
                          color: DebtsUi.accentGoldSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Unsynced',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: DebtsUi.accentGoldInk,
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
                    color: DebtsUi.textMuted,
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
              color: DebtsUi.greenMid,
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
