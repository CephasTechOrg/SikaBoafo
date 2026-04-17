import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../data/expenses_repository.dart';
import '../providers/expenses_providers.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _category = 'inventory_purchase';
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

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

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F4E43), Color(0xFF1A6B5B), AppColors.canvas],
            stops: [0.0, 0.22, 0.22],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => ref.read(expensesControllerProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const _ExpenseHero(),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add Expense', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          decoration: const InputDecoration(labelText: 'Category'),
                          items: ExpensesRepository.allowedCategories
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_categoryLabel(value)),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _category = value);
                          },
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            hintText: 'e.g. 35.50',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _noteCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Note (optional)'),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: expensesAsync.isLoading ? null : _saveExpense,
                            icon: const Icon(Icons.receipt_long_rounded),
                            label: Text(expensesAsync.isLoading ? 'Saving...' : 'Save Expense'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Expense History', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                if (expensesAsync.isLoading && expenses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (expenses.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No expenses recorded yet.'),
                    ),
                  )
                else
                  ...expenses.map(_buildExpenseTile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseTile(LocalExpenseRecord row) {
    final dt = DateTime.fromMillisecondsSinceEpoch(row.createdAtMillis);
    final syncColor = switch (row.syncStatus) {
      'applied' || 'duplicate' => AppColors.success,
      'failed' => AppColors.danger,
      'conflict' => AppColors.warning,
      _ => AppColors.warning,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.work_outline_rounded, color: AppColors.warning),
        ),
        title: Text(
          'GHS ${row.amount}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${_categoryLabel(row.category)} | ${row.note ?? "No note"} | ${dt.toLocal()}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          row.syncStatus,
          style: TextStyle(
            color: syncColor,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Future<void> _saveExpense() async {
    final amount = _amountCtrl.text.trim();
    if (amount.isEmpty) {
      _showMessage('Enter a valid amount.');
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
      _showMessage('Expense recorded.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _categoryLabel(String value) {
    return switch (value) {
      'inventory_purchase' => 'Inventory Purchase',
      'transport' => 'Transport',
      'utilities' => 'Utilities',
      'rent' => 'Rent',
      'salary' => 'Salary',
      'tax' => 'Tax',
      _ => 'Other',
    };
  }
}

class _ExpenseHero extends StatelessWidget {
  const _ExpenseHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFEDE6D8), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Expenses', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'Capture money leaving the business without slowing daily work.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: AppColors.warning),
          ),
        ],
      ),
    );
  }
}
