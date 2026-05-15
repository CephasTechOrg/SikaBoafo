import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/debts_ui_tokens.dart';
import '../../utils/debts_ui_utils.dart';

/// Amount input for the receive-payment sheet, with quick-fill chips for
/// "Half" and "Full" (the entire outstanding amount). Styled with the shared
/// debts mockup design language.
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
          cursorColor: DebtsUi.greenMid,
          style: const TextStyle(
            fontSize: 22,
            color: DebtsUi.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            labelText: 'Amount received',
            labelStyle: const TextStyle(
              fontSize: 12.5,
              color: DebtsUi.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            floatingLabelStyle: const TextStyle(
              fontSize: 12.5,
              color: DebtsUi.greenMid,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 8, 0),
              child: Text(
                '₵',
                style: TextStyle(
                  fontSize: 22,
                  color: DebtsUi.greenMid,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: DebtsUi.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
              borderSide: const BorderSide(color: DebtsUi.border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
              borderSide: const BorderSide(color: DebtsUi.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
              borderSide: const BorderSide(color: DebtsUi.greenMid, width: 1.8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: enabled ? DebtsUi.greenPale : DebtsUi.surface2,
            borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
            border: Border.all(
              color: enabled ? DebtsUi.greenLight : DebtsUi.border,
              width: 1.5,
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
                  color: enabled ? DebtsUi.greenMid : DebtsUi.textMuted,
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
                  fontSize: 13,
                  color: enabled ? DebtsUi.textPrimary : DebtsUi.textMuted,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
