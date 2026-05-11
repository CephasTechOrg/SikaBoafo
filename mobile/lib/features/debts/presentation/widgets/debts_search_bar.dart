import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class DebtsSearchBar extends StatelessWidget {
  const DebtsSearchBar({
    super.key,
    required this.onChanged,
    required this.onClear,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: true,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: 'Search by customer name…',
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          color: AppColors.muted,
          onPressed: onClear,
        ),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
