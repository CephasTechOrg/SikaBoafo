import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/premium_ui.dart';
import '../../data/debts_repository.dart';
import '../utils/debts_ui_utils.dart';

class DebtPaymentCard extends StatelessWidget {
  const DebtPaymentCard({super.key, required this.payment});

  final LocalReceivablePaymentRecord payment;

  @override
  Widget build(BuildContext context) {
    final syncColor = DebtsUiUtils.syncColor(payment.syncStatus);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₵${payment.amount}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  DebtsUiUtils.paymentMethodLabel(payment.paymentMethodLabel),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  DebtsUiUtils.fmtDateTime(
                    DateTime.fromMillisecondsSinceEpoch(
                      payment.createdAtMillis,
                    ),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          PremiumStatusPill(
            label: DebtsUiUtils.syncLabel(payment.syncStatus),
            foreground: syncColor,
            background: syncColor.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }
}
