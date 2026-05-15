import 'package:flutter/material.dart';

import '../utils/debts_ui_tokens.dart';

/// Empty state shown on Debts list when no debts match the filter / search.
/// Mockup-aligned: surface card with green-tinted icon tile, title, copy,
/// and a gradient CTA button.
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
        color: DebtsUi.surface,
        borderRadius: BorderRadius.circular(DebtsUi.radiusLg),
        border: Border.all(color: DebtsUi.border, width: 1.5),
        boxShadow: DebtsUi.shadowSm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: DebtsUi.greenPale,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: DebtsUi.greenLight, width: 1.5),
            ),
            child: const Icon(
              Icons.handshake_outlined,
              size: 32,
              color: DebtsUi.greenMid,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
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
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: _CtaButton(label: ctaLabel, onTap: onCreateDebt),
          ),
        ],
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: DebtsUi.ctaGradient,
          borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
          boxShadow: const [
            BoxShadow(
              color: Color(0x59166B42),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
