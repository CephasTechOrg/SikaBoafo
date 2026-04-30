import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

class SalesSearchBar extends StatelessWidget {
  const SalesSearchBar({
    super.key,
    required this.controller,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13, color: AppColors.ink),
        decoration: InputDecoration(
          hintText: 'Search products',
          isDense: true,
          contentPadding: EdgeInsets.zero,
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 16,
            color: AppColors.muted,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 0,
          ),
          suffixIcon: hasQuery
              ? IconButton(
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
