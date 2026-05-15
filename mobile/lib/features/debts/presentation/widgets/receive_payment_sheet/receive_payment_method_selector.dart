import 'package:flutter/material.dart';

import '../../utils/debts_ui_tokens.dart';

/// Method picker for the receive-payment sheet.
///
/// Manual "Receive payment" is for in-person collection, so we intentionally
/// keep this flow cash-only. Digital collections (mobile money, bank, card)
/// should go through the online payment link / QR flow above the sheet,
/// which records a [ReceivablePayment] server-side automatically.
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
            color: DebtsUi.textSecondary,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? DebtsUi.greenPale : DebtsUi.surface,
            borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
            border: Border.all(
              color: selected ? DebtsUi.greenMid : DebtsUi.border,
              width: 1.5,
            ),
            boxShadow: selected ? null : DebtsUi.shadowSm,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? DebtsUi.greenMid : DebtsUi.surface2,
                  borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
                  border: Border.all(
                    color:
                        selected ? DebtsUi.greenMid : DebtsUi.border,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : DebtsUi.textSecondary,
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
                        color: DebtsUi.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: DebtsUi.textSecondary,
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
                        color: DebtsUi.greenMid,
                        size: 22,
                      )
                    : const Icon(
                        Icons.radio_button_unchecked_rounded,
                        key: ValueKey('unselected'),
                        color: DebtsUi.textMuted,
                        size: 22,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
