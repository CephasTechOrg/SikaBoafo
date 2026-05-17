import 'package:flutter/material.dart';

import '../../../debts/presentation/utils/debts_ui_tokens.dart';
import '../../../debts/presentation/widgets/debts_gradient_button.dart';

class CustomersEmptyState extends StatelessWidget {
  const CustomersEmptyState({
    super.key,
    required this.onAddCustomer,
    this.title = 'No customers yet',
    this.message =
        'Save people you sell to on credit. Track balances and debt history '
        'in one place.',
    this.ctaLabel = 'Add customer',
  });

  factory CustomersEmptyState.filtered({
    required VoidCallback onAddCustomer,
    required String filterLabel,
  }) {
    return CustomersEmptyState(
      onAddCustomer: onAddCustomer,
      title: 'No $filterLabel customers',
      message: 'Nothing matches the "$filterLabel" filter. Try another tab or '
          'clear your search.',
      ctaLabel: 'Add customer',
    );
  }

  final VoidCallback onAddCustomer;
  final String title;
  final String message;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: DebtsUi.surface,
        borderRadius: BorderRadius.circular(DebtsUi.radiusLg),
        border: Border.all(color: DebtsUi.borderNeutral, width: 1.5),
        boxShadow: DebtsUi.shadowNeutralSm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: DebtsUi.avatarNeutralBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: DebtsUi.avatarNeutralBorder, width: 1.5),
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 32,
              color: DebtsUi.avatarNeutralFg,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Constantia',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: DebtsUi.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: DebtsUi.textSecondary,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          DebtsGradientButton(
            label: ctaLabel,
            icon: Icons.person_add_alt_rounded,
            onPressed: onAddCustomer,
          ),
        ],
      ),
    );
  }
}
