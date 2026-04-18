import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../data/expenses_repository.dart';
import '../providers/expenses_providers.dart';

// ─── category metadata ────────────────────────────────────────────────────────

class _CatMeta {
  const _CatMeta(this.label, this.icon, this.color, this.bg);
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
}

const _kCats = <String, _CatMeta>{
  'inventory_purchase': _CatMeta(
    'Inventory',
    Icons.shopping_cart_rounded,
    Color(0xFF0F766E),
    Color(0xFFE6F4F1),
  ),
  'transport': _CatMeta(
    'Transport',
    Icons.directions_car_rounded,
    Color(0xFF2563EB),
    Color(0xFFEFF6FF),
  ),
  'utilities': _CatMeta(
    'Utilities',
    Icons.bolt_rounded,
    Color(0xFFD97706),
    Color(0xFFFFFBEB),
  ),
  'rent': _CatMeta(
    'Rent',
    Icons.home_rounded,
    Color(0xFFEA580C),
    Color(0xFFFFF7ED),
  ),
  'salary': _CatMeta(
    'Salary',
    Icons.people_rounded,
    Color(0xFF7C3AED),
    Color(0xFFF5F3FF),
  ),
  'tax': _CatMeta(
    'Tax',
    Icons.account_balance_rounded,
    Color(0xFFDC2626),
    Color(0xFFFEF2F2),
  ),
  'other': _CatMeta(
    'Other',
    Icons.receipt_long_rounded,
    Color(0xFF6B7280),
    Color(0xFFF9FAFB),
  ),
};

// ─── helpers ──────────────────────────────────────────────────────────────────

int _toMinor(String value) {
  final parts = value.trim().split('.');
  final major = int.tryParse(parts[0]) ?? 0;
  final raw = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
  return (major * 100) + (int.tryParse(raw.substring(0, 2)) ?? 0);
}

String _fmtMoney(int minor) {
  final major = minor ~/ 100;
  final cents = (minor % 100).toString().padLeft(2, '0');
  return 'GHS $major.$cents';
}

