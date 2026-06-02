import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum SalesViewTab { newSale, history }

class SalesTabBar extends StatelessWidget {
  const SalesTabBar({
    super.key,
    required this.activeTab,
    required this.onChanged,
    this.darkMode = false,
  });

  final SalesViewTab activeTab;
  final ValueChanged<SalesViewTab> onChanged;
  // darkMode kept for API compat but not used — all tabs now follow mockup style.
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEBEFED),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Tab(
              label: 'New Sale',
              selected: activeTab == SalesViewTab.newSale,
              onTap: () => onChanged(SalesViewTab.newSale),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _Tab(
              label: 'History',
              selected: activeTab == SalesViewTab.history,
              onTap: () => onChanged(SalesViewTab.history),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 42,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF073B2A) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x40073B2A),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
