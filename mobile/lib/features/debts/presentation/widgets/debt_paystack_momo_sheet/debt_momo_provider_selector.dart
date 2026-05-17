import 'package:flutter/material.dart';

import '../../utils/debts_ui_tokens.dart';

/// Network dropdown for MoMo charge: MTN, AirtelTigo, Telecel.
class DebtMomoProviderSelector extends StatelessWidget {
  const DebtMomoProviderSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Network',
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: DebtsUi.textPrimary,
          ),
          items: const [
            DropdownMenuItem(value: 'mtn', child: Text('MTN')),
            DropdownMenuItem(value: 'atl', child: Text('AirtelTigo')),
            DropdownMenuItem(value: 'vod', child: Text('Telecel')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
