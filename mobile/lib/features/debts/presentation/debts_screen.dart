import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../data/local/kv_cache_repository.dart';
import '../../../shared/utils/user_friendly_error.dart';
import '../../../shared/widgets/stale_banner.dart';
import 'utils/debts_ui_utils.dart';
import 'widgets/debts_empty_state.dart';
import 'widgets/debts_header.dart';
import 'widgets/debts_search_bar.dart';
import 'widgets/debts_tab_filter.dart';
import '../data/debts_repository.dart';
import '../providers/debts_providers.dart';

// ── Screen ─────────────────────────────────────────────────────────────────

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  String _searchQuery = '';
  bool _showSearch = false;
  bool _showAll = false;
  String _activeTab = 'all';

  @override
  Widget build(BuildContext context) {
    final debtsAsync = ref.watch(debtsControllerProvider);
    final viewData = debtsAsync.valueOrNull;
    final customers = viewData?.customers ?? const <LocalDebtCustomer>[];
    final receivables =
        viewData?.receivables ?? const <LocalReceivableRecord>[];
    final paidThisMonth = viewData?.paidThisMonth ?? '0.00';

    int outstandingMinor = 0;
    int overdueMinor = 0;
    for (final r in receivables) {
      if (r.status != 'open' && r.status != 'partially_paid') continue;
      final m = DebtsUiUtils.moneyToMinor(r.outstandingAmount);
      outstandingMinor += m;
      if (DebtsUiUtils.receivableStatus(r) == 'overdue') overdueMinor += m;
    }

    final searched = _searchQuery.isEmpty
        ? receivables
        : receivables
            .where((r) => r.customerName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
            .toList(growable: false);

    final filtered = _filterByTab(searched);

    const kLeadingGutter = 56.0;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            stretch: true,
            leadingWidth: kLeadingGutter,
            leading: IconButton(
              onPressed: () => context.go(AppRoute.home.path),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
            ),
            backgroundColor: const Color(0xFF041C0B),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: DebtsHeader(
                leadingContentInset: kLeadingGutter,
                outstandingMinor: outstandingMinor,
                overdueMinor: overdueMinor,
                paidThisMonthStr: paidThisMonth,
                customerCount: customers.length,
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
                start: kLeadingGutter,
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
            loading: () => RefreshIndicator(
              onRefresh: () =>
                  ref.read(debtsControllerProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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
            error: (e, _) => RefreshIndicator(
              onRefresh: () =>
                  ref.read(debtsControllerProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  const StaleBanner(
                    screenKey: 'debts',
                    kvKey: KvCacheRepository.kDebtsTs,
                  ),
                  const SizedBox(height: 24),
                  Text(userFriendlyError(e), textAlign: TextAlign.center),
                ],
              ),
            ),
            data: (_) => RefreshIndicator(
              onRefresh: () =>
                  ref.read(debtsControllerProvider.notifier).refresh(),
              child: ColoredBox(
                color: const Color(0xFF041C0B),
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: AppRadii.heroRadius),
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
                        const SizedBox(height: 10),
                        if (_showSearch) ...[
                          DebtsSearchBar(
                            onChanged: (v) =>
                                setState(() => _searchQuery = v.trim()),
                            onClear: () => setState(() {
                              _searchQuery = '';
                              _showSearch = false;
                            }),
                          ),
                          const SizedBox(height: 16),
                        ],
                        const SizedBox(height: 4),
                        const Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _QuickActionsRow(
                          onNewDebt: _openNewDebtSheet,
                          onViewReports: () =>
                              context.push(AppRoute.reports.path),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Text(
                              'Debts',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const Spacer(),
                            if (receivables.isNotEmpty) ...[
                              IconButton(
                                onPressed: () => setState(
                                    () => _showSearch = !_showSearch),
                                icon: Icon(
                                  _showSearch
                                      ? Icons.search_off_rounded
                                      : Icons.search_rounded,
                                  color: AppColors.muted,
                                  size: 20,
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              if (!_showAll && filtered.length > 10)
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _showAll = true),
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Text(
                                      'View all →',
                                      style: TextStyle(
                                        color: AppColors.forest,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        DebtsTabFilter(
                          activeTab: _activeTab,
                          onTabChanged: (t) => setState(() {
                            _activeTab = t;
                            _showAll = false;
                          }),
                        ),
                        const SizedBox(height: 12),
                        if (debtsAsync.isLoading && receivables.isEmpty)
                          const Center(child: CircularProgressIndicator())
                        else if (filtered.isEmpty)
                          DebtsEmptyState(
                            hasSearch: _searchQuery.isNotEmpty,
                            activeTab: _activeTab,
                          )
                        else
                          ...filtered
                              .take(!_showAll && _searchQuery.isEmpty && _activeTab == 'all'
                                  ? 10
                                  : filtered.length)
                              .map(_buildDebtCard),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDebtCard(LocalReceivableRecord row) {
    final status = DebtsUiUtils.receivableStatus(row);
    final (statusLabel, statusColor, avatarBg) = switch (status) {
      'overdue' => ('Overdue', AppColors.danger, AppColors.dangerSoft),
      'due_soon' => ('Due Soon', AppColors.warning, AppColors.warningSoft),
      'settled' => ('Settled', AppColors.success, AppColors.successSoft),
      'cancelled' => ('Cancelled', AppColors.muted, AppColors.surfaceAlt),
      'partially_paid' => ('Partial', AppColors.warning, AppColors.warningSoft),
      _ => ('Open', AppColors.info, AppColors.infoSoft),
    };

    final initials = row.customerName.trim().isEmpty
        ? '?'
        : row.customerName
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w[0])
            .join()
            .toUpperCase();

    final dueLabel = row.dueDateIso != null && row.dueDateIso!.isNotEmpty
        ? 'Due ${DebtsUiUtils.fmtDueDate(row.dueDateIso)}'
        : 'No due date';

    return GestureDetector(
      onTap: () => _openDebtDetail(row.receivableId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.subtle,
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: avatarBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + due date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dueLabel,
                    style: TextStyle(
                      color: status == 'overdue'
                          ? AppColors.danger
                          : AppColors.muted,
                      fontSize: 12,
                      fontWeight: status == 'overdue'
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (row.invoiceNumber != null &&
                      row.invoiceNumber!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      row.invoiceNumber!,
                      style: const TextStyle(
                        color: AppColors.mutedSoft,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Amount + status pill
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₵${DebtsUiUtils.fmtAmount(row.outstandingAmount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<void> _openDebtDetail(String receivableId) async {
    await context.push('/debts/$receivableId');
    if (!mounted) return;
    ref.invalidate(receivableDetailProvider(receivableId));
    await ref.read(debtsControllerProvider.notifier).refresh();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<LocalReceivableRecord> _filterByTab(
      List<LocalReceivableRecord> records) {
    return switch (_activeTab) {
      'overdue' =>
        records.where((r) => DebtsUiUtils.receivableStatus(r) == 'overdue').toList(),
      'partial' =>
        records.where((r) => r.status == 'partially_paid').toList(),
      'settled' => records.where((r) => r.status == 'settled').toList(),
      _ => records,
    };
  }

  Future<void> _openNewDebtSheet() async {
    final customers =
        ref.read(debtsControllerProvider).valueOrNull?.customers ??
            const <LocalDebtCustomer>[];
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _NewDebtSheet(customers: customers),
    );
    if (saved != true || !mounted) return;
    _showMessage('Debt created.');
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ── Quick actions row ───────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onNewDebt,
    required this.onViewReports,
  });

  final VoidCallback onNewDebt;
  final VoidCallback onViewReports;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickTile(
            icon: Icons.add_card_rounded,
            label: 'New Debt',
            backgroundColor: AppColors.forest,
            foregroundColor: Colors.white,
            onTap: onNewDebt,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickTile(
            icon: Icons.bar_chart_rounded,
            label: 'Reports',
            backgroundColor: AppColors.surfaceAlt,
            foregroundColor: AppColors.inkSoft,
            onTap: onViewReports,
          ),
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: backgroundColor == AppColors.surfaceAlt
                  ? AppColors.border
                  : backgroundColor.withValues(alpha: 0.14),
            ),
            boxShadow: backgroundColor == AppColors.surfaceAlt
                ? AppShadows.subtle
                : AppShadows.card,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foregroundColor, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── New Debt bottom sheet ───────────────────────────────────────────────────

class _NewDebtSheet extends ConsumerStatefulWidget {
  const _NewDebtSheet({required this.customers});
  final List<LocalDebtCustomer> customers;

  @override
  ConsumerState<_NewDebtSheet> createState() => _NewDebtSheetState();
}

class _NewDebtSheetState extends ConsumerState<_NewDebtSheet> {
  int _step = 0;

  final _searchCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _selectedCustomerId;
  String? _selectedCustomerName;

  final _amountCtrl = TextEditingController();
  final _dueDateCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    _dueDateCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  List<LocalDebtCustomer> get _filteredCustomers {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return widget.customers;
    return widget.customers
        .where((c) => c.name.toLowerCase().contains(q))
        .toList();
  }

  bool get _canContinue =>
      _selectedCustomerId != null || _searchCtrl.text.trim().length >= 2;

  void _onCustomerTap(LocalDebtCustomer c) {
    setState(() {
      _selectedCustomerId = c.customerId;
      _selectedCustomerName = c.name;
      _searchCtrl.text = c.name;
    });
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    _dueDateCtrl.text =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() {});
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(debtsRepositoryProvider);
      final String customerId;
      if (_selectedCustomerId != null) {
        customerId = _selectedCustomerId!;
      } else {
        customerId = await repo.createCustomerLocal(
          name: _searchCtrl.text.trim(),
          phoneNumber: _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
        );
      }
      await repo.createReceivableLocal(
        customerId: customerId,
        originalAmount: _amountCtrl.text.trim(),
        dueDateIso: _dueDateCtrl.text.isEmpty ? null : _dueDateCtrl.text,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      await ref.read(debtsControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFriendlyError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewBottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + viewBottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.forest.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_card_rounded,
                      color: AppColors.forest,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _step == 0 ? 'Select Customer' : 'Debt Details',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.muted,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_step == 0) _buildStep0() else _buildStep1(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep0() {
    final matches = _filteredCustomers;
    final showNewOption = _selectedCustomerId == null &&
        _searchCtrl.text.trim().length >= 2 &&
        matches.isEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          autofocus: true,
          onChanged: (_) => setState(() {
            _selectedCustomerId = null;
            _selectedCustomerName = null;
          }),
          decoration: InputDecoration(
            hintText: 'Search or enter a customer name…',
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.muted,
              size: 20,
            ),
            filled: true,
            fillColor: AppColors.canvas,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.borderStrong),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.borderStrong),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide:
                  const BorderSide(color: AppColors.forest, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        const SizedBox(height: 10),
        if (matches.isNotEmpty) ...[
          const Text(
            'Existing customers',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: matches.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (_, idx) {
                  final c = matches[idx];
                  final isSelected = _selectedCustomerId == c.customerId;
                  return InkWell(
                    onTap: () => _onCustomerTap(c),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.forest
                                  : AppColors.canvas,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              c.name.isNotEmpty
                                  ? c.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.forest,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              c.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.forest,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ] else if (showNewOption) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border:
                  Border.all(color: AppColors.forest.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.forest.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_rounded,
                      color: AppColors.forest, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New customer',
                        style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _searchCtrl.text.trim(),
                        style: const TextStyle(
                          color: AppColors.forest,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone number (optional)',
              prefixIcon: const Icon(
                Icons.phone_outlined,
                color: AppColors.muted,
                size: 20,
              ),
              filled: true,
              fillColor: AppColors.canvas,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: const BorderSide(color: AppColors.borderStrong),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: const BorderSide(color: AppColors.borderStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide:
                    const BorderSide(color: AppColors.forest, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ] else if (widget.customers.isEmpty) ...[
          const SizedBox(height: 4),
          const Text(
            'Type a name above to add a new customer.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _canContinue ? () => setState(() => _step = 1) : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forest,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    final customerLabel =
        _selectedCustomerName ?? _searchCtrl.text.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _step = 0),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.forest.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.person_rounded,
                  color: AppColors.forest,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  customerLabel,
                  style: const TextStyle(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.edit_rounded,
                  color: AppColors.forest,
                  size: 13,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Amount owed',
            hintText: '0.00',
            prefixText: '₵ ',
            prefixIcon: const Icon(
              Icons.attach_money_rounded,
              color: AppColors.muted,
              size: 20,
            ),
            filled: true,
            fillColor: AppColors.canvas,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.borderStrong),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.borderStrong),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide:
                  const BorderSide(color: AppColors.forest, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _dueDateCtrl,
          readOnly: true,
          onTap: _pickDueDate,
          decoration: InputDecoration(
            labelText: 'Due date (optional)',
            prefixIcon: const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.muted,
              size: 20,
            ),
            filled: true,
            fillColor: AppColors.canvas,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.borderStrong),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.borderStrong),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide:
                  const BorderSide(color: AppColors.forest, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _noteCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Note (optional)',
            prefixIcon: const Icon(
              Icons.notes_rounded,
              color: AppColors.muted,
              size: 20,
            ),
            filled: true,
            fillColor: AppColors.canvas,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.borderStrong),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.borderStrong),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide:
                  const BorderSide(color: AppColors.forest, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.receipt_long_rounded, size: 18),
            label: const Text(
              'Create Debt',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forest,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
