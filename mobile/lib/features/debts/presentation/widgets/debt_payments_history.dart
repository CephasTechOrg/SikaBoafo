import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../data/models/local_receivable_payment_record.dart';
import 'debt_payment_card.dart';

/// Payment history section for a debt detail screen. Renders a small
/// section heading + count badge, then each [DebtPaymentCard].
class DebtPaymentsHistory extends StatelessWidget {
  const DebtPaymentsHistory({super.key, required this.payments});

  final List<LocalReceivablePaymentRecord> payments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Repayments',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${payments.length}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkSoft,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (payments.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 18,
                  color: AppColors.muted,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No repayments yet. Use "Receive payment" below to '
                    'record cash or mobile money.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...payments.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DebtPaymentCard(payment: p),
            ),
          ),
      ],
    );
  }
}
