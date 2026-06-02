import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../utils/debts_ui_tokens.dart';

/// Compact search input matching `debts UI mockup` `.search-bar`: white surface
/// with a 1.5px border, leading magnifier icon, muted hint copy.
class DebtsSearchBar extends StatelessWidget {
  const DebtsSearchBar({
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
        border: Border.all(color: DebtsUi.borderNeutral, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: DebtsUi.textPrimary,
        style: const TextStyle(
          fontSize: 13.5,
          color: DebtsUi.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search by customer or invoice…',
          hintStyle: const TextStyle(
            fontSize: 13.5,
            color: DebtsUi.textMuted,
            fontWeight: FontWeight.w500,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          prefixIcon: const Icon(
            LucideIcons.search,
            size: 18,
            color: DebtsUi.textMuted,
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 32, minHeight: 0),
          suffixIcon: hasQuery
              ? IconButton(
                  onPressed: onClear,
                  icon: const Icon(
                    LucideIcons.x,
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
