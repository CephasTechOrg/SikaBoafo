import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../sales/presentation/utils/sales_ui_utils.dart';

/// Fixed bottom action bar for the "Log expense" tab.
///
/// Matches the mockup exactly:
/// - White bg, border-top #E5E7EB, padding 11×16, upward shadow
/// - Left: 44×44 icon tile (green-tint/green-700 when ready, gray when not)
/// - Centre: main label + sub label
/// - Right: "Save" pill button (green when ready, gray when disabled)
class ExpensesBottomBar extends StatelessWidget {
  const ExpensesBottomBar({
    super.key,
    required this.amountText,
    required this.categoryLabel,
    required this.canSave,
    required this.isBusy,
    required this.onSave,
  });

  final String amountText;
  final String categoryLabel;
  final bool canSave;
  final bool isBusy;
  final VoidCallback onSave;

  // Design tokens
  static const Color _greenTint = Color(0xFFEAF6EF);
  static const Color _green700 = Color(0xFF0F7A4A);
  static const Color _ink = Color(0xFF111827);
  static const Color _ink2 = Color(0xFF6B7280);
  static const Color _ink3 = Color(0xFF9AA3AF);
  static const Color _line = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    final minor = SalesUiUtils.moneyToMinorSafe(amountText);
    final ready = canSave && minor > 0;

    final mainLabel = ready
        ? '$categoryLabel · ${SalesUiUtils.formatMinor(minor, symbol: '₵')}'
        : 'Enter amount';
    final subLabel = ready
        ? 'Ready to save this expense'
        : 'Choose a category and amount';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _line, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D101828),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              // Left icon tile
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ready ? _greenTint : const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  LucideIcons.receipt,
                  size: 21,
                  color: ready ? _green700 : _ink3,
                ),
              ),
              const SizedBox(width: 12),
              // Centre labels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mainLabel,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _ink2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Save button
              SizedBox(
                height: 46,
                child: TextButton(
                  onPressed: (ready && !isBusy) ? onSave : null,
                  style: TextButton.styleFrom(
                    backgroundColor: ready
                        ? const Color(0xFF168A55)
                        : const Color(0xFFE7EAE9),
                    foregroundColor:
                        ready ? Colors.white : const Color(0xFF9AA3AF),
                    disabledBackgroundColor: const Color(0xFFE7EAE9),
                    disabledForegroundColor: const Color(0xFF9AA3AF),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBusy
                            ? LucideIcons.loader
                            : LucideIcons.check,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(isBusy ? 'Saving…' : 'Save'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
