import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../data/local/kv_cache_repository.dart';
import '../../../shared/utils/user_friendly_error.dart';
import '../../../shared/widgets/stale_banner.dart';
import '../../debts/data/debts_repository.dart';
import '../../debts/presentation/utils/debts_ui_tokens.dart';
import '../../debts/presentation/utils/debts_ui_utils.dart';
import '../../debts/presentation/widgets/debts_list_content_shell.dart';
import '../../debts/providers/debts_providers.dart';
import 'widgets/add_customer_sheet.dart';
import 'widgets/customer_list_tile.dart';
import 'widgets/customers_empty_state.dart';
import 'widgets/customers_filter_tab.dart';
import 'widgets/customers_header.dart';
import 'widgets/customers_search_bar.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  CustomersFilterTab _activeTab = CustomersFilterTab.all;
  String _query = '';

  static const _kLeadingGutter = 56.0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debtsAsync = ref.watch(debtsControllerProvider);
    final viewData = debtsAsync.valueOrNull;
    final customers = viewData?.customers ?? const <LocalDebtCustomer>[];
    final receivables = viewData?.receivables ?? const <LocalReceivableRecord>[];

    final outstandingMinor =
        DebtsUiUtils.sumPortfolioOutstandingMinor(receivables);
    final clearedCount = customers
        .where((c) => DebtsUiUtils.amountToMinor(c.totalOutstanding) == 0)
        .length;
    final withDebtCount = customers.length - clearedCount;

    final counts = {
      CustomersFilterTab.all: customers.length,
      CustomersFilterTab.withBalance: withDebtCount,
      CustomersFilterTab.cleared: clearedCount,
    };

    final filtered = _applyFilters(customers);

    return Scaffold(
      backgroundColor: DebtsUi.pageBackground,
      floatingActionButton: _CustomersFab(
        onPressed: () => showAddCustomerSheet(context),
      ),
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
              background: CustomersHeader(
                leadingContentInset: _kLeadingGutter,
                outstandingMinor: outstandingMinor,
                customerCount: customers.length,
                clearedCount: clearedCount,
                withDebtCount: withDebtCount,
              ),
              title: innerBoxIsScrolled
                  ? const Text(
                      'Customers',
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
            loading: () => _LoadingState(onRefresh: _refresh),
            error: (e, _) => _ErrorState(
              message: userFriendlyError(e),
              onRetry: _refresh,
            ),
            data: (_) => _DataBody(
              filtered: filtered,
              totalCustomers: customers.length,
              counts: counts,
              activeTab: _activeTab,
              query: _query,
              searchCtrl: _searchCtrl,
              onSearchChanged: (v) => setState(() => _query = v),
              onSearchCleared: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
              onTabChanged: (tab) => setState(() => _activeTab = tab),
              onAddCustomer: () => showAddCustomerSheet(context),
              onRefresh: _refresh,
              onTapCustomer: (c) =>
                  context.push('/customers/${c.customerId}'),
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

  List<LocalDebtCustomer> _applyFilters(List<LocalDebtCustomer> all) {
    final lower = _query.trim().toLowerCase();
    return all.where((c) {
      final minor = DebtsUiUtils.amountToMinor(c.totalOutstanding);
      final matchesTab = switch (_activeTab) {
        CustomersFilterTab.all => true,
        CustomersFilterTab.withBalance => minor > 0,
        CustomersFilterTab.cleared => minor == 0,
      };
      if (!matchesTab) return false;
      if (lower.isEmpty) return true;
      if (c.name.toLowerCase().contains(lower)) return true;
      final phone = c.phoneNumber;
      if (phone != null && phone.toLowerCase().contains(lower)) return true;
      return false;
    }).toList(growable: false);
  }
}

class _DataBody extends StatelessWidget {
  const _DataBody({
    required this.filtered,
    required this.totalCustomers,
    required this.counts,
    required this.activeTab,
    required this.query,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onTabChanged,
    required this.onAddCustomer,
    required this.onRefresh,
    required this.onTapCustomer,
  });

  final List<LocalDebtCustomer> filtered;
  final int totalCustomers;
  final Map<CustomersFilterTab, int> counts;
  final CustomersFilterTab activeTab;
  final String query;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<CustomersFilterTab> onTabChanged;
  final VoidCallback onAddCustomer;
  final Future<void> Function() onRefresh;
  final ValueChanged<LocalDebtCustomer> onTapCustomer;

  @override
  Widget build(BuildContext context) {
    return DebtsListContentShell(
      onRefresh: onRefresh,
      staleBanner: const StaleBanner(
        screenKey: 'customers',
        kvKey: KvCacheRepository.kDebtsTs,
      ),
      searchBar: CustomersSearchBar(
        controller: searchCtrl,
        hasQuery: query.isNotEmpty,
        onChanged: onSearchChanged,
        onClear: onSearchCleared,
      ),
      tabFilter: CustomersTabFilter(
        activeTab: activeTab,
        onChanged: onTabChanged,
        counts: counts,
      ),
      children: [
        if (totalCustomers == 0)
          CustomersEmptyState(onAddCustomer: onAddCustomer)
        else if (filtered.isEmpty)
          CustomersEmptyState.filtered(
            onAddCustomer: onAddCustomer,
            filterLabel: activeTab.label.toLowerCase(),
          )
        else ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(
              'YOUR CUSTOMERS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: DebtsUi.textMuted,
              ),
            ),
          ),
          ...filtered.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CustomerListTile(
                customer: c,
                onTap: () => onTapCustomer(c),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CustomersFab extends StatelessWidget {
  const _CustomersFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add customer',
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
                Icons.person_add_alt_1_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
  const _LoadingState({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
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
                screenKey: 'customers',
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
                screenKey: 'customers',
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
