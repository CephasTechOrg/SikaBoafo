import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../sales/presentation/utils/sales_ui_utils.dart';

class ExpensesBottomBar extends StatelessWidget {
  const ExpensesBottomBar({
    super.key,
    required this.amountText,
    required this.categoryLabel,
    required this.canSave,
    required this.isBusy,
    required this.onSave,
  });

  final String amountText;
  final String categoryLabel;
  final bool canSave;
  final bool isBusy;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final minor = SalesUiUtils.moneyToMinorSafe(amountText);
    final hasAmount = minor > 0;

    return Container(
      decoration: BoxDecoration(
        gradient: hasAmount
            ? const LinearGradient(
                colors: [Color(0xFF0A3D1A), Color(0xFF155236)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: hasAmount ? null : const Color(0xFFF8F9FC),
        boxShadow: AppShadows.elevated,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: hasAmount
                      ? Colors.white.withValues(alpha: 0.15)
                      : AppColors.forest.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: hasAmount ? Colors.white : AppColors.forest,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasAmount ? 'Ready to save' : 'Enter amount',
                      style: TextStyle(
                        color: hasAmount ? Colors.white : AppColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      hasAmount
                          ? '${SalesUiUtils.formatMinor(minor, symbol: '₵')} · $categoryLabel'
                          : 'Choose category and amount above',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hasAmount
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppColors.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: (canSave && !isBusy) ? onSave : null,
                  icon: Icon(
                    isBusy ? Icons.hourglass_top_rounded : Icons.save_rounded,
                    size: 17,
                  ),
                  label: Text(isBusy ? 'Saving...' : 'Save'),
                  style: FilledButton.styleFrom(
                    backgroundColor: hasAmount ? Colors.white : AppColors.forest,
                    foregroundColor: hasAmount ? AppColors.forest : Colors.white,
                    disabledBackgroundColor: const Color(0xFFCCCCCC),
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
