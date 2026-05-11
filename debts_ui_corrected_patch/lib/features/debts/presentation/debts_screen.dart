import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../data/local/kv_cache_repository.dart';
import '../../../shared/utils/user_friendly_error.dart';
import '../../../shared/widgets/stale_banner.dart';
import 'utils/debts_ui_tokens.dart';
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
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
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
                        // ── Quick Actions panel ──────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(
                                DebtTokens.panelRadius),
                            border: Border.all(color: AppColors.border),
                            boxShadow: DebtTokens.panel,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quick Actions',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _QuickActionsRow(
                                onNewDebt: _openNewDebtSheet,
                                onViewReports: () =>
                                    context.push(AppRoute.reports.path),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Text(
                              'Debts',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(DebtTokens.debtCardRadius),
          border: Border.all(color: AppColors.border),
          boxShadow: DebtTokens.card,
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
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
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + due date + invoice
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
                          ? DebtTokens.danger
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
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: status == 'overdue' ? DebtTokens.danger : AppColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(DebtTokens.pillRadius),
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
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.muted.withValues(alpha: 0.5), size: 18),
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
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
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
    final isPrimary = backgroundColor == AppColors.forest;
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(DebtTokens.buttonRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DebtTokens.buttonRadius),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DebtTokens.buttonRadius),
            border: Border.all(
              color: isPrimary
                  ? AppColors.forestDark
                  : AppColors.border,
            ),
            boxShadow: isPrimary ? AppShadows.card : DebtTokens.card,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foregroundColor, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
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

  final _customerFormKey = GlobalKey<FormState>();
  final _debtFormKey = GlobalKey<FormState>();

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

  String? _validateCustomerName(String? value) {
    if (_selectedCustomerId != null) return null;
    final raw = value?.trim() ?? '';
    if (raw.length < 2) return 'Enter at least 2 characters for the customer name.';
    return null;
  }

  String? _validateAmount(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Enter the amount owed.';
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      return 'Enter a valid amount greater than 0.';
    }
    return null;
  }

  void _continueToDebtDetails() {
    if (!(_customerFormKey.currentState?.validate() ?? false)) return;
    if (!_canContinue) return;
    setState(() => _step = 1);
  }

  Future<void> _save() async {
    if (!(_debtFormKey.currentState?.validate() ?? false)) return;
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
    final size = MediaQuery.sizeOf(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewBottom),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            constraints: BoxConstraints(maxHeight: size.height * 0.92),
            decoration: const BoxDecoration(
              color: DebtTokens.sheetSurface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(DebtTokens.sheetTopRadius),
              ),
              boxShadow: DebtTokens.sheet,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 46,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7DDD9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  _DebtSheetHeader(
                    icon: _step == 0
                        ? Icons.person_search_rounded
                        : Icons.receipt_long_rounded,
                    title: _step == 0 ? 'New Customer Debt' : 'Debt Details',
                    subtitle: _step == 0
                        ? 'Select an existing customer or create a new one.'
                        : 'Enter the amount owed and optional due date.',
                    onClose: _saving ? null : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 18),
                  _StepIndicator(currentStep: _step),
                  const SizedBox(height: 18),
                  if (_step == 0) _buildStep0() else _buildStep1(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep0() {
    final matches = _filteredCustomers;
    final searchText = _searchCtrl.text.trim();
    final showNewOption = _selectedCustomerId == null &&
        searchText.length >= 2 &&
        !matches.any((c) => c.name.toLowerCase() == searchText.toLowerCase());

    return Form(
      key: _customerFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _searchCtrl,
            autofocus: true,
            validator: _validateCustomerName,
            onChanged: (_) => setState(() {
              _selectedCustomerId = null;
              _selectedCustomerName = null;
            }),
            decoration: _debtInputDecoration(
              label: 'Customer name',
              hint: 'Search or enter customer name',
              icon: Icons.search_rounded,
            ),
          ),
          const SizedBox(height: 12),
          if (showNewOption) ...[
            _NewCustomerPreview(name: searchText),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _debtInputDecoration(
                label: 'Phone number (optional)',
                hint: 'e.g. 024 000 0000',
                icon: Icons.phone_outlined,
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (matches.isNotEmpty) ...[
            const Text(
              'Existing Customers',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: DebtTokens.sheetCanvas,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: DebtTokens.fieldBorder),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 230),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: matches.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFE8EEE9)),
                  itemBuilder: (_, idx) {
                    final c = matches[idx];
                    final isSelected = _selectedCustomerId == c.customerId;
                    return _CustomerPickTile(
                      customer: c,
                      selected: isSelected,
                      onTap: () => _onCustomerTap(c),
                    );
                  },
                ),
              ),
            ),
          ] else if (!showNewOption) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DebtTokens.sheetCanvas,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: DebtTokens.fieldBorder),
              ),
              child: const Text(
                'Type a customer name above to create a new customer debt.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _canContinue ? _continueToDebtDetails : null,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text(
                'Continue',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DebtTokens.buttonRadius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    final customerLabel = _selectedCustomerName ?? _searchCtrl.text.trim();

    return Form(
      key: _debtFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SelectedCustomerReceipt(
            name: customerLabel,
            isNewCustomer: _selectedCustomerId == null,
            onEdit: _saving ? null : () => setState(() => _step = 0),
          ),
          const SizedBox(height: 16),
          const Text(
            'Debt Information',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            validator: _validateAmount,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
            decoration: _debtInputDecoration(
              label: 'Amount owed',
              hint: '0.00',
              icon: Icons.payments_outlined,
              prefixText: '₵ ',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _dueDateCtrl,
            readOnly: true,
            onTap: _saving ? null : _pickDueDate,
            decoration: _debtInputDecoration(
              label: 'Due date (optional)',
              hint: 'Select due date',
              icon: Icons.calendar_month_outlined,
              suffixIcon: _dueDateCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _dueDateCtrl.clear()),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteCtrl,
            maxLines: 3,
            minLines: 2,
            textInputAction: TextInputAction.newline,
            decoration: _debtInputDecoration(
              label: 'Note (optional)',
              hint: 'Add what this debt is for',
              icon: Icons.notes_rounded,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => setState(() => _step = 0),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(DebtTokens.buttonRadius),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
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
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    _saving ? 'Creating...' : 'Create Debt',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(DebtTokens.buttonRadius),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DebtSheetHeader extends StatelessWidget {
  const _DebtSheetHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.forest.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.forest, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
          color: AppColors.muted,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StepPill(label: 'Customer', active: currentStep == 0)),
        const SizedBox(width: 8),
        Expanded(child: _StepPill(label: 'Debt', active: currentStep == 1)),
      ],
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? AppColors.forest.withValues(alpha: 0.10)
            : DebtTokens.sheetCanvas,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? AppColors.forest : DebtTokens.fieldBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? AppColors.forest : AppColors.muted,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CustomerPickTile extends StatelessWidget {
  const _CustomerPickTile({
    required this.customer,
    required this.selected,
    required this.onTap,
  });

  final LocalDebtCustomer customer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?';
    return Material(
      color: selected ? AppColors.forest.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected ? AppColors.forest : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.forest : DebtTokens.fieldBorder,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.forest,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.phoneNumber?.isNotEmpty == true
                          ? customer.phoneNumber!
                          : 'No phone number',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.forest, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewCustomerPreview extends StatelessWidget {
  const _NewCustomerPreview({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.forest.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.forest.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_add_rounded,
                color: AppColors.forest, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create new customer',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedCustomerReceipt extends StatelessWidget {
  const _SelectedCustomerReceipt({
    required this.name,
    required this.isNewCustomer,
    required this.onEdit,
  });

  final String name;
  final bool isNewCustomer;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DebtTokens.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DebtTokens.paperEdge),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_rounded,
                color: AppColors.forest, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNewCustomer ? 'New Customer' : 'Selected Customer',
                  style: const TextStyle(
                    color: DebtTokens.paperMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded, size: 15),
            label: const Text('Change'),
            style: TextButton.styleFrom(foregroundColor: AppColors.forest),
          ),
        ],
      ),
    );
  }
}

InputDecoration _debtInputDecoration({
  required String label,
  required String hint,
  required IconData icon,
  String? prefixText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefixText,
    prefixStyle: const TextStyle(
      color: AppColors.ink,
      fontSize: 18,
      fontWeight: FontWeight.w900,
    ),
    prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: DebtTokens.fieldSurface,
    errorMaxLines: 2,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DebtTokens.fieldRadius),
      borderSide: const BorderSide(color: DebtTokens.fieldBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DebtTokens.fieldRadius),
      borderSide: const BorderSide(color: DebtTokens.fieldBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DebtTokens.fieldRadius),
      borderSide: const BorderSide(color: AppColors.forest, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DebtTokens.fieldRadius),
      borderSide: const BorderSide(color: DebtTokens.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DebtTokens.fieldRadius),
      borderSide: const BorderSide(color: DebtTokens.danger, width: 1.4),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}
