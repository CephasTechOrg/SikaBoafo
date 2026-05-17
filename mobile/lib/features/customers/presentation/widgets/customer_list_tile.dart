import 'package:flutter/material.dart';

import '../../../debts/data/models/local_debt_customer.dart';
import '../../../debts/presentation/utils/debts_ui_tokens.dart';
import '../../../debts/presentation/utils/debts_ui_utils.dart';

class CustomerListTile extends StatelessWidget {
  const CustomerListTile({
    super.key,
    required this.customer,
    required this.onTap,
  });

  final LocalDebtCustomer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outstanding = DebtsUiUtils.amountToMinor(customer.totalOutstanding);
    final hasBalance = outstanding > 0;
    final initial = customer.name.isNotEmpty
        ? customer.name[0].toUpperCase()
        : '?';

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
            border: Border.all(color: DebtsUi.borderNeutral, width: 1.5),
            boxShadow: DebtsUi.shadowNeutralSm,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hasBalance
                      ? DebtsUi.avatarGoldBg
                      : DebtsUi.avatarNeutralBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasBalance
                        ? DebtsUi.avatarGoldBorder
                        : DebtsUi.avatarNeutralBorder,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontFamily: 'Constantia',
                    fontSize: 20,
                    color: hasBalance
                        ? DebtsUi.avatarGoldFg
                        : DebtsUi.avatarNeutralFg,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
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
                    Text(
                      customer.phoneNumber ?? 'No phone on file',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: DebtsUi.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    hasBalance
                        ? DebtsUiUtils.formatMinor(outstanding)
                        : 'Cleared',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: hasBalance
                          ? DebtsUi.textPrimary
                          : DebtsUi.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: hasBalance ? DebtsUi.openBg : DebtsUi.settledBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            hasBalance ? DebtsUi.openBorder : DebtsUi.settledBorder,
                      ),
                    ),
                    child: Text(
                      hasBalance ? 'Owes you' : 'Settled',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: hasBalance ? DebtsUi.openFg : DebtsUi.settledFg,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
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
}
