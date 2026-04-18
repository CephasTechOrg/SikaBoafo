import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../data/debts_repository.dart';
import 'debt_detail_screen.dart';
import '../providers/debts_providers.dart';

// ── Design tokens ──────────────────────────────────────────────────────────
const _kHeaderGradient = LinearGradient(
  colors: [Color(0xFF08302A), Color(0xFF1A6655)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// O(n) YYYY-MM-DD lexicographic comparison — no DateTime.parse needed.
String _receivableStatus(LocalReceivableRecord r) {
  if (r.status == 'settled') return 'settled';
  final d = r.dueDateIso;
  if (d == null || d.isEmpty) return 'open';
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final soon = DateFormat('yyyy-MM-dd')
      .format(DateTime.now().add(const Duration(days: 7)));
  if (d.compareTo(today) < 0) return 'overdue';
  if (d.compareTo(soon) <= 0) return 'due_soon';
  return 'open';
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
  // Form controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _dueDateCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _repaymentAmountCtrl = TextEditingController();

  // UI state
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
    final receivables = viewData?.receivables ?? const <LocalReceivableRecord>[];
    final paidThisMonth = viewData?.paidThisMonth ?? '0.00';
    final isBusy = debtsAsync.isLoading;

    // O(n) single-pass stats
    int outstandingMinor = 0;
    int overdueMinor = 0;
    for (final r in receivables) {
      if (r.status != 'open') continue;
      final m = _moneyToMinorLocal(r.outstandingAmount);
      outstandingMinor += m;
      if (_receivableStatus(r) == 'overdue') overdueMinor += m;
    }

    final selectedCustomerId = _resolveSelectedCustomer(customers);

    // Search filter for recent debts
    final filtered = _searchQuery.isEmpty
        ? receivables
        : receivables
            .where((r) =>
                r.customerName
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()))
            .toList(growable: false);

    return Scaffold(
      body: Column(
        children: [
          // ── Green gradient header ────────────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: _kHeaderGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                child: Row(
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
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Track customers, due dates and repayments',
                            style: TextStyle(
                              color: Color(0xFFB2D8CE),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _HeaderIconBtn(
                      icon: _showSearch
                          ? Icons.search_off_rounded
                          : Icons.search_rounded,
                      onTap: () =>
                          setState(() => _showSearch = !_showSearch),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Content area ────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF6F7F9),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                child: debtsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(e.toString(),
                          textAlign: TextAlign.center),
                    ),
                  ),
                  data: (_) => RefreshIndicator(
                    onRefresh: () =>
                        ref.read(debtsControllerProvider.notifier).refresh(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                      children: [
                        // Search bar (slides in)
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

                        // Stats row
                        _StatsRow(
                          totalOutstanding:
                              _minorToMoneyLocal(outstandingMinor),
                          overdue: _minorToMoneyLocal(overdueMinor),
                          paidThisMonth: paidThisMonth,
                          totalCustomers: customers.length,
                        ),
                        const SizedBox(height: 16),

                        // Quick actions
                        _QuickActions(
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
                          onViewReports: () =>
                              widget.onNavigate?.call(5),
                        ),
                        const SizedBox(height: 14),

                        // Add Customer expandable
                        _ExpandableSection(
                          title: 'Add Customer',
                          subtitle:
                              'Add a new customer to start tracking debts',
                          icon: Icons.person_add_rounded,
                          iconBg: const Color(0xFFE8F5E9),
                          iconFg: const Color(0xFF2E7D32),
                          expanded: _showAddCustomer,
                          onToggle: () => setState(
                              () => _showAddCustomer = !_showAddCustomer),
                          child: _AddCustomerForm(
                            nameCtrl: _nameCtrl,
                            phoneCtrl: _phoneCtrl,
                            isBusy: isBusy,
                            onSave: _saveCustomer,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Create Debt expandable
                        _ExpandableSection(
                          title: 'Create Debt',
                          subtitle: 'Creates a new debt for a customer',
                          icon: Icons.receipt_long_rounded,
                          iconBg: const Color(0xFFFFF3E0),
                          iconFg: const Color(0xFFD97706),
                          expanded: _showCreateDebt,
                          onToggle: () => setState(
                              () => _showCreateDebt = !_showCreateDebt),
                          child: _CreateDebtForm(
                            customers: customers,
                            selectedCustomerId: selectedCustomerId,
                            amountCtrl: _amountCtrl,
                            dueDateCtrl: _dueDateCtrl,
                            noteCtrl: _noteCtrl,
                            isBusy: isBusy,
                            onCustomerChanged: (v) =>
                                setState(() => _selectedCustomerId = v),
                            onPickDate: _pickDueDate,
                            onSave: () =>
                                _saveDebt(selectedCustomerId: selectedCustomerId),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Record Payment expandable
                        _ExpandableSection(
                          title: 'Record Payment',
                          subtitle: 'Record a repayment for an open debt',
                          icon: Icons.payments_rounded,
                          iconBg: const Color(0xFFE8F1FB),
                          iconFg: const Color(0xFF2D6BC4),
                          expanded: _showRecordPayment,
                          onToggle: () => setState(
                              () => _showRecordPayment = !_showRecordPayment),
                          child: _RecordPaymentForm(
                            openReceivables: receivables
                                .where((r) => r.status == 'open')
                                .toList(growable: false),
                            selectedReceivableId: _resolveSelectedReceivable(
                              receivables
                                  .where((r) => r.status == 'open')
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

                        // Recent Debts header
                        Row(
                          children: [
                            Text(
                              'Recent Debts',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            if (receivables.isNotEmpty)
                              GestureDetector(
                                onTap: () => setState(
                                    () => _showSearch = !_showSearch),
                                child: const Text(
                                  'Search all →',
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
                          _EmptyDebts(
                              hasSearch: _searchQuery.isNotEmpty)
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
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCard(LocalReceivableRecord row) {
    final status = _receivableStatus(row);
    final (statusLabel, statusColor, avatarBg) = switch (status) {
      'overdue' => (
          'Overdue',
          const Color(0xFFC62828),
          const Color(0xFFFFEBEE)
        ),
      'due_soon' => (
          'Due Soon',
          const Color(0xFFD97706),
          const Color(0xFFFFF3E0)
        ),
      'settled' => (
          'Settled',
          const Color(0xFF2E7D32),
          const Color(0xFFE8F5E9)
        ),
      _ => (
          'Open',
          const Color(0xFF2D6BC4),
          const Color(0xFFE8F1FB)
        ),
    };

    final initials = row.customerName.trim().isEmpty
        ? '?'
        : row.customerName.trim().split(' ').take(2).map((w) => w[0]).join().toUpperCase();

    final dueLabel = row.dueDateIso != null && row.dueDateIso!.isNotEmpty
        ? 'Due ${row.dueDateIso}'
        : 'No due date';

    return GestureDetector(
      onTap: () => _openDebtDetail(row.receivableId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x07000000),
                blurRadius: 8,
                offset: Offset(0, 2)),
          ],
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
                          ? const Color(0xFFC62828)
                          : AppColors.muted,
                      fontSize: 12,
                      fontWeight: status == 'overdue'
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // Amount + status badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'GHS ${row.outstandingAmount}',
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
                    borderRadius: BorderRadius.circular(20),
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DebtDetailScreen(receivableId: receivableId),
      ),
    );
    if (!mounted) return;
    ref.invalidate(receivableDetailProvider(receivableId));
    await ref.read(debtsControllerProvider.notifier).refresh();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String? _resolveSelectedReceivable(
      List<LocalReceivableRecord> openReceivables) {
    if (openReceivables.isEmpty) return null;
    final hasCurrent = openReceivables
        .any((r) => r.receivableId == _selectedReceivableId);
    return hasCurrent
        ? _selectedReceivableId
        : openReceivables.first.receivableId;
  }

  Future<void> _saveRepayment() async {
    final openReceivables =
        (ref.read(debtsControllerProvider).valueOrNull?.receivables ?? const [])
            .where((r) => r.status == 'open')
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
      _repaymentAmountCtrl.clear();
      setState(() => _showRecordPayment = false);
      if (!mounted) return;
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
      _nameCtrl.clear();
      _phoneCtrl.clear();
      setState(() => _showAddCustomer = false);
      if (!mounted) return;
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
      _amountCtrl.clear();
      _dueDateCtrl.clear();
      _noteCtrl.clear();
      setState(() => _showCreateDebt = false);
      if (!mounted) return;
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ── Stats row ───────────────────────────────────────────────────────────────

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
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Outstanding',
            value: 'GHS $totalOutstanding',
            iconBg: const Color(0xFFE8F5E9),
            iconFg: const Color(0xFF2E7D32),
            icon: Icons.account_balance_wallet_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Overdue',
            value: 'GHS $overdue',
            iconBg: const Color(0xFFFFEBEE),
            iconFg: const Color(0xFFC62828),
            icon: Icons.warning_amber_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Paid This Month',
            value: 'GHS $paidThisMonth',
            iconBg: const Color(0xFFE8F1FB),
            iconFg: const Color(0xFF2D6BC4),
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Customers',
            value: '$totalCustomers',
            iconBg: const Color(0xFFFFF3E0),
            iconFg: const Color(0xFFD97706),
            icon: Icons.group_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.iconBg,
    required this.iconFg,
    required this.icon,
  });

  final String label;
  final String value;
  final Color iconBg;
  final Color iconFg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconFg, size: 16),
          ),
          const SizedBox(height: 8),
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
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

// ── Quick actions ────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionBtn(
              icon: Icons.person_add_rounded,
              label: 'Add\nCustomer',
              iconBg: const Color(0xFFE8F5E9),
              iconFg: const Color(0xFF2E7D32),
              onTap: onAddCustomer,
            ),
          ),
          Expanded(
            child: _QuickActionBtn(
              icon: Icons.receipt_long_rounded,
              label: 'Create\nDebt',
              iconBg: const Color(0xFFFFF3E0),
              iconFg: const Color(0xFFD97706),
              onTap: onCreateDebt,
            ),
          ),
          Expanded(
            child: _QuickActionBtn(
              icon: Icons.payments_rounded,
              label: 'Record\nPayment',
              iconBg: const Color(0xFFE8F1FB),
              iconFg: const Color(0xFF2D6BC4),
              onTap: onRecordPayment,
            ),
          ),
          Expanded(
            child: _QuickActionBtn(
              icon: Icons.bar_chart_rounded,
              label: 'View\nReports',
              iconBg: const Color(0xFFF3E5F5),
              iconFg: const Color(0xFF6A1B9A),
              onTap: onViewReports,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.iconBg,
    required this.iconFg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconBg;
  final Color iconFg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconFg, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expandable section ───────────────────────────────────────────────────────

class _ExpandableSection extends StatelessWidget {
  const _ExpandableSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: expanded ? AppColors.forest : const Color(0xFFEEEEEE),
          width: expanded ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconFg, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.ink,
                          ),
                        ),
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
                        color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
          // Expanded form
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
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
                  borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700),
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
        // Customer dropdown
        DropdownButtonFormField<String>(
          initialValue: selectedCustomerId,
          decoration: InputDecoration(
            labelText: 'Customer',
            prefixIcon: const Icon(Icons.person_outline_rounded,
                color: AppColors.muted, size: 20),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
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
        // Amount + due date row
        Row(
          children: [
            Expanded(
              child: _FormField(
                controller: amountCtrl,
                label: 'Amount',
                icon: Icons.attach_money_rounded,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                prefixText: 'GHS ',
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
        // Note
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
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFCCCCCC),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700),
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
            fillColor: const Color(0xFFF8F9FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          items: openReceivables.isEmpty
              ? [
                  const DropdownMenuItem(
                      value: null,
                      child: Text('No open debts'))
                ]
              : openReceivables
                  .map((r) => DropdownMenuItem(
                        value: r.receivableId,
                        child: Text(
                          '${r.customerName} — GHS ${r.outstandingAmount}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
          onChanged:
              openReceivables.isEmpty ? null : onReceivableChanged,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: paymentMethod,
          decoration: InputDecoration(
            labelText: 'Payment method',
            prefixIcon: const Icon(Icons.payments_outlined,
                color: AppColors.muted, size: 20),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
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
          onChanged: (v) { if (v != null) onMethodChanged(v); },
        ),
        const SizedBox(height: 10),
        _FormField(
          controller: amountCtrl,
          label: 'Repayment amount',
          icon: Icons.attach_money_rounded,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          prefixText: 'GHS ',
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                (isBusy || openReceivables.isEmpty) ? null : onSave,
            icon: const Icon(Icons.payments_rounded, size: 18),
            label: const Text('Save Repayment'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2D6BC4),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFCCCCCC),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700),
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
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.forest, width: 1.4),
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
        prefixIcon: const Icon(Icons.search_rounded,
            color: AppColors.muted, size: 20),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          color: AppColors.muted,
          onPressed: onClear,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.group_outlined,
                color: Color(0xFF2E7D32), size: 28),
          ),
          const SizedBox(height: 12),
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

// ── Header icon button ─────────────────────────────────────────────────────────

class _HeaderIconBtn extends StatelessWidget {
  const _HeaderIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
