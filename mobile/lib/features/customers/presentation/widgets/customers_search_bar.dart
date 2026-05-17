import 'package:flutter/material.dart';

import '../../../debts/presentation/utils/debts_ui_tokens.dart';

class CustomersSearchBar extends StatelessWidget {
  const CustomersSearchBar({
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
        color: DebtsUi.surface,
        borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
        border: Border.all(color: DebtsUi.border, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: DebtsUi.greenMid,
        style: const TextStyle(
          fontSize: 14,
          color: DebtsUi.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search by name or phone…',
          hintStyle: const TextStyle(
            fontSize: 14,
            color: DebtsUi.textMuted,
            fontWeight: FontWeight.w500,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 18,
            color: DebtsUi.textMuted,
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 32, minHeight: 0),
          suffixIcon: hasQuery
              ? IconButton(
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: DebtsUi.textMuted,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
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
