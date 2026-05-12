import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/theme/app_theme.dart';

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
      scrollPadding: EdgeInsets.only(
        bottom: keyboardInset + 120,
        left: 16,
        right: 16,
        top: 24,
      ),
      decoration: InputDecoration(
        labelText: 'Customer MoMo number',
        hintText: testMode ? 'Test MTN: 0551234987' : 'e.g. 055 123 4567',
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
