import 'package:flutter/material.dart';

import '../../../../../app/theme/app_theme.dart';

/// Method picker for the receive-payment sheet. Three options:
/// cash, mobile money, bank transfer — laid out as selectable cards.
class ReceivePaymentMethodSelector extends StatelessWidget {
  const ReceivePaymentMethodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How did the customer pay?',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        _MethodCard(
          icon: Icons.payments_rounded,
          title: 'Cash',
          subtitle: 'Received in hand',
          value: 'cash',
          selected: selected == 'cash',
          onTap: () => onChanged('cash'),
        ),
        const SizedBox(height: 8),
        _MethodCard(
          icon: Icons.smartphone_rounded,
          title: 'Mobile money',
          subtitle: 'MoMo / Vodafone Cash / AT Money',
          value: 'mobile_money',
          selected: selected == 'mobile_money',
          onTap: () => onChanged('mobile_money'),
        ),
        const SizedBox(height: 8),
        _MethodCard(
          icon: Icons.account_balance_rounded,
          title: 'Bank transfer',
          subtitle: 'Direct deposit or transfer',
          value: 'bank_transfer',
          selected: selected == 'bank_transfer',
          onTap: () => onChanged('bank_transfer'),
        ),
      ],
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.forest.withValues(alpha: 0.07)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.forestDark.withValues(alpha: 0.55)
                : AppColors.border,
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.forestDark
                    : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppColors.inkSoft,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: selected
                  ? const Icon(
                      Icons.check_circle_rounded,
                      key: ValueKey('selected'),
                      color: AppColors.forestDark,
                      size: 22,
                    )
                  : const Icon(
                      Icons.radio_button_unchecked_rounded,
                      key: ValueKey('unselected'),
                      color: AppColors.mutedSoft,
                      size: 22,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
