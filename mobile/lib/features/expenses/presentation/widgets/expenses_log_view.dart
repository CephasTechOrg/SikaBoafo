import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../expenses_category_meta.dart';

/// "Log expense" tab content — matches the mockup exactly.
class ExpensesLogView extends StatelessWidget {
  const ExpensesLogView({
    super.key,
    required this.catMinors,
    required this.category,
    required this.amountCtrl,
    required this.noteCtrl,
    required this.otherNameCtrl,
    required this.onCategoryChanged,
  });

  final Map<String, int> catMinors;
  final String category;
  final TextEditingController amountCtrl;
  final TextEditingController noteCtrl;
  final TextEditingController otherNameCtrl;
  final ValueChanged<String> onCategoryChanged;

  // Design tokens (local constants matching mockup)
  static const Color _ink = Color(0xFF111827);
  static const Color _ink2 = Color(0xFF6B7280);
  static const Color _ink3 = Color(0xFF9AA3AF);
  static const Color _line = Color(0xFFE5E7EB);
  static const Color _card = Colors.white;
  static const Color _warn = Color(0xFFBE8A2C);
  static const Color _warnTint = Color(0xFFFAF3E1);
  static const Color _green600 = Color(0xFF168A55);
  static const Color _activeChipBg = Color(0xFF073B2A);

  // Icon mapping per category key
  static IconData _iconFor(String key) => switch (key) {
        'inventory_purchase' => LucideIcons.package,
        'transport' => LucideIcons.truck,
        'utilities' => LucideIcons.zap,
        'rent' => LucideIcons.building,
        'salary' => LucideIcons.users,
        'tax' => LucideIcons.landmark,
        _ => LucideIcons.grid,
      };

  @override
  Widget build(BuildContext context) {
    final amountFilled = amountCtrl.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section intro ──────────────────────────────────────────────
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _warnTint,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                LucideIcons.clipboardList,
                size: 19,
                color: _warn,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Record spending',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Pick a category and enter the amount.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _ink2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── Category ───────────────────────────────────────────────────
        const _SecLabel(text: 'Category', topMargin: 20, bottomMargin: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kExpenseCategories.entries.map((entry) {
            final isSel = entry.key == category;
            return GestureDetector(
              onTap: () => onCategoryChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: isSel ? _activeChipBg : _card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSel ? Colors.transparent : _line,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconFor(entry.key),
                      size: 15,
                      color: isSel ? Colors.white : _ink2,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      entry.value.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSel ? Colors.white : _ink2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        // ── Other name field (only when 'other' is selected) ───────────
        if (category == 'other') ...[
          const _SecLabel(text: 'Name', topMargin: 18, bottomMargin: 10),
          _NoteContainer(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(LucideIcons.tag, size: 18, color: _ink3),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: otherNameCtrl,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: _ink,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Office supplies, Bank charges',
                      hintStyle: TextStyle(color: _ink3, fontSize: 14.5),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Amount ─────────────────────────────────────────────────────
        const _SecLabel(text: 'Amount', topMargin: 20, bottomMargin: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: amountFilled ? _green600 : _line,
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A101828),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
              BoxShadow(
                color: Color(0x0A101828),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(
                '₵',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: amountFilled ? _ink : _ink3,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.4,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: _ink3,
                      letterSpacing: -0.4,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const Text(
                'GHS',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _ink3,
                ),
              ),
            ],
          ),
        ),

        // ── Note ───────────────────────────────────────────────────────
        const _SecLabelOptional(topMargin: 18, bottomMargin: 10),
        _NoteContainer(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(LucideIcons.fileText, size: 18, color: _ink3),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: noteCtrl,
                  maxLines: null,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: _ink,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Add a note for this expense…',
                    hintStyle: TextStyle(color: _ink3, fontSize: 14.5),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),

      ],
    );
  }
}

/// Shared container for the note / other-name text fields.
class _NoteContainer extends StatelessWidget {
  const _NoteContainer({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

/// Section label — "CATEGORY", "AMOUNT", etc.
class _SecLabel extends StatelessWidget {
  const _SecLabel({
    required this.text,
    required this.topMargin,
    required this.bottomMargin,
  });
  final String text;
  final double topMargin;
  final double bottomMargin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topMargin, bottom: bottomMargin),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.10 * 12,
          color: Color(0xFF9AA3AF),
        ),
      ),
    );
  }
}

/// Special "NOTE · optional" label.
class _SecLabelOptional extends StatelessWidget {
  const _SecLabelOptional({
    required this.topMargin,
    required this.bottomMargin,
  });
  final double topMargin;
  final double bottomMargin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topMargin, bottom: bottomMargin),
      child: RichText(
        text: const TextSpan(
          children: [
            TextSpan(
              text: 'NOTE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Color(0xFF9AA3AF),
              ),
            ),
            TextSpan(
              text: ' · optional',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
                color: Color(0xFF9AA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
