import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../data/expenses_repository.dart';
import '../providers/expenses_providers.dart';
import 'expenses_category_meta.dart';
import 'widgets/expense_edit_sheet.dart';
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
  final _otherNameCtrl = TextEditingController();

  void _onAmountChanged() => setState(() {});

  void _onOtherNameChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_onAmountChanged);
    _otherNameCtrl.addListener(_onOtherNameChanged);
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onAmountChanged);
    _otherNameCtrl.removeListener(_onOtherNameChanged);
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _otherNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesControllerProvider);
    final expenses = expensesAsync.valueOrNull ?? const <LocalExpenseRecord>[];

    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final monthStart = DateTime(now.year, now.month).millisecondsSinceEpoch;

    int todayMinor = 0, monthMinor = 0, todayEntryCount = 0;
    final catMinors = <String, int>{};
    final monthCategories = <String>{};
    for (final e in expenses) {
      final v = _toMinor(e.amount);
      if (e.createdAtMillis >= todayStart) {
        todayMinor += v;
        todayEntryCount++;
      }
      if (e.createdAtMillis >= monthStart) {
        monthMinor += v;
        monthCategories.add(e.category);
      }
      catMinors[e.category] = (catMinors[e.category] ?? 0) + v;
    }

    final isBusy = expensesAsync.isLoading;
    final minor = _toMinor(_amountCtrl.text);
    final amountOk = minor > 0 &&
        RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(_amountCtrl.text.trim());
    final otherOk =
        _category != 'other' || _otherNameCtrl.text.trim().isNotEmpty;
    final canSave = amountOk && otherOk;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    const kLeadingGutter = 56.0;
    final heroInset = canPop ? kLeadingGutter : 20.0;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: 210,
                pinned: true,
                stretch: true,
                leadingWidth: canPop ? kLeadingGutter : null,
                leading: canPop
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () => Navigator.of(context).maybePop(),
                      )
                    : null,
                backgroundColor: AppColors.forestNight,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: ExpensesHeader(
                    leadingContentInset: heroInset,
                    monthMinor: monthMinor,
                    todayMinor: todayMinor,
                    todayEntryCount: todayEntryCount,
                    monthCategoryCount: monthCategories.length,
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
                  titlePadding: EdgeInsetsDirectional.only(
                    start: heroInset,
                    bottom: 16,
                  ),
                ),
              ),
              // Extend the hero background slightly so the rounded sheet corners
              // reveal the header color (no extra edge/underlay colors).
              const SliverToBoxAdapter(
                child: ColoredBox(
                  color: AppColors.forestNight,
                  child: SizedBox(height: 18),
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
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: AppColors.surface),
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
                          otherNameCtrl: _otherNameCtrl,
                          onCategoryChanged: (c) =>
                              setState(() => _category = c),
                        )
                      else
                        ExpensesHistoryView(
                          expenses: expenses,
                          isLoadingEmpty:
                              expensesAsync.isLoading && expenses.isEmpty,
                          onEditExpense: (row) async {
                            await showExpenseEditSheet(context, record: row);
                          },
                        ),
                    ],
                  ),
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
                categoryLabel: expenseSaveCategoryLabel(
                  _category,
                  _otherNameCtrl.text,
                ),
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
    if (_category == 'other' && _otherNameCtrl.text.trim().isEmpty) {
      _showMsg('Enter a name for this expense.');
      return;
    }
    final storedNote = buildStoredExpenseNote(
      category: _category,
      otherName: _otherNameCtrl.text,
      additionalNote: _noteCtrl.text,
    );
    try {
      await ref.read(expensesControllerProvider.notifier).createExpense(
            category: _category,
            amount: amount,
            note: storedNote,
          );
      _amountCtrl.clear();
      _noteCtrl.clear();
      _otherNameCtrl.clear();
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
    return ColoredBox(
      color: AppColors.forestNight,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: AppRadii.heroRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: overlapsContent
                  ? const [
                      BoxShadow(
                        color: Color(0x1F0F172A),
                        blurRadius: 28,
                        offset: Offset(0, -8),
                      ),
                    ]
                  : null,
            ),
            child: SizedBox(height: maxExtent - 22, child: child),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverExpensesTabDelegate oldDelegate) =>
      oldDelegate.activeTab != activeTab;
}
