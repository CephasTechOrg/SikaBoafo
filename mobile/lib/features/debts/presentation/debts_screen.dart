import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../data/debts_repository.dart';
import 'debt_detail_screen.dart';
import '../providers/debts_providers.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _debtAmountCtrl = TextEditingController();
  final _repaymentAmountCtrl = TextEditingController();
  final _dueDateCtrl = TextEditingController();

  String? _selectedCustomerId;
  String? _selectedReceivableId;
  String _repaymentMethod = 'cash';

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _debtAmountCtrl.dispose();
    _repaymentAmountCtrl.dispose();
    _dueDateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debtsAsync = ref.watch(debtsControllerProvider);
    final viewData = debtsAsync.valueOrNull;
    final customers = viewData?.customers ?? const <LocalDebtCustomer>[];
    final receivables = viewData?.receivables ?? const <LocalReceivableRecord>[];
    final openReceivables = receivables.where((row) => row.status == 'open').toList(growable: false);
    final selectedCustomerId = _resolveSelectedCustomer(customers);
    final selectedReceivableId = _resolveSelectedReceivable(openReceivables);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F4E43), Color(0xFF1A6B5B), AppColors.canvas],
            stops: [0.0, 0.22, 0.22],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => ref.read(debtsControllerProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const _DebtHero(),
                const SizedBox(height: 14),
                _buildCustomerCard(isBusy: debtsAsync.isLoading),
                const SizedBox(height: 12),
                _buildCreateDebtCard(
                  customers: customers,
                  selectedCustomerId: selectedCustomerId,
                  isBusy: debtsAsync.isLoading,
                ),
                const SizedBox(height: 12),
                _buildRepaymentCard(
                  receivables: openReceivables,
                  selectedReceivableId: selectedReceivableId,
                  isBusy: debtsAsync.isLoading,
                ),
                const SizedBox(height: 18),
                Text('Debt History', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                if (debtsAsync.isLoading && receivables.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (receivables.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No debts recorded yet.'),
                    ),
                  )
                else
                  ...receivables.map(_buildReceivableTile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCard({required bool isBusy}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Customer', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _customerNameCtrl,
              decoration: const InputDecoration(labelText: 'Customer name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _customerPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isBusy ? null : _saveCustomer,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Save Customer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateDebtCard({
    required List<LocalDebtCustomer> customers,
    required String? selectedCustomerId,
    required bool isBusy,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Debt', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedCustomerId,
              decoration: const InputDecoration(labelText: 'Customer'),
              items: customers
                  .map(
                    (customer) => DropdownMenuItem(
                      value: customer.customerId,
                      child: Text(customer.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: customers.isEmpty
                  ? null
                  : (value) {
                      setState(() => _selectedCustomerId = value);
                    },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _debtAmountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: 'e.g. 120.00',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _dueDateCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Due date (optional)',
                hintText: 'YYYY-MM-DD',
                suffixIcon: Icon(Icons.calendar_month_outlined),
              ),
              onTap: _pickDueDate,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (isBusy || selectedCustomerId == null) ? null : _saveDebt,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Save Debt'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepaymentCard({
    required List<LocalReceivableRecord> receivables,
    required String? selectedReceivableId,
    required bool isBusy,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receive Payment', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedReceivableId,
              decoration: const InputDecoration(labelText: 'Open debt'),
              items: receivables
                  .map(
                    (row) => DropdownMenuItem(
                      value: row.receivableId,
                      child: Text(
                        '${row.customerName} | GHS ${row.outstandingAmount}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: receivables.isEmpty
                  ? null
                  : (value) {
                      setState(() => _selectedReceivableId = value);
                    },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _repaymentMethod,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
                DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _repaymentMethod = value);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _repaymentAmountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Repayment amount',
                hintText: 'e.g. 30.00',
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (isBusy || selectedReceivableId == null) ? null : _saveRepayment,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Save Repayment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivableTile(LocalReceivableRecord row) {
    final dt = DateTime.fromMillisecondsSinceEpoch(row.createdAtMillis);
    final statusColor = row.status == 'settled' ? AppColors.success : AppColors.warning;
    final syncColor = switch (row.syncStatus) {
      'applied' || 'duplicate' => AppColors.success,
      'failed' => AppColors.danger,
      'conflict' => AppColors.warning,
      _ => AppColors.warning,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _openDebtDetail(row.receivableId),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.16),
          child: Text(
            row.customerName.isEmpty ? '?' : row.customerName[0].toUpperCase(),
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(
          row.customerName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Outstanding GHS ${row.outstandingAmount} | Due ${row.dueDateIso ?? "not set"}'
          ' | ${dt.toLocal()}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              row.status,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 12),
            ),
            Text(
              row.syncStatus,
              style: TextStyle(color: syncColor, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDebtDetail(String receivableId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DebtDetailScreen(receivableId: receivableId),
      ),
    );
    if (!mounted) {
      return;
    }
    ref.invalidate(receivableDetailProvider(receivableId));
    await ref.read(debtsControllerProvider.notifier).refresh();
  }

  String? _resolveSelectedCustomer(List<LocalDebtCustomer> customers) {
    if (customers.isEmpty) return null;
    final hasCurrent = customers.any((customer) => customer.customerId == _selectedCustomerId);
    return hasCurrent ? _selectedCustomerId : customers.first.customerId;
  }

  String? _resolveSelectedReceivable(List<LocalReceivableRecord> receivables) {
    if (receivables.isEmpty) return null;
    final hasCurrent = receivables.any((row) => row.receivableId == _selectedReceivableId);
    return hasCurrent ? _selectedReceivableId : receivables.first.receivableId;
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
    final month = selected.month.toString().padLeft(2, '0');
    final day = selected.day.toString().padLeft(2, '0');
    _dueDateCtrl.text = '${selected.year}-$month-$day';
  }

  Future<void> _saveCustomer() async {
    try {
      await ref.read(debtsControllerProvider.notifier).createCustomer(
            name: _customerNameCtrl.text,
            phoneNumber: _customerPhoneCtrl.text,
          );
      _customerNameCtrl.clear();
      _customerPhoneCtrl.clear();
      if (!mounted) return;
      _showMessage('Customer saved.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_humanizeError(error));
    }
  }

  Future<void> _saveDebt() async {
    final selectedCustomerId = _resolveSelectedCustomer(
      ref.read(debtsControllerProvider).valueOrNull?.customers ?? const [],
    );
    if (selectedCustomerId == null) {
      _showMessage('Add a customer first.');
      return;
    }
    try {
      await ref.read(debtsControllerProvider.notifier).createReceivable(
            customerId: selectedCustomerId,
            originalAmount: _debtAmountCtrl.text,
            dueDateIso: _dueDateCtrl.text,
          );
      _debtAmountCtrl.clear();
      _dueDateCtrl.clear();
      if (!mounted) return;
      _showMessage('Debt saved.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_humanizeError(error));
    }
  }

  Future<void> _saveRepayment() async {
    final selectedReceivableId = _resolveSelectedReceivable(
      (ref.read(debtsControllerProvider).valueOrNull?.receivables ?? const [])
          .where((row) => row.status == 'open')
          .toList(growable: false),
    );
    if (selectedReceivableId == null) {
      _showMessage('No open debt to repay.');
      return;
    }
    try {
      await ref.read(debtsControllerProvider.notifier).recordRepayment(
            receivableId: selectedReceivableId,
            amount: _repaymentAmountCtrl.text,
            paymentMethodLabel: _repaymentMethod,
          );
      _repaymentAmountCtrl.clear();
      if (!mounted) return;
      _showMessage('Repayment saved.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_humanizeError(error));
    }
  }

  String _humanizeError(Object error) {
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Invalid input.';
    }
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    return message;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DebtHero extends StatelessWidget {
  const _DebtHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFEDE6D8), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manage Debts', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'Track customers, due dates, and repayments with clear status.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.group_rounded, color: AppColors.coral),
          ),
        ],
      ),
    );
  }
}