// ─── screen ───────────────────────────────────────────────────────────────────

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _category = 'inventory_purchase';
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _showForm = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesControllerProvider);
    final expenses = expensesAsync.valueOrNull ?? const <LocalExpenseRecord>[];

    // O(n) single-pass stats + category buckets
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final monthStart = DateTime(now.year, now.month).millisecondsSinceEpoch;

    int todayMinor = 0, monthMinor = 0;
    final catMinors = <String, int>{};
    for (final e in expenses) {
      final v = _toMinor(e.amount);
      if (e.createdAtMillis >= todayStart) todayMinor += v;
      if (e.createdAtMillis >= monthStart) monthMinor += v;
      catMinors[e.category] = (catMinors[e.category] ?? 0) + v;
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A3D33), Color(0xFF1A6B5B), AppColors.canvas],
            stops: [0.0, 0.28, 0.28],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                monthMinor: monthMinor,
                onRefresh: () =>
                    ref.read(expensesControllerProvider.notifier).refresh(),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  child: Container(
                    color: AppColors.canvas,
                    child: RefreshIndicator(
                      onRefresh: () =>
                          ref.read(expensesControllerProvider.notifier).refresh(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(16, 20, 16, 100),
                        children: [
                          _StatsRow(
                            todayMinor: todayMinor,
                            monthMinor: monthMinor,
                            count: expenses.length,
                          ),
                          const SizedBox(height: 16),
                          if (catMinors.isNotEmpty) ...[
                            _CategoryBreakdownCard(catMinors: catMinors),
                            const SizedBox(height: 16),
                          ],
                          _LogExpenseCard(
                            expanded: _showForm,
                            category: _category,
                            amountCtrl: _amountCtrl,
                            noteCtrl: _noteCtrl,
                            isLoading: expensesAsync.isLoading,
                            onToggle: () =>
                                setState(() => _showForm = !_showForm),
                            onCategoryChanged: (c) =>
                                setState(() => _category = c),
                            onSave: _saveExpense,
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              const Text(
                                'Expense History',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.ink,
                                ),
                              ),
                              if (expenses.isNotEmpty) ...[
                                const Spacer(),
                                Text(
                                  '${expenses.length} entries',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (expensesAsync.isLoading && expenses.isEmpty)
                            const _LoadingCard()
                          else if (expenses.isEmpty)
                            const _EmptyCard()
                          else
                            ...expenses.map(_buildExpenseTile),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseTile(LocalExpenseRecord row) {
    final dt = DateTime.fromMillisecondsSinceEpoch(row.createdAtMillis);
    final meta = _kCats[row.category] ?? _kCats['other']!;
    final syncColor = switch (row.syncStatus) {
      'applied' || 'duplicate' => AppColors.success,
      'failed' => AppColors.danger,
      'conflict' => AppColors.amber,
      _ => AppColors.amber,
    };
    final syncLabel = switch (row.syncStatus) {
      'applied' || 'duplicate' => 'Synced',
      'failed' => 'Failed',
      'conflict' => 'Conflict',
      _ => 'Pending',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: meta.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(meta.icon, color: meta.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          meta.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'GHS ${row.amount}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: meta.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.note?.isNotEmpty == true
                              ? row.note!
                              : 'No note',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM d, HH:mm').format(dt.toLocal()),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: syncColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        syncLabel,
                        style: TextStyle(
                          color: syncColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveExpense() async {
    final amount = _amountCtrl.text.trim();
    if (amount.isEmpty) {
      _showMsg('Enter a valid amount.');
      return;
    }
    try {
      await ref.read(expensesControllerProvider.notifier).createExpense(
            category: _category,
            amount: amount,
            note: _noteCtrl.text,
          );
      _amountCtrl.clear();
      _noteCtrl.clear();
      if (!mounted) return;
      setState(() => _showForm = false);
      _showMsg('Expense recorded.');
    } catch (error) {
      if (!mounted) return;
      _showMsg(error.toString());
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ─── header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.monthMinor, required this.onRefresh});
  final int monthMinor;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Expenses',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'This month: ${_fmtMoney(monthMinor)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.todayMinor,
    required this.monthMinor,
    required this.count,
  });
  final int todayMinor, monthMinor, count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Today',
            value: _fmtMoney(todayMinor),
            icon: Icons.today_rounded,
            color: AppColors.forest,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'This Month',
            value: _fmtMoney(monthMinor),
            icon: Icons.calendar_month_rounded,
            color: const Color(0xFFD97706),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Entries',
            value: '$count',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF7C3AED),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: AppColors.ink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── category breakdown card ──────────────────────────────────────────────────

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({required this.catMinors});
  final Map<String, int> catMinors;

  @override
  Widget build(BuildContext context) {
    final total = catMinors.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final sorted = catMinors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pie_chart_rounded,
                    color: AppColors.forest, size: 17),
              ),
              const SizedBox(width: 10),
              const Text(
                'Spending by Category',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...sorted.take(6).map((entry) {
            final meta = _kCats[entry.key] ?? _kCats['other']!;
            final pct = entry.value / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: meta.bg,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(meta.icon, color: meta.color, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              meta.label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              '${(pct * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 6,
                            backgroundColor: meta.bg,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(meta.color),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'GHS ${(entry.value / 100).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── log expense accordion ────────────────────────────────────────────────────

class _LogExpenseCard extends StatelessWidget {
  const _LogExpenseCard({
    required this.expanded,
    required this.category,
    required this.amountCtrl,
    required this.noteCtrl,
    required this.isLoading,
    required this.onToggle,
    required this.onCategoryChanged,
    required this.onSave,
  });
  final bool expanded;
  final String category;
  final TextEditingController amountCtrl, noteCtrl;
  final bool isLoading;
  final VoidCallback onToggle, onSave;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: expanded
                ? const BorderRadius.vertical(top: Radius.circular(20))
                : BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: AppColors.forest, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Log Expense',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  const Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _CategoryPicker(
                    selected: category,
                    onChanged: onCategoryChanged,
                  ),
                  const SizedBox(height: 14),
                  _EField(
                    controller: amountCtrl,
                    label: 'Amount (GHS)',
                    hint: '0.00',
                    prefixIcon: Icons.payments_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                  const SizedBox(height: 10),
                  _EField(
                    controller: noteCtrl,
                    label: 'Note (optional)',
                    hint: 'What was this expense for?',
                    prefixIcon: Icons.notes_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : onSave,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: Text(
                          isLoading ? 'Saving...' : 'Save Expense'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── category picker chips ────────────────────────────────────────────────────

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker(
      {required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _kCats.entries.map((entry) {
        final isSel = entry.key == selected;
        final meta = entry.value;
        return GestureDetector(
          onTap: () => onChanged(entry.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color:
                  isSel ? meta.color.withValues(alpha: 0.14) : const Color(0xFFF6F7F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSel ? meta.color : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  meta.icon,
                  color: isSel ? meta.color : AppColors.muted,
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  meta.label,
                  style: TextStyle(
                    color: isSel ? meta.color : AppColors.muted,
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── shared helpers ───────────────────────────────────────────────────────────

class _EField extends StatelessWidget {
  const _EField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.keyboardType,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String label, hint;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, size: 18),
        filled: true,
        fillColor: const Color(0xFFF6F7F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.forest, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                color: AppColors.forest, size: 30),
          ),
          const SizedBox(height: 14),
          const Text(
            'No expenses yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap "Log Expense" above\nto record your first expense.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
