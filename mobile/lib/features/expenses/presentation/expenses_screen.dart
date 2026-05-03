import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../data/expenses_repository.dart';
import '../providers/expenses_providers.dart';
import 'expenses_category_meta.dart';
import 'widgets/expenses_bottom_bar.dart';
import 'widgets/expenses_header.dart';
import 'widgets/expenses_history_view.dart';
import 'widgets/expenses_log_view.dart';
import 'widgets/expenses_tab_bar.dart';

int _toMinor(String value) {
  final parts = value.trim().split('.');
  final major = int.tryParse(parts[0]) ?? 0;
  final raw = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
  return (major * 100) + (int.tryParse(raw.substring(0, 2)) ?? 0);
}

({String? key, int minor})? _topCategory(Map<String, int> catMinors) {
  if (catMinors.isEmpty) return null;
  var bestKey = catMinors.keys.first;
  var bestVal = catMinors[bestKey] ?? 0;
  for (final e in catMinors.entries) {
    if (e.value > bestVal) {
      bestVal = e.value;
      bestKey = e.key;
    }
  }
  return (key: bestKey, minor: bestVal);
}

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  ExpensesViewTab _activeTab = ExpensesViewTab.log;
  String _category = 'inventory_purchase';
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  void _onAmountChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onAmountChanged);
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesControllerProvider);
    final expenses = expensesAsync.valueOrNull ?? const <LocalExpenseRecord>[];
    final merchantAsync = ref.watch(merchantContextProvider);

    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final monthStart = DateTime(now.year, now.month).millisecondsSinceEpoch;

    int todayMinor = 0, monthMinor = 0, todayEntryCount = 0;
    final catMinors = <String, int>{};
    for (final e in expenses) {
      final v = _toMinor(e.amount);
      if (e.createdAtMillis >= todayStart) {
        todayMinor += v;
        todayEntryCount++;
      }
      if (e.createdAtMillis >= monthStart) monthMinor += v;
      catMinors[e.category] = (catMinors[e.category] ?? 0) + v;
    }

    final top = _topCategory(catMinors);
    final isBusy = expensesAsync.isLoading;
    final minor = _toMinor(_amountCtrl.text);
    final canSave = minor > 0 &&
        RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(_amountCtrl.text.trim());

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: 308,
                pinned: true,
                stretch: true,
                leading: ModalRoute.of(context)?.canPop == true
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () => Navigator.of(context).maybePop(),
                      )
                    : null,
                backgroundColor: const Color(0xFF071D11),
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: ExpensesHeader(
                    businessName:
                        merchantAsync.valueOrNull?.businessName ?? 'My Shop',
                    todayMinor: todayMinor,
                    monthMinor: monthMinor,
                    todayEntryCount: todayEntryCount,
                    topCategoryKey: top?.key,
                    topCategoryMinor: top?.minor,
                  ),
                  title: innerBoxIsScrolled
                      ? const Text(
                          'Expenses',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        )
                      : null,
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverExpensesTabDelegate(
                  activeTab: _activeTab,
                  child: ExpensesTabBar(
                    activeTab: _activeTab,
                    onChanged: (tab) => setState(() => _activeTab = tab),
                  ),
                ),
              ),
            ],
            body: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: RefreshIndicator(
                color: AppColors.forest,
                onRefresh: () =>
                    ref.read(expensesControllerProvider.notifier).refresh(),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    _activeTab == ExpensesViewTab.log ? 110 : 28,
                  ),
                  children: [
                    if (_activeTab == ExpensesViewTab.log)
                      ExpensesLogView(
                        catMinors: catMinors,
                        category: _category,
                        amountCtrl: _amountCtrl,
                        noteCtrl: _noteCtrl,
                        onCategoryChanged: (c) =>
                            setState(() => _category = c),
                      )
                    else
                      ExpensesHistoryView(
                        expenses: expenses,
                        isLoadingEmpty:
                            expensesAsync.isLoading && expenses.isEmpty,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_activeTab == ExpensesViewTab.log)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ExpensesBottomBar(
                amountText: _amountCtrl.text,
                categoryLabel: expenseMetaFor(_category).label,
                canSave: canSave,
                isBusy: isBusy,
                onSave: _saveExpense,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _saveExpense() async {
    final amount = _amountCtrl.text.trim();
    if (amount.isEmpty ||
        !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(amount) ||
        _toMinor(amount) <= 0) {
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
      _showMsg('Expense recorded.');
    } catch (error) {
      if (!mounted) return;
      _showMsg(error.toString());
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _SliverExpensesTabDelegate extends SliverPersistentHeaderDelegate {
  _SliverExpensesTabDelegate({required this.activeTab, required this.child});
  final ExpensesViewTab activeTab;
  final Widget child;

  @override
  double get minExtent => 78;

  @override
  double get maxExtent => 78;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.canvas,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          boxShadow: overlapsContent
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: SizedBox(height: maxExtent - 20, child: child),
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverExpensesTabDelegate oldDelegate) =>
      oldDelegate.activeTab != activeTab;
}
