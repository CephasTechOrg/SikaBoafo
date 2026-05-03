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
    final visibleCount = historySales.length > 15 ? 15 : historySales.length;

    return PremiumReveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent transactions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Edit or void recorded sales from the latest activity list.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
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
              title: 'No sales recorded yet',
              message: showVoided
                  ? 'No matching sales were found in history yet.'
                  : 'Your recent sales will appear here after you complete your first transaction.',
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                historySales.length > 15
                    ? 'Showing the latest $visibleCount of ${historySales.length} sales'
                    : '$visibleCount sale${visibleCount == 1 ? '' : 's'} available',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            ),
            ...historySales.take(15).map(buildSaleTile),
          ],
        ],
      ),
    );
  }
}
