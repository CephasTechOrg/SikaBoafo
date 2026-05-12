import 'package:flutter/material.dart';

import '../../../../../app/theme/app_theme.dart';

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
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
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
