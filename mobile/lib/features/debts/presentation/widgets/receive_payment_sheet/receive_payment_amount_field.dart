import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/theme/app_theme.dart';
import '../../utils/debts_ui_utils.dart';

/// Amount input for the receive-payment sheet, with quick-fill chips for
/// "Half" and "Full" (the entire outstanding amount).
class ReceivePaymentAmountField extends StatelessWidget {
  const ReceivePaymentAmountField({
    super.key,
    required this.controller,
    required this.outstandingMinor,
    required this.onQuickFill,
  });

  final TextEditingController controller;
  final int outstandingMinor;
  final ValueChanged<String> onQuickFill;

  @override
  Widget build(BuildContext context) {
    final halfMinor = outstandingMinor ~/ 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          style: const TextStyle(
            fontSize: 20,
            color: AppColors.ink,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            labelText: 'Amount received',
            prefixIcon: const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 8, 0),
              child: Text(
                '₵',
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.forest, width: 1.4),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _QuickFill(
                label: 'Half',
                value: DebtsUiUtils.formatMinor(halfMinor),
                enabled: halfMinor > 0,
                onTap: () => onQuickFill(_minorToDecimal(halfMinor)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickFill(
                label: 'Full',
                value: DebtsUiUtils.formatMinor(outstandingMinor),
                enabled: outstandingMinor > 0,
                onTap: () =>
                    onQuickFill(_minorToDecimal(outstandingMinor)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _minorToDecimal(int minor) {
    final major = minor ~/ 100;
    final cents = (minor % 100).toString().padLeft(2, '0');
    return '$major.$cents';
  }
}

class _QuickFill extends StatelessWidget {
  const _QuickFill({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.forest.withValues(alpha: 0.06)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? AppColors.forest.withValues(alpha: 0.30)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: enabled ? AppColors.forestDark : AppColors.mutedSoft,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: enabled ? AppColors.ink : AppColors.mutedSoft,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
