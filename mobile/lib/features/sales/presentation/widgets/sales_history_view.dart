import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/premium_ui.dart';
import '../../data/sales_repository.dart';
import '../../providers/sales_providers.dart';
import 'empty_card.dart';

class SalesHistoryView extends ConsumerWidget {
  const SalesHistoryView({
    super.key,
    required this.showVoided,
    required this.onShowVoidedChanged,
    required this.historySales,
    required this.buildSaleTile,
    required this.isBusy,
  });

  final bool showVoided;
  final ValueChanged<bool> onShowVoidedChanged;
  final List<LocalSaleRecord> historySales;
  final Widget Function(LocalSaleRecord) buildSaleTile;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesControllerProvider);

    return PremiumReveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              FilterChip(
                label: const Text('Show voided'),
                selected: showVoided,
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: showVoided ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
                selectedColor: AppColors.ink,
                checkmarkColor: Colors.white,
                onSelected: isBusy ? null : onShowVoidedChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (salesAsync.isLoading && historySales.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (historySales.isEmpty)
            EmptyCard(
              icon: Icons.receipt_long_outlined,
              message: showVoided
                  ? 'No transactions found.'
                  : 'No active transactions. Switch to "New Sale" to start selling.',
            )
          else
            ...historySales.take(15).map(buildSaleTile),
        ],
      ),
    );
  }
}
