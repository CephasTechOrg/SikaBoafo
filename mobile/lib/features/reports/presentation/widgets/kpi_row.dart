import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/app_components.dart';

class KpiRow extends StatelessWidget {
  const KpiRow({super.key, 
    required this.sales,
    required this.expenses,
    required this.profit,
    this.grossProfit = '0.00',
  });
  final String sales, expenses, profit, grossProfit;
  static final NumberFormat _compactMoneyFormatter =
      NumberFormat.compactCurrency(
    symbol: '\u20B5',
    decimalDigits: 1,
  );

  bool get _hasGrossProfit {
    final v = double.tryParse(grossProfit) ?? 0.0;
    return v > 0;
  }

  String _compactMoney(String raw) {
    final value = double.tryParse(raw);
    if (value == null) return '\u20B5$raw';
    return _compactMoneyFormatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final compactSales = _compactMoney(sales);
    final compactExpenses = _compactMoney(expenses);
    final compactProfit = _compactMoney(profit);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppStatCard(
                label: 'Sales',
                value: compactSales,
                icon: Icons.trending_up_rounded,
                accent: AppColors.forest,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppStatCard(
                label: 'Expenses',
                value: compactExpenses,
                icon: Icons.receipt_long_outlined,
                accent: AppColors.danger,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppStatCard(
                label: 'Est. Profit',
                value: compactProfit,
                icon: Icons.attach_money_rounded,
                accent: AppColors.warning,
              ),
            ),
          ],
        ),
        if (_hasGrossProfit) ...[
          const SizedBox(height: 10),
          AppStatCard(
            label: 'Gross Profit',
            value: '\u20B5$grossProfit',
            caption: 'Revenue minus cost of goods sold',
            icon: Icons.insights_rounded,
            accent: AppColors.info,
          ),
        ],
      ],
    );
  }
}
