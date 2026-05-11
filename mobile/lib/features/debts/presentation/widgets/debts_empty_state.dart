import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Empty-state card shown on Debts list when no debts match the current
/// filter / search. Tone shifts based on whether *any* debts exist.
class DebtsEmptyState extends StatelessWidget {
  const DebtsEmptyState({
    super.key,
    required this.onCreateDebt,
    this.title = 'No debts yet',
    this.message =
        'Track what customers owe you. Tap below to record your first '
        'debt — you can attach a customer and a due date.',
    this.ctaLabel = 'Record a debt',
  });

  /// Variant for "you have debts but none match this filter".
  factory DebtsEmptyState.filtered({
    required VoidCallback onCreateDebt,
    required String filterLabel,
  }) {
    return DebtsEmptyState(
      onCreateDebt: onCreateDebt,
      title: 'No $filterLabel debts',
      message: 'Nothing matches the "$filterLabel" filter right now. '
          'Try another tab or clear your search.',
      ctaLabel: 'Record a debt',
    );
  }

  final VoidCallback onCreateDebt;
  final String title;
  final String message;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.handshake_rounded,
              size: 34,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreateDebt,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(ctaLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forestDark,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
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
    );
  }
}
