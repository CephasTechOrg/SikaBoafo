import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../data/debts_repository.dart';
import '../providers/debts_providers.dart';

// O(n) YYYY-MM-DD lexicographic comparison — no DateTime.parse needed.
String _receivableStatus(LocalReceivableRecord r) {
  if (r.status == 'settled') return 'settled';
  if (r.status == 'cancelled') return 'cancelled';
  final d = r.dueDateIso;
  if (d != null && d.isNotEmpty) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final soon = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().add(const Duration(days: 7)));
    if (d.compareTo(today) < 0) return 'overdue';
    if (d.compareTo(soon) <= 0) return 'due_soon';
  }
  return r.status == 'partially_paid' ? 'partially_paid' : 'open';
}

int _moneyToMinorLocal(String value) {
  final raw = value.trim();
  final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
  if (match == null) return 0;
  final parts = raw.split('.');
  final major = int.parse(parts[0]);
  final dec = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
  return (major * 100) + int.parse(dec);
}

String _minorToMoneyLocal(int v) {
  final major = v ~/ 100;
  final minor = (v % 100).toString().padLeft(2, '0');
  return '$major.$minor';
}

// ── Screen ─────────────────────────────────────────────────────────────────

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key, this.onNavigate});
  final ValueChanged<int>? onNavigate;

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _dueDateCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _repaymentAmountCtrl = TextEditingController();

  bool _showAddCustomer = false;
  bool _showCreateDebt = false;
  bool _showRecordPayment = false;
  String? _selectedCustomerId;
  String? _selectedReceivableId;
  String _repaymentMethod = 'cash';
  String _searchQuery = '';
  bool _showSearch = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    _dueDateCtrl.dispose();
    _noteCtrl.dispose();
    _repaymentAmountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debtsAsync = ref.watch(debtsControllerProvider);
    final viewData = debtsAsync.valueOrNull;
    final customers = viewData?.customers ?? const <LocalDebtCustomer>[];
    final receivables =
        viewData?.receivables ?? const <LocalReceivableRecord>[];
    final paidThisMonth = viewData?.paidThisMonth ?? '0.00';
    final isBusy = debtsAsync.isLoading;

    int outstandingMinor = 0;
    int overdueMinor = 0;
    for (final r in receivables) {
      if (r.status != 'open' && r.status != 'partially_paid') continue;
      final m = _moneyToMinorLocal(r.outstandingAmount);
      outstandingMinor += m;
      if (_receivableStatus(r) == 'overdue') overdueMinor += m;
    }

    final selectedCustomerId = _resolveSelectedCustomer(customers);

    final filtered = _searchQuery.isEmpty
        ? receivables
        : receivables
            .where((r) => r.customerName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
            .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.shell),
        child: Column(
          children: [
            // ── Hero header ───────────────────────────────────────────────
            _buildHeader(
              outstandingMinor: outstandingMinor,
              overdueMinor: overdueMinor,
              paidThisMonth: paidThisMonth,
              customerCount: customers.length,
            ),

            // ── Content canvas ────────────────────────────────────────────
            Expanded(
              child: PremiumSurface(
                child: debtsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(e.toString(), textAlign: TextAlign.center),
                    ),
                  ),
                  data: (_) => RefreshIndicator(
                    onRefresh: () =>
                        ref.read(debtsControllerProvider.notifier).refresh(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                      children: [
                        // Search bar
                        if (_showSearch) ...[
                          _SearchBar(
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

                        // Quick actions label
                        const Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Quick actions row
                        _QuickActionsRow(
                          onAddCustomer: () => setState(() {
                            _showAddCustomer = !_showAddCustomer;
                            if (_showAddCustomer) _showCreateDebt = false;
                          }),
                          onCreateDebt: () => setState(() {
                            _showCreateDebt = !_showCreateDebt;
                            if (_showCreateDebt) _showAddCustomer = false;
                          }),
                          onRecordPayment: () => setState(() {
                            _showRecordPayment = !_showRecordPayment;
                            if (_showRecordPayment) {
                              _showAddCustomer = false;
                              _showCreateDebt = false;
                            }
                          }),
                          onViewReports: () => widget.onNavigate?.call(5),
                        ),
                        const SizedBox(height: 22),

                        // Action sections (grouped list card)
                        _ActionSectionsList(
                          showAddCustomer: _showAddCustomer,
                          showCreateDebt: _showCreateDebt,
                          showRecordPayment: _showRecordPayment,
                          onToggleAddCustomer: () => setState(
                              () => _showAddCustomer = !_showAddCustomer),
                          onToggleCreateDebt: () => setState(
                              () => _showCreateDebt = !_showCreateDebt),
                          onToggleRecordPayment: () => setState(
                              () => _showRecordPayment = !_showRecordPayment),
                          onViewReports: () => widget.onNavigate?.call(5),
                          addCustomerForm: _AddCustomerForm(
                            nameCtrl: _nameCtrl,
                            phoneCtrl: _phoneCtrl,
                            isBusy: isBusy,
                            onSave: _saveCustomer,
                          ),
                          createDebtForm: _CreateDebtForm(
                            customers: customers,
                            selectedCustomerId: selectedCustomerId,
                            amountCtrl: _amountCtrl,
                            dueDateCtrl: _dueDateCtrl,
                            noteCtrl: _noteCtrl,
                            isBusy: isBusy,
                            onCustomerChanged: (v) =>
                                setState(() => _selectedCustomerId = v),
                            onPickDate: _pickDueDate,
                            onSave: () => _saveDebt(
                                selectedCustomerId: selectedCustomerId),
                          ),
                          recordPaymentForm: _RecordPaymentForm(
                            openReceivables: receivables
                                .where((r) =>
                                    r.status == 'open' ||
                                    r.status == 'partially_paid')
                                .toList(growable: false),
                            selectedReceivableId: _resolveSelectedReceivable(
                              receivables
                                  .where((r) =>
                                      r.status == 'open' ||
                                      r.status == 'partially_paid')
                                  .toList(growable: false),
                            ),
                            amountCtrl: _repaymentAmountCtrl,
                            paymentMethod: _repaymentMethod,
                            isBusy: isBusy,
                            onReceivableChanged: (v) =>
                                setState(() => _selectedReceivableId = v),
                            onMethodChanged: (v) =>
                                setState(() => _repaymentMethod = v),
                            onSave: _saveRepayment,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Recent debts header
                        Row(
                          children: [
                            const Text(
                              'Recent Debts',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const Spacer(),
                            if (receivables.isNotEmpty)
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _showSearch = !_showSearch),
                                child: const Text(
                                  'View all →',
                                  style: TextStyle(
                                    color: AppColors.forest,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (debtsAsync.isLoading && receivables.isEmpty)
                          const Center(child: CircularProgressIndicator())
                        else if (filtered.isEmpty)
                          _EmptyDebts(hasSearch: _searchQuery.isNotEmpty)
                        else
                          ...filtered
                              .take(_searchQuery.isEmpty ? 10 : filtered.length)
                              .map(_buildDebtCard),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader({
    required int outstandingMinor,
    required int overdueMinor,
    required String paidThisMonth,
    required int customerCount,
  }) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.hero),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Debts',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Track customers, due dates, and repayments',
                          style: TextStyle(
                            color: AppColors.heroSubtitle,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Outstanding',
                            style: TextStyle(
                              color: AppColors.heroSubtitle,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '\u20B5${_minorToMoneyLocal(outstandingMinor)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Constantia',
                              letterSpacing: -0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildHeroChip(
                    label: '\u20B5${_minorToMoneyLocal(overdueMinor)}',
                    value: 'Overdue',
                    tone: overdueMinor > 0
                        ? const Color(0xFFF6A6A6)
                        : Colors.white.withValues(alpha: 0.72),
                  ),
                  const SizedBox(width: 8),
                  _buildHeroChip(
                    label: '\u20B5$paidThisMonth',
                    value: 'Collected',
                    tone: const Color(0xFF9AE7BF),
                  ),
                  const SizedBox(width: 8),
                  _buildHeroChip(
                    label: '$customerCount',
                    value: 'Customers',
                    tone: AppColors.gold,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Debt card ────────────────────────────────────────────────────────────

  Widget _buildHeroChip({
    required String label,
    required String value,
    required Color tone,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tone,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtCard(LocalReceivableRecord row) {
    final status = _receivableStatus(row);
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
        ? 'Due ${row.dueDateIso}'
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
                  '\u20B5${row.outstandingAmount}',
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

  // ── Navigation ───────────────────────────────────────────────────────────

  Future<void> _openDebtDetail(String receivableId) async {
    await context.push('/debts/$receivableId');
    if (!mounted) return;
    ref.invalidate(receivableDetailProvider(receivableId));
    await ref.read(debtsControllerProvider.notifier).refresh();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String? _resolveSelectedReceivable(
      List<LocalReceivableRecord> openReceivables) {
    if (openReceivables.isEmpty) return null;
    final hasCurrent =
        openReceivables.any((r) => r.receivableId == _selectedReceivableId);
    return hasCurrent
        ? _selectedReceivableId
        : openReceivables.first.receivableId;
  }

  Future<void> _saveRepayment() async {
    final openReceivables =
        (ref.read(debtsControllerProvider).valueOrNull?.receivables ?? const [])
            .where((r) => r.status == 'open' || r.status == 'partially_paid')
            .toList(growable: false);
    final receivableId = _resolveSelectedReceivable(openReceivables);
    if (receivableId == null) {
      _showMessage('No open debt selected.');
      return;
    }
    try {
      await ref.read(debtsControllerProvider.notifier).recordRepayment(
            receivableId: receivableId,
            amount: _repaymentAmountCtrl.text,
            paymentMethodLabel: _repaymentMethod,
          );
      if (!mounted) return;
      _repaymentAmountCtrl.clear();
      setState(() => _showRecordPayment = false);
      _showMessage('Payment recorded.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_humanize(error));
    }
  }

  String? _resolveSelectedCustomer(List<LocalDebtCustomer> customers) {
    if (customers.isEmpty) return null;
    final hasCurrent =
        customers.any((c) => c.customerId == _selectedCustomerId);
    return hasCurrent ? _selectedCustomerId : customers.first.customerId;
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (selected == null) return;
    final m = selected.month.toString().padLeft(2, '0');
    final d = selected.day.toString().padLeft(2, '0');
    _dueDateCtrl.text = '${selected.year}-$m-$d';
    setState(() {});
  }

  Future<void> _saveCustomer() async {
    try {
      await ref.read(debtsControllerProvider.notifier).createCustomer(
            name: _nameCtrl.text,
            phoneNumber: _phoneCtrl.text,
          );
      if (!mounted) return;
      _nameCtrl.clear();
      _phoneCtrl.clear();
      setState(() => _showAddCustomer = false);
      _showMessage('Customer saved.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_humanize(error));
    }
  }

  Future<void> _saveDebt({required String? selectedCustomerId}) async {
    if (selectedCustomerId == null) {
      _showMessage('Add a customer first.');
      return;
    }
    try {
      await ref.read(debtsControllerProvider.notifier).createReceivable(
            customerId: selectedCustomerId,
            originalAmount: _amountCtrl.text,
            dueDateIso: _dueDateCtrl.text,
            note: _noteCtrl.text,
          );
      if (!mounted) return;
      _amountCtrl.clear();
      _dueDateCtrl.clear();
      _noteCtrl.clear();
      setState(() => _showCreateDebt = false);
      _showMessage('Debt created.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_humanize(error));
    }
  }

  String _humanize(Object error) {
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Invalid input.';
    }
    final s = error.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ── Stats row ───────────────────────────────────────────────────────────────

// ignore: unused_element
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.totalOutstanding,
    required this.overdue,
    required this.paidThisMonth,
    required this.totalCustomers,
  });

  final String totalOutstanding;
  final String overdue;
  final String paidThisMonth;
  final int totalCustomers;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 720
            ? (constraints.maxWidth - 30) / 4
            : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: itemWidth,
              child: _StatCard(
                label: 'Outstanding',
                value: '\u20B5$totalOutstanding',
                subLabel: 'Total owed',
                iconColor: AppColors.success,
                icon: Icons.account_balance_wallet_rounded,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _StatCard(
                label: 'Overdue',
                value: '\u20B5$overdue',
                subLabel: 'Past due date',
                iconColor: AppColors.danger,
                icon: Icons.warning_amber_rounded,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _StatCard(
                label: 'Paid / Month',
                value: '\u20B5$paidThisMonth',
                subLabel: 'This month',
                iconColor: AppColors.info,
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _StatCard(
                label: 'Customers',
                value: '$totalCustomers',
                subLabel: 'Total tracked',
                iconColor: AppColors.warning,
                icon: Icons.group_rounded,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.subLabel,
    required this.iconColor,
    required this.icon,
  });

  final String label;
  final String value;
  final String subLabel;
  final Color iconColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.ink,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              height: 1.2,
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 3),
          Text(
            subLabel,
            style: const TextStyle(
              color: AppColors.mutedSoft,
              fontSize: 9.5,
              height: 1.2,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

// ── Quick actions row ────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onAddCustomer,
    required this.onCreateDebt,
    required this.onRecordPayment,
    required this.onViewReports,
  });

  final VoidCallback onAddCustomer;
  final VoidCallback onCreateDebt;
  final VoidCallback onRecordPayment;
  final VoidCallback onViewReports;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickTile(
            icon: Icons.person_add_rounded,
            label: 'Add Customer',
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            onTap: onAddCustomer,
          ),
          const SizedBox(width: 10),
          _QuickTile(
            icon: Icons.receipt_long_rounded,
            label: 'Create Debt',
            backgroundColor: AppColors.forest,
            foregroundColor: Colors.white,
            onTap: onCreateDebt,
          ),
          const SizedBox(width: 10),
          _QuickTile(
            icon: Icons.payments_rounded,
            label: 'Record Payment',
            backgroundColor: AppColors.goldSoft,
            foregroundColor: AppColors.gold,
            onTap: onRecordPayment,
          ),
          const SizedBox(width: 10),
          _QuickTile(
            icon: Icons.bar_chart_rounded,
            label: 'Reports',
            backgroundColor: AppColors.surfaceAlt,
            foregroundColor: AppColors.inkSoft,
            onTap: onViewReports,
          ),
        ],
      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foregroundColor, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
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

// ── Action sections list (grouped card) ─────────────────────────────────────

class _ActionSectionsList extends StatelessWidget {
  const _ActionSectionsList({
    required this.showAddCustomer,
    required this.showCreateDebt,
    required this.showRecordPayment,
    required this.onToggleAddCustomer,
    required this.onToggleCreateDebt,
    required this.onToggleRecordPayment,
    required this.onViewReports,
    required this.addCustomerForm,
    required this.createDebtForm,
    required this.recordPaymentForm,
  });

  final bool showAddCustomer;
  final bool showCreateDebt;
  final bool showRecordPayment;
  final VoidCallback onToggleAddCustomer;
  final VoidCallback onToggleCreateDebt;
  final VoidCallback onToggleRecordPayment;
  final VoidCallback onViewReports;
  final Widget addCustomerForm;
  final Widget createDebtForm;
  final Widget recordPaymentForm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.person_add_rounded,
            iconColor: AppColors.success,
            title: 'Add Customer',
            subtitle: 'Add a customer to start tracking debts',
            expanded: showAddCustomer,
            isFirst: true,
            isLast: false,
            onTap: onToggleAddCustomer,
            child: addCustomerForm,
          ),
          _ActionRow(
            icon: Icons.receipt_long_rounded,
            iconColor: AppColors.warning,
            title: 'Create Debt',
            subtitle: 'Create a new debt for a customer',
            expanded: showCreateDebt,
            isFirst: false,
            isLast: false,
            onTap: onToggleCreateDebt,
            child: createDebtForm,
          ),
          _ActionRow(
            icon: Icons.payments_rounded,
            iconColor: AppColors.info,
            title: 'Record Payment',
            subtitle: 'Record a repayment for an open debt',
            expanded: showRecordPayment,
            isFirst: false,
            isLast: false,
            onTap: onToggleRecordPayment,
            child: recordPaymentForm,
          ),
          _ActionRow(
            icon: Icons.bar_chart_rounded,
            iconColor: AppColors.forest,
            title: 'View Reports',
            subtitle: 'See detailed insights and analytics',
            expanded: false,
            isFirst: false,
            isLast: true,
            onTap: onViewReports,
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool expanded;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final topRadius =
        isFirst ? const Radius.circular(AppRadii.md) : Radius.zero;
    final bottomRadius =
        isLast && !expanded ? const Radius.circular(AppRadii.md) : Radius.zero;

    return Column(
      children: [
        if (!isFirst)
          const Divider(
              height: 1, indent: 16, endIndent: 16, color: AppColors.border),
        InkWell(
          borderRadius: BorderRadius.only(
            topLeft: topRadius,
            topRight: topRadius,
            bottomLeft: expanded ? Radius.zero : bottomRadius,
            bottomRight: expanded ? Radius.zero : bottomRadius,
          ),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more_rounded,
                      color: AppColors.mutedSoft, size: 22),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState:
              expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            children: [
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: child,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Add customer form ─────────────────────────────────────────────────────────

class _AddCustomerForm extends StatelessWidget {
  const _AddCustomerForm({
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.isBusy,
    required this.onSave,
  });

  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final bool isBusy;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FormField(
          controller: nameCtrl,
          label: 'Customer name',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 10),
        _FormField(
          controller: phoneCtrl,
          label: 'Phone (optional)',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isBusy ? null : onSave,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Save Customer'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forestDark,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm)),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Create debt form ──────────────────────────────────────────────────────────

class _CreateDebtForm extends StatelessWidget {
  const _CreateDebtForm({
    required this.customers,
    required this.selectedCustomerId,
    required this.amountCtrl,
    required this.dueDateCtrl,
    required this.noteCtrl,
    required this.isBusy,
    required this.onCustomerChanged,
    required this.onPickDate,
    required this.onSave,
  });

  final List<LocalDebtCustomer> customers;
  final String? selectedCustomerId;
  final TextEditingController amountCtrl;
  final TextEditingController dueDateCtrl;
  final TextEditingController noteCtrl;
  final bool isBusy;
  final ValueChanged<String?> onCustomerChanged;
  final VoidCallback onPickDate;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedCustomerId,
          decoration: InputDecoration(
            labelText: 'Customer',
            prefixIcon: const Icon(Icons.person_outline_rounded,
                color: AppColors.muted, size: 20),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          items: customers.isEmpty
              ? [
                  const DropdownMenuItem(
                      value: null,
                      child: Text('No customers yet — add one above'))
                ]
              : customers
                  .map((c) => DropdownMenuItem(
                      value: c.customerId, child: Text(c.name)))
                  .toList(),
          onChanged: customers.isEmpty ? null : onCustomerChanged,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _FormField(
                controller: amountCtrl,
                label: 'Amount',
                icon: Icons.attach_money_rounded,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                prefixText: '\u20B5 ',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FormField(
                controller: dueDateCtrl,
                label: 'Due date',
                icon: Icons.calendar_month_outlined,
                readOnly: true,
                onTap: onPickDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _FormField(
          controller: noteCtrl,
          label: 'Note (optional)',
          icon: Icons.notes_rounded,
          maxLines: 2,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (isBusy || selectedCustomerId == null) ? null : onSave,
            icon: const Icon(Icons.receipt_long_rounded, size: 18),
            label: const Text('Create Debt'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.mutedSoft,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm)),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Record payment form ───────────────────────────────────────────────────────

class _RecordPaymentForm extends StatelessWidget {
  const _RecordPaymentForm({
    required this.openReceivables,
    required this.selectedReceivableId,
    required this.amountCtrl,
    required this.paymentMethod,
    required this.isBusy,
    required this.onReceivableChanged,
    required this.onMethodChanged,
    required this.onSave,
  });

  final List<LocalReceivableRecord> openReceivables;
  final String? selectedReceivableId;
  final TextEditingController amountCtrl;
  final String paymentMethod;
  final bool isBusy;
  final ValueChanged<String?> onReceivableChanged;
  final ValueChanged<String> onMethodChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedReceivableId,
          decoration: InputDecoration(
            labelText: 'Open debt',
            prefixIcon: const Icon(Icons.person_outline_rounded,
                color: AppColors.muted, size: 20),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          items: openReceivables.isEmpty
              ? [
                  const DropdownMenuItem(
                      value: null, child: Text('No open debts'))
                ]
              : openReceivables
                  .map((r) => DropdownMenuItem(
                        value: r.receivableId,
                        child: Text(
                          '${r.customerName} — \u20B5${r.outstandingAmount}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
          onChanged: openReceivables.isEmpty ? null : onReceivableChanged,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: paymentMethod,
          decoration: InputDecoration(
            labelText: 'Payment method',
            prefixIcon: const Icon(Icons.payments_outlined,
                color: AppColors.muted, size: 20),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('Cash')),
            DropdownMenuItem(
                value: 'mobile_money', child: Text('Mobile Money')),
            DropdownMenuItem(
                value: 'bank_transfer', child: Text('Bank Transfer')),
          ],
          onChanged: (v) {
            if (v != null) onMethodChanged(v);
          },
        ),
        const SizedBox(height: 10),
        _FormField(
          controller: amountCtrl,
          label: 'Repayment amount',
          icon: Icons.attach_money_rounded,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixText: '\u20B5 ',
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (isBusy || openReceivables.isEmpty) ? null : onSave,
            icon: const Icon(Icons.payments_rounded, size: 18),
            label: const Text('Save Repayment'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.info,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.mutedSoft,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm)),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared form field ─────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.prefixText,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? prefixText;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: AppColors.ink),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
        prefixText: prefixText,
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged, required this.onClear});
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: true,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: 'Search by customer name…',
        prefixIcon:
            const Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          color: AppColors.muted,
          onPressed: onClear,
        ),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyDebts extends StatelessWidget {
  const _EmptyDebts({required this.hasSearch});
  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: AppColors.successSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.group_outlined,
                color: AppColors.success, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            hasSearch
                ? 'No debts match your search.'
                : 'No debts recorded yet.',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasSearch
                ? 'Try a different name.'
                : 'Tap "Add Customer" then "Create Debt" to get started.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
