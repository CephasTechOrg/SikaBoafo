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
import 'widgets/customers_header.dart';
import 'widgets/customers_search_bar.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debtsAsync = ref.watch(debtsControllerProvider);
    final viewData   = debtsAsync.valueOrNull;
    final customers  = viewData?.customers ?? const <LocalDebtCustomer>[];

    final withDebtCount = customers
        .where((c) => DebtsUiUtils.amountToMinor(c.totalOutstanding) > 0)
        .length;
    final filtered = _applyFilters(customers);

    void doBack() {
      if (ModalRoute.of(context)?.canPop ?? false) {
        context.pop();
      } else {
        context.go(AppRoute.home.path);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 218,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: DebtsUi.greenDeep,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: CustomersHeader(
                customerCount: customers.length,
                withDebtCount: withDebtCount,
                activeCount: customers.length,
                onBack: doBack,
                onAdd: () => showAddCustomerSheet(context),
              ),
              title: innerBoxIsScrolled
                  ? const Text(
                      'Customers',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.2,
                      ),
                    )
                  : null,
              centerTitle: false,
              titlePadding: const EdgeInsetsDirectional.only(
                start: 20,
                bottom: 16,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: ColoredBox(
              color: DebtsUi.greenDeep,
              child: SizedBox(height: 0),
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
              query: _query,
              searchCtrl: _searchCtrl,
              onSearchChanged: (v) => setState(() => _query = v),
              onSearchCleared: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
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
    await ref
        .read(debtsControllerProvider.notifier)
        .refreshFromServer(userInitiated: true);
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
    if (lower.isEmpty) return all;
    return all.where((c) {
      if (c.name.toLowerCase().contains(lower)) return true;
      final phone = c.phoneNumber;
      return phone != null && phone.toLowerCase().contains(lower);
    }).toList(growable: false);
  }
}

class _DataBody extends StatelessWidget {
  const _DataBody({
    required this.filtered,
    required this.totalCustomers,
    required this.query,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onAddCustomer,
    required this.onRefresh,
    required this.onTapCustomer,
  });

  final List<LocalDebtCustomer> filtered;
  final int totalCustomers;
  final String query;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onAddCustomer;
  final Future<void> Function() onRefresh;
  final ValueChanged<LocalDebtCustomer> onTapCustomer;

  @override
  Widget build(BuildContext context) {
    return DebtsListContentShell(
      onRefresh: onRefresh,
      staleBannerTopPadding: 0,
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
      tabFilter: null,
      children: [
        if (totalCustomers == 0)
          CustomersEmptyState(onAddCustomer: onAddCustomer)
        else if (filtered.isEmpty)
          CustomersEmptyState.filtered(
            onAddCustomer: onAddCustomer,
            filterLabel: 'customer',
          )
        else ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'ALL CUSTOMERS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: Color(0xFF9AA3AF),
              ),
            ),
          ),
          ...filtered.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
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
