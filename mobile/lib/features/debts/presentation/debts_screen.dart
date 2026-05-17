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
import 'utils/debts_ui_tokens.dart';
import 'utils/debts_ui_utils.dart';
import 'widgets/debt_list_tile.dart';
import 'widgets/debts_empty_state.dart';
import 'widgets/debts_list_content_shell.dart';
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
    final outstandingMinor =
        DebtsUiUtils.sumPortfolioOutstandingMinor(allReceivables);

    return Scaffold(
      backgroundColor: DebtsUi.pageBackground,
      floatingActionButton: _DebtsFab(onPressed: () => _openNewDebtSheet(context)),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 230,
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
              _GlassIconButton(
                tooltip: 'Customers',
                icon: Icons.person_add_alt_1_rounded,
                onPressed: () => context.push(AppRoute.customers.path),
              ),
              const SizedBox(width: 8),
              _GlassIconButton(
                tooltip: 'Refresh',
                icon: Icons.refresh_rounded,
                onPressed: _refresh,
              ),
              const SizedBox(width: 12),
            ],
            backgroundColor: DebtsUi.greenDeep,
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
                        fontFamily: 'Constantia',
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        letterSpacing: -0.3,
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
              color: DebtsUi.pageBackground,
              child: SizedBox(height: 10),
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
    return DebtsListContentShell(
      onRefresh: onRefresh,
      staleBanner: const StaleBanner(
        screenKey: 'debts',
        kvKey: KvCacheRepository.kDebtsTs,
      ),
      searchBar: DebtsSearchBar(
        controller: searchCtrl,
        hasQuery: query.isNotEmpty,
        onChanged: onSearchChanged,
        onClear: onSearchCleared,
      ),
      tabFilter: DebtsTabFilter(
        activeTab: activeTab,
        onChanged: onTabChanged,
        counts: counts,
      ),
      children: [
        if (totalReceivables == 0)
          DebtsEmptyState(onCreateDebt: onCreateDebt)
        else if (filtered.isEmpty)
          DebtsEmptyState.filtered(
            onCreateDebt: onCreateDebt,
            filterLabel: activeTab.label.toLowerCase(),
          )
        else ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(
              'RECENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: DebtsUi.textMuted,
              ),
            ),
          ),
          ...filtered.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DebtListTile(
                record: record,
                onTap: () => onTapDebt(record),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Rounded-square gradient FAB matching the mockup's `.fab`. Plus icon only,
/// 56x56, with a soft green drop shadow.
class _DebtsFab extends StatelessWidget {
  const _DebtsFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'New debt',
      child: SizedBox(
        width: 56,
        height: 56,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: Container(
              decoration: BoxDecoration(
                gradient: DebtsUi.ctaGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66166B42),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular translucent icon button used in the debts hero header.
/// Matches `index (2).html` `.icon-btn`.
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: Colors.white),
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
      color: DebtsUi.textMuted,
      backgroundColor: DebtsUi.surface,
      child: ColoredBox(
        color: DebtsUi.pageBackground,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: AppRadii.heroRadius),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
            children: [
              const StaleBanner(
                screenKey: 'debts',
                kvKey: KvCacheRepository.kDebtsTs,
              ),
              SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
              const Center(
                child: CircularProgressIndicator(color: DebtsUi.greenMid),
              ),
            ],
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
      color: DebtsUi.textMuted,
      backgroundColor: DebtsUi.surface,
      child: ColoredBox(
        color: DebtsUi.pageBackground,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: AppRadii.heroRadius),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
            children: [
              const StaleBanner(
                screenKey: 'debts',
                kvKey: KvCacheRepository.kDebtsTs,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: DebtsUi.surface,
                  borderRadius: BorderRadius.circular(DebtsUi.radiusLg),
                  border:
                      Border.all(color: DebtsUi.borderNeutral, width: 1.5),
                  boxShadow: DebtsUi.shadowNeutralSm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 42,
                      color: DebtsUi.danger,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: DebtsUi.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: DebtsUi.greenMid,
                      ),
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
    );
  }
}
