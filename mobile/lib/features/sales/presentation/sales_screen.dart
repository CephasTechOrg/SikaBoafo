import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../inventory/data/inventory_api.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../data/sales_repository.dart';
import '../providers/sales_providers.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final Map<String, int> _qtyByItemId = {};
  String _paymentMethod = 'cash';

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryControllerProvider);
    final salesAsync = ref.watch(salesControllerProvider);
    final items = inventoryAsync.valueOrNull ?? const <LocalInventoryItem>[];
    final recentSales = salesAsync.valueOrNull ?? const <LocalSaleRecord>[];
    final totalAmount = _calculateTotal(items);
    final isBusy = salesAsync.isLoading;

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
          child: inventoryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  humanizeInventoryError(error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            data: (_) {
              return RefreshIndicator(
                onRefresh: () async {
                  await ref.read(inventoryControllerProvider.notifier).refresh();
                  await ref.read(salesControllerProvider.notifier).refresh();
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _SalesHero(totalAmount: totalAmount),
                    const SizedBox(height: 14),
                    _PaymentSelector(
                      paymentMethod: _paymentMethod,
                      onSelected: (value) => setState(() => _paymentMethod = value),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select items and quantity',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text(
                            'No inventory items available. Add stock in Inventory first.',
                          ),
                        ),
                      )
                    else
                      ...items.map((item) => _buildItemCard(item: item)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: isBusy ? null : () => _recordSale(items: items),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: Text(isBusy ? 'Saving...' : 'Confirm Sale'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Recent Sales',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    if (salesAsync.isLoading && recentSales.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (recentSales.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('No sales recorded yet.'),
                        ),
                      )
                    else
                      ...recentSales.take(8).map(_buildRecentSaleTile),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard({required LocalInventoryItem item}) {
    final selectedQty = _qtyByItemId[item.id] ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.shopping_bag_outlined, color: AppColors.forest),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'GHS ${item.defaultPrice} | In stock ${item.quantityOnHand}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _QtyButton(
                  icon: Icons.remove_rounded,
                  enabled: selectedQty > 0,
                  onTap: () => setState(() => _qtyByItemId[item.id] = selectedQty - 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '$selectedQty',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
                _QtyButton(
                  icon: Icons.add_rounded,
                  enabled: selectedQty < item.quantityOnHand,
                  onTap: () => setState(() => _qtyByItemId[item.id] = selectedQty + 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSaleTile(LocalSaleRecord sale) {
    final dt = DateTime.fromMillisecondsSinceEpoch(sale.createdAtMillis);
    final syncColor = switch (sale.syncStatus) {
      'applied' || 'duplicate' => AppColors.success,
      'failed' => AppColors.danger,
      'conflict' => AppColors.warning,
      _ => AppColors.warning,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(
          'GHS ${sale.totalAmount}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${_paymentLabel(sale.paymentMethodLabel)} | ${dt.toLocal()}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          sale.syncStatus,
          style: TextStyle(color: syncColor, fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ),
    );
  }

  String _calculateTotal(List<LocalInventoryItem> items) {
    final itemById = {for (final item in items) item.id: item};
    int totalMinor = 0;
    for (final entry in _qtyByItemId.entries) {
      final qty = entry.value;
      if (qty <= 0) continue;
      final item = itemById[entry.key];
      if (item == null) continue;
      totalMinor += _moneyToMinor(item.defaultPrice) * qty;
    }
    final major = totalMinor ~/ 100;
    final minor = (totalMinor % 100).toString().padLeft(2, '0');
    return '$major.$minor';
  }

  int _moneyToMinor(String value) {
    final raw = value.trim();
    final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
    if (match == null) return 0;
    final parts = raw.split('.');
    final major = int.parse(parts[0]);
    final decimals = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
    return (major * 100) + int.parse(decimals);
  }

  Future<void> _recordSale({required List<LocalInventoryItem> items}) async {
    final itemById = {for (final item in items) item.id: item};
    final lines = <SaleDraftLine>[];
    for (final entry in _qtyByItemId.entries) {
      final qty = entry.value;
      if (qty <= 0) continue;
      final item = itemById[entry.key];
      if (item == null) continue;
      lines.add(SaleDraftLine(itemId: item.id, quantity: qty, unitPrice: item.defaultPrice));
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item quantity.')),
      );
      return;
    }
    try {
      await ref.read(salesControllerProvider.notifier).recordSale(
            paymentMethodLabel: _paymentMethod,
            lines: lines,
          );
      ref.invalidate(inventoryControllerProvider);
      setState(_qtyByItemId.clear);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale recorded.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeInventoryError(error))),
      );
    }
  }

  String _paymentLabel(String raw) {
    return switch (raw) {
      'mobile_money' => 'Mobile Money',
      'bank_transfer' => 'Bank Transfer',
      _ => 'Cash',
    };
  }
}

class _SalesHero extends StatelessWidget {
  const _SalesHero({required this.totalAmount});

  final String totalAmount;

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
                Text('Record Sale', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'Build the basket quickly and confirm in one tap.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.forestDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  'Total',
                  style: TextStyle(color: Color(0xFFD7F3EA), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'GHS $totalAmount',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSelector extends StatelessWidget {
  const _PaymentSelector({
    required this.paymentMethod,
    required this.onSelected,
  });

  final String paymentMethod;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose Payment Method', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PaymentMethodTile(
                    label: 'Cash',
                    icon: Icons.account_balance_wallet_rounded,
                    selected: paymentMethod == 'cash',
                    onTap: () => onSelected('cash'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PaymentMethodTile(
                    label: 'Mobile Money',
                    icon: Icons.phone_android_rounded,
                    selected: paymentMethod == 'mobile_money',
                    onTap: () => onSelected('mobile_money'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PaymentMethodTile(
                    label: 'Bank Transfer',
                    icon: Icons.account_balance_rounded,
                    selected: paymentMethod == 'bank_transfer',
                    onTap: () => onSelected('bank_transfer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : AppColors.forest),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled ? AppColors.mint : AppColors.border.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.forest : AppColors.muted,
          size: 18,
        ),
      ),
    );
  }
}
