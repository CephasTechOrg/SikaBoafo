import 'package:flutter/material.dart';

import '../../data/models/local_receivable_payment_record.dart';
import 'debt_payment_card.dart';
import 'debt_section_card.dart';

/// Repayments group on the debt detail screen, wrapped in a [DebtSectionCard]
/// to mirror the mockup's `.section-card` chrome with a count badge.
class DebtPaymentsHistory extends StatelessWidget {
  const DebtPaymentsHistory({super.key, required this.payments});

  final List<LocalReceivablePaymentRecord> payments;

  @override
  Widget build(BuildContext context) {
    return DebtSectionCard(
      title: 'Repayments',
      icon: Icons.history_rounded,
      countBadge: payments.length,
      child: payments.isEmpty
          ? const DebtSectionEmptyState(
              icon: Icons.refresh_rounded,
              title: 'No repayments yet',
              message:
                  'Use "Receive payment" below to record cash or mobile money.',
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < payments.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  DebtPaymentCard(payment: payments[i]),
                ],
              ],
            ),
    );
  }
}
