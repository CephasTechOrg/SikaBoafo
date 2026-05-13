import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../data/local/kv_cache_repository.dart';
import '../../../shared/utils/user_friendly_error.dart';
import '../../../shared/widgets/stale_banner.dart';
import '../data/debts_repository.dart';
import '../providers/debts_providers.dart';
import 'utils/debts_ui_utils.dart';
import 'widgets/debt_list_tile.dart';
import 'widgets/debts_empty_state.dart';
import 'widgets/debts_header.dart';
import 'widgets/debts_search_bar.dart';
import 'widgets/debts_tab_filter.dart';
import 'widgets/new_debt_sheet/new_debt_sheet.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  DebtsFilterTab _activeTab = DebtsFilterTab.all;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static const double _kLeadingGutter = 56;

  @override
  Widget build(BuildContext context) {
    final debtsAsync = ref.watch(debtsControllerProvider);
    final viewData = debtsAsync.valueOrNull ??
        const DebtsViewData(customers: [], receivables: []);

    final allReceivables = viewData.receivables;
    final counts = _computeCounts(allReceivables);
    final filtered = _applyFilters(allReceivables);
    final outstandingMinor = _sumOutstanding(allReceivables);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.forestDark,
        foregroundColor: Colors.white,
        elevation: 2,
        onPressed: () => _openNewDebtSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New debt',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            stretch: true,
            leadingWidth: _kLeadingGutter,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () {
                if (ModalRoute.of(context)?.canPop ?? false) {
                  context.pop();
                } else {
                  context.go(AppRoute.home.path);
                }
              },
            ),
            actions: [
              IconButton(
                tooltip: 'Customers',
                icon: const Icon(
                  Icons.people_alt_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: () => context.push(AppRoute.customers.path),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: _refresh,
              ),
            ],
            backgroundColor: const Color(0xFF041C0B),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: DebtsHeader(
                leadingContentInset: _kLeadingGutter,
                outstandingMinor: outstandingMinor,
                totalDebtsCount: counts[DebtsFilterTab.all] ?? 0,
                openCount: counts[DebtsFilterTab.open] ?? 0,
                overdueCount: counts[DebtsFilterTab.overdue] ?? 0,
              ),
              title: innerBoxIsScrolled
                  ? const Text(
                      'Debts',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    )
                  : null,
              centerTitle: false,
              titlePadding: const EdgeInsetsDirectional.only(
                start: _kLeadingGutter,
                bottom: 16,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: ColoredBox(
              color: Color(0xFF041C0B),
              child: SizedBox(height: 18),
            ),
          ),
        ],
        body: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: debtsAsync.when(
            loading: () => _LoadingState(refresh: _refresh),
            error: (error, _) => _ErrorState(
              message: userFriendlyError(error),
              onRetry: _refresh,
            ),
            data: (_) => _DataBody(
              filtered: filtered,
              totalReceivables: allReceivables.length,
              counts: counts,
              activeTab: _activeTab,
              query: _query,
              searchCtrl: _searchCtrl,
              onSearchChanged: (value) => setState(() => _query = value),
              onSearchCleared: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
              onTabChanged: (tab) => setState(() => _activeTab = tab),
              onCreateDebt: () => _openNewDebtSheet(context),
              onRefresh: _refresh,
              onTapDebt: (record) {
                final path = AppRoute.debtDetail.path
                    .replaceFirst(':id', record.receivableId);
                context.push(path);
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    await ref.read(debtsControllerProvider.notifier).refreshFromServer();
    if (!mounted) return;
    final err = ref.read(debtsControllerProvider).valueOrNull?.lastSyncError;
    if (err != null && err.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync paused: $err'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _openNewDebtSheet(BuildContext context) async {
    final view = ref.read(debtsControllerProvider).valueOrNull;
    final customers = view?.customers ?? const [];
    await showNewDebtSheet(context, customers: customers);
  }

  Map<DebtsFilterTab, int> _computeCounts(
    List<LocalReceivableRecord> receivables,
  ) {
    var open = 0;
    var overdue = 0;
    var settled = 0;
    for (final r in receivables) {
      switch (r.status) {
        case 'settled':
          settled++;
          break;
        case 'cancelled':
          break;
        default:
          open++;
          if (DebtsUiUtils.isOverdue(r.dueDateIso)) overdue++;
      }
    }
    return {
      // `All` shows everything except cancelled debts; cancelled rows stay
      // accessible from customer detail history but never clutter the
      // active ledger view.
      DebtsFilterTab.all: receivables.length - _countCancelled(receivables),
      DebtsFilterTab.open: open,
      DebtsFilterTab.overdue: overdue,
      DebtsFilterTab.settled: settled,
    };
  }

  int _countCancelled(List<LocalReceivableRecord> receivables) {
    var count = 0;
    for (final r in receivables) {
      if (r.status == 'cancelled') count++;
    }
    return count;
  }

  List<LocalReceivableRecord> _applyFilters(
    List<LocalReceivableRecord> all,
  ) {
    final lowerQuery = _query.trim().toLowerCase();
    return all.where((r) {
      final matchesTab = switch (_activeTab) {
        DebtsFilterTab.all => r.status != 'cancelled',
        DebtsFilterTab.open =>
          r.status == 'open' || r.status == 'partially_paid',
        DebtsFilterTab.overdue =>
          (r.status == 'open' || r.status == 'partially_paid') &&
              DebtsUiUtils.isOverdue(r.dueDateIso),
        DebtsFilterTab.settled => r.status == 'settled',
      };
      if (!matchesTab) return false;

      if (lowerQuery.isEmpty) return true;
      final name = (r.customerName ?? '').toLowerCase();
      if (name.contains(lowerQuery)) return true;
      final invoice = (r.invoiceNumber ?? '').toLowerCase();
      if (invoice.contains(lowerQuery)) return true;
      return false;
    }).toList(growable: false);
  }

  int _sumOutstanding(List<LocalReceivableRecord> all) {
    var total = 0;
    for (final r in all) {
      if (r.status == 'settled' || r.status == 'cancelled') continue;
      total += DebtsUiUtils.amountToMinor(r.outstandingAmount);
    }
    return total;
  }
}

class _DataBody extends StatelessWidget {
  const _DataBody({
    required this.filtered,
    required this.totalReceivables,
    required this.counts,
    required this.activeTab,
    required this.query,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onTabChanged,
    required this.onCreateDebt,
    required this.onRefresh,
    required this.onTapDebt,
  });

  final List<LocalReceivableRecord> filtered;
  final int totalReceivables;
  final Map<DebtsFilterTab, int> counts;
  final DebtsFilterTab activeTab;
  final String query;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<DebtsFilterTab> onTabChanged;
  final VoidCallback onCreateDebt;
  final Future<void> Function() onRefresh;
  final ValueChanged<LocalReceivableRecord> onTapDebt;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.forest,
      child: ColoredBox(
        color: const Color(0xFF041C0B),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: AppRadii.heroRadius),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.surface),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
              children: [
                const StaleBanner(
                  screenKey: 'debts',
                  kvKey: KvCacheRepository.kDebtsTs,
                ),
                const SizedBox(height: 8),
                DebtsSearchBar(
                  controller: searchCtrl,
                  hasQuery: query.isNotEmpty,
                  onChanged: onSearchChanged,
                  onClear: onSearchCleared,
                ),
                const SizedBox(height: 12),
                DebtsTabFilter(
                  activeTab: activeTab,
                  onChanged: onTabChanged,
                  counts: counts,
                ),
                const SizedBox(height: 16),
                if (totalReceivables == 0)
                  DebtsEmptyState(onCreateDebt: onCreateDebt)
                else if (filtered.isEmpty)
                  DebtsEmptyState.filtered(
                    onCreateDebt: onCreateDebt,
                    filterLabel: activeTab.label.toLowerCase(),
                  )
                else
                  ...filtered.map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DebtListTile(
                        record: record,
                        onTap: () => onTapDebt(record),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.refresh});

  final Future<void> Function() refresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: refresh,
      color: AppColors.forest,
      child: ColoredBox(
        color: const Color(0xFF041C0B),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: AppRadii.heroRadius),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.surface),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              children: [
                const StaleBanner(
                  screenKey: 'debts',
                  kvKey: KvCacheRepository.kDebtsTs,
                ),
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
                const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRetry,
      color: AppColors.forest,
      child: ColoredBox(
        color: const Color(0xFF041C0B),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: AppRadii.heroRadius),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.surface),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              children: [
                const StaleBanner(
                  screenKey: 'debts',
                  kvKey: KvCacheRepository.kDebtsTs,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 42,
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.inkSoft),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: onRetry,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
