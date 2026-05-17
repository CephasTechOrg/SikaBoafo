import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/debts_ui_tokens.dart';

/// MoMo phone number input. Accepts digits, plus signs, and spaces; the
/// repository normalizes to the Ghana 10-digit form server-side.
class DebtMomoPhoneField extends StatelessWidget {
  const DebtMomoPhoneField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.fieldKey,
    required this.keyboardInset,
    required this.testMode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final GlobalKey fieldKey;
  final double keyboardInset;
  final bool testMode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d+\s]'))],
      cursorColor: DebtsUi.greenMid,
      style: const TextStyle(fontSize: 14, color: DebtsUi.textPrimary),
      scrollPadding: EdgeInsets.only(
        bottom: keyboardInset + 120,
        left: 16,
        right: 16,
        top: 24,
      ),
      decoration: InputDecoration(
        labelText: 'Customer MoMo number',
        labelStyle: const TextStyle(
          fontSize: 12.5,
          color: DebtsUi.textSecondary,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 12.5,
          color: DebtsUi.greenMid,
          fontWeight: FontWeight.w700,
        ),
        hintText: testMode ? 'Test MTN: 0551234987' : 'e.g. 055 123 4567',
        hintStyle: const TextStyle(
          fontSize: 13,
          color: DebtsUi.textMuted,
        ),
        filled: true,
        fillColor: DebtsUi.surface2,
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
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
