import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../data/expenses_repository.dart';
import '../expenses_category_meta.dart';

/// "History" tab content — matches the mockup's single-card layout.
class ExpensesHistoryView extends StatelessWidget {
  const ExpensesHistoryView({
    super.key,
    required this.expenses,
    required this.isLoadingEmpty,
    required this.onEditExpense,
  });

  final List<LocalExpenseRecord> expenses;
  final bool isLoadingEmpty;
  final Future<void> Function(LocalExpenseRecord row) onEditExpense;

  // Design tokens
  static const Color _ink3 = Color(0xFF9AA3AF);
  static const Color _lineSoft = Color(0xFFEEF1F0);

  // Category → LucideIcons mapping
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
    final count = expenses.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        // Section header: "THIS MONTH" | "{n} entries"
        Row(
          children: [
            const Text(
              'THIS MONTH',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.10 * 12,
                color: _ink3,
              ),
            ),
            const Spacer(),
            Text(
              '$count ${count == 1 ? 'entry' : 'entries'}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _ink3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (isLoadingEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          // Single card wrapping all rows
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _lineSoft),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A101828),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
                BoxShadow(
                  color: Color(0x0A101828),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: expenses.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No expenses this month',
                        style: TextStyle(
                          fontSize: 14,
                          color: _ink3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < expenses.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: _lineSoft,
                          ),
                        _ExpenseRow(
                          row: expenses[i],
                          iconData: _iconFor(expenses[i].category),
                          onTap: () => onEditExpense(expenses[i]),
                        ),
                      ],
                    ],
                  ),
          ),

        const SizedBox(height: 16),
      ],
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.row,
    required this.iconData,
    required this.onTap,
  });

  final LocalExpenseRecord row;
  final IconData iconData;
  final VoidCallback onTap;

  static const Color _ink = Color(0xFF111827);
  static const Color _ink2 = Color(0xFF6B7280);
  static const Color _ink3 = Color(0xFF9AA3AF);
  static const Color _warn = Color(0xFFBE8A2C);
  static const Color _warnTint = Color(0xFFFAF3E1);

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(row.createdAtMillis);
    final meta = expenseMetaFor(row.category);
    final displayNote = expenseNoteDisplayLine(row.category, row.note);
    final dateStr = DateFormat('MMM d').format(dt.toLocal());

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _warnTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, size: 19, color: _warn),
            ),
            const SizedBox(width: 13),
            // Middle: category + note
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta.label,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayNote,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _ink2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right: amount + date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '−₵${row.amount}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _ink3,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
