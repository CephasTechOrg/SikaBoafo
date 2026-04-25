// ignore_for_file: unused_element, prefer_const_constructors

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/product_image_catalog.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../../inventory/data/inventory_api.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../data/sales_payments_api.dart';
import '../data/sales_repository.dart';
import '../providers/sales_providers.dart';

enum _SaleAction { edit, voidSale }

enum _SalesViewTab { newSale, history }

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final Map<String, int> _qtyByItemId = {};
  // O(1) lookup per item for price override.
  final Map<String, String> _priceOverrideByItemId = {};
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  String _paymentMethod = 'cash';
  String _searchQuery = '';
  _SalesViewTab _activeTab = _SalesViewTab.newSale;
  bool _showVoided = false;
  bool _showNote = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryControllerProvider);
    final salesAsync = ref.watch(salesControllerProvider);
    final allItems =
        (inventoryAsync.valueOrNull ?? const <LocalInventoryItem>[])
            .where((item) => item.isActive)
            .toList(growable: false);
    final recentSales = salesAsync.valueOrNull ?? const <LocalSaleRecord>[];
    final isBusy = salesAsync.isLoading;

    // O(n·m) search filter — acceptable for n < 500 items.
    final filtered = _searchQuery.isEmpty
        ? allItems
        : allItems
            .where((i) =>
                i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList(growable: false);

    // O(n) single-pass partition — stable within each group.
    final selectedItems = <LocalInventoryItem>[];
    final unselectedItems = <LocalInventoryItem>[];
    for (final item in filtered) {
      ((_qtyByItemId[item.id] ?? 0) > 0 ? selectedItems : unselectedItems)
          .add(item);
    }

    final itemCount = _qtyByItemId.values.fold(0, (a, b) => a + b);
    final totalAmount = _calculateTotal(allItems);
    final hasItems = _parseTotal(totalAmount) > 0;
    final visibleSales = recentSales.where((sale) => !sale.isVoided).toList();
    final historySales = _showVoided ? recentSales : visibleSales;
    final todaySales = visibleSales.where((sale) {
      final createdAt =
          DateTime.fromMillisecondsSinceEpoch(sale.createdAtMillis).toLocal();
      return _isSameLocalDay(createdAt, DateTime.now());
    }).toList(growable: false);
    final todayRevenueMinor = todaySales.fold<int>(
      0,
      (sum, sale) => sum + _parseTotal(sale.totalAmount),
    );
    final momoTotal = todaySales
        .where((sale) => sale.paymentMethodLabel == 'mobile_money')
        .fold<int>(0, (sum, sale) => sum + _parseTotal(sale.totalAmount));
    final cashTotal = todaySales
        .where((sale) => sale.paymentMethodLabel == 'cash')
        .fold<int>(0, (sum, sale) => sum + _parseTotal(sale.totalAmount));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.shell),
        child: Column(
          children: [
            // ── Green gradient header ──────────────────────────────────────
            Container(
              decoration: const BoxDecoration(gradient: AppGradients.hero),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
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
                                  'Sales',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Record new sales and follow today'
                                  's cashflow',
                                  style: TextStyle(
                                    color: Color(0xFFC7D0E5),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Today\'s Revenue',
                                  style: TextStyle(
                                    color: Color(0xFFC7D0E5),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _formatMinor(todayRevenueMinor, symbol: '₵'),
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
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _SalesHeroChip(
                            label: '${todaySales.length} txns',
                            value: 'Today',
                            tone: const Color(0xFF9AE7BF),
                          ),
                          const SizedBox(width: 8),
                          _SalesHeroChip(
                            label: _formatMinor(momoTotal, symbol: '₵'),
                            value: 'MoMo',
                            tone: AppColors.gold,
                          ),
                          const SizedBox(width: 8),
                          _SalesHeroChip(
                            label: _formatMinor(cashTotal, symbol: '₵'),
                            value: 'Cash',
                            tone: const Color(0xFF9AE7BF),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Content area ──────────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  child: inventoryAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          humanizeInventoryError(error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    data: (_) => Stack(
                      children: [
                        RefreshIndicator(
                          onRefresh: () async {
                            await Future.wait([
                              ref
                                  .read(inventoryControllerProvider.notifier)
                                  .refresh(),
                              ref
                                  .read(salesControllerProvider.notifier)
                                  .refresh(includeVoided: _showVoided),
                            ]);
                          },
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              18,
                              16,
                              _activeTab == _SalesViewTab.newSale ? 108 : 24,
                            ),
                            children: [
                              _SalesTabBar(
                                activeTab: _activeTab,
                                onChanged: (tab) =>
                                    setState(() => _activeTab = tab),
                              ),
                              const SizedBox(height: 18),
                              if (_activeTab == _SalesViewTab.newSale) ...[
                                _SaleDraftPanel(
                                  itemCount: itemCount,
                                  totalAmount: _formatMajor(
                                    totalAmount,
                                    symbol: 'GHS ',
                                  ),
                                  noteValue: _noteCtrl.text.trim(),
                                  showNote: _showNote,
                                  onToggleNote: () =>
                                      setState(() => _showNote = !_showNote),
                                ),
                                if (_showNote) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: TextField(
                                      controller: _noteCtrl,
                                      maxLines: 2,
                                      maxLength: 500,
                                      decoration: const InputDecoration(
                                        hintText: 'Note for this sale…',
                                        contentPadding: EdgeInsets.all(14),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        counterStyle: TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),

                                _SalesSearchBar(
                                  controller: _searchCtrl,
                                  hasQuery: _searchQuery.isNotEmpty,
                                  onChanged: (v) =>
                                      setState(() => _searchQuery = v.trim()),
                                  onClear: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                ),
                                const SizedBox(height: 14),
                                _ProductsHeader(
                                  selectedCount: selectedItems.length,
                                  totalCount: allItems.length,
                                ),
                                const SizedBox(height: 14),

                                // Item list
                                if (allItems.isEmpty)
                                  const _EmptyCard(
                                    icon: Icons.inventory_2_outlined,
                                    message:
                                        'No inventory items. Add stock in Inventory first.',
                                  )
                                else ...[
                                  if (selectedItems.isNotEmpty) ...[
                                    _SectionLabel(
                                      label:
                                          'In cart (${selectedItems.length})',
                                    ),
                                    const SizedBox(height: 10),
                                    _ItemGrid(
                                      children: selectedItems
                                          .map(
                                            (item) => _ItemCard(
                                              item: item,
                                              qty: _qtyByItemId[item.id] ?? 0,
                                              priceOverride:
                                                  _priceOverrideByItemId[
                                                      item.id],
                                              isSelected: true,
                                              onMinus: () => setState(
                                                () => _decrementQty(item.id),
                                              ),
                                              onPlus: () => setState(
                                                () => _incrementQty(item),
                                              ),
                                              onPriceTap: () =>
                                                  _showPriceOverrideDialog(
                                                      item),
                                            ),
                                          )
                                          .toList(growable: false),
                                    ),
                                    const SizedBox(height: 18),
                                  ],
                                  if (unselectedItems.isNotEmpty) ...[
                                    _SectionLabel(
                                      label: selectedItems.isNotEmpty
                                          ? 'Add more products'
                                          : 'Available products',
                                    ),
                                    const SizedBox(height: 10),
                                    _ItemGrid(
                                      children: unselectedItems
                                          .map(
                                            (item) => _ItemCard(
                                              item: item,
                                              qty: 0,
                                              priceOverride: null,
                                              isSelected: false,
                                              onMinus: () {},
                                              onPlus: () => setState(
                                                () => _incrementQty(item),
                                              ),
                                              onPriceTap: () =>
                                                  _showPriceOverrideDialog(
                                                      item),
                                            ),
                                          )
                                          .toList(growable: false),
                                    ),
                                  ],
                                  if (filtered.isEmpty &&
                                      _searchQuery.isNotEmpty)
                                    _EmptyCard(
                                      icon: Icons.search_off_rounded,
                                      message:
                                          'No items match "$_searchQuery".',
                                    ),
                                ],
                                const SizedBox(height: 24),
                              ],
                              if (_activeTab == _SalesViewTab.history) ...[
                                Row(
                                  children: [
                                    Text(
                                      'Recent Transactions',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const Spacer(),
                                    FilterChip(
                                      label: const Text('Show voided'),
                                      selected: _showVoided,
                                      onSelected: isBusy
                                          ? null
                                          : (value) async {
                                              setState(
                                                  () => _showVoided = value);
                                              await ref
                                                  .read(salesControllerProvider
                                                      .notifier)
                                                  .refresh(
                                                      includeVoided: value);
                                            },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (salesAsync.isLoading && recentSales.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Center(
                                        child: CircularProgressIndicator()),
                                  )
                                else if (historySales.isEmpty)
                                  _EmptyCard(
                                    icon: Icons.receipt_long_outlined,
                                    message: _showVoided
                                        ? 'No sales found yet.'
                                        : 'No sales yet. Record your first sale above.',
                                  )
                                else
                                  ...historySales
                                      .take(12)
                                      .map(_buildRecentSaleTile),
                              ],
                            ],
                          ),
                        ),

                        // ── Persistent bottom action bar ────────────────
                        if (_activeTab == _SalesViewTab.newSale)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _BottomBar(
                              itemCount: itemCount,
                              totalAmount: totalAmount,
                              paymentMethod: _paymentLabel(_paymentMethod),
                              hasItems: hasItems,
                              isBusy: isBusy,
                              onConfirm: () => _showCheckoutSheet(
                                items: allItems,
                                itemCount: itemCount,
                                totalAmount: totalAmount,
                                isBusy: isBusy,
                              ),
                            ),
                          ),
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

  void _incrementQty(LocalInventoryItem item) {
    final current = _qtyByItemId[item.id] ?? 0;
    if (current >= item.quantityOnHand) {
      return;
    }
    _qtyByItemId[item.id] = current + 1;
  }

  void _decrementQty(String itemId) {
    final current = _qtyByItemId[itemId] ?? 0;
    if (current <= 1) {
      _qtyByItemId.remove(itemId);
      return;
    }
    _qtyByItemId[itemId] = current - 1;
  }

  String _formatMinor(int minor, {String symbol = 'GHS '}) {
    final value = minor / 100;
    return NumberFormat.currency(symbol: symbol, decimalDigits: 2)
        .format(value);
  }

  String _formatMajor(String value, {String symbol = 'GHS '}) {
    return _formatMinor(_parseTotal(value), symbol: symbol);
  }

  Future<void> _showCheckoutSheet({
    required List<LocalInventoryItem> items,
    required int itemCount,
    required String totalAmount,
    required bool isBusy,
  }) async {
    if (_parseTotal(totalAmount) <= 0 || isBusy) {
      return;
    }
    var selectedMethod = _paymentMethod;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: AppShadows.elevated,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.borderStrong,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Confirm payment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$itemCount ${itemCount == 1 ? 'item' : 'items'} · ${_formatMajor(totalAmount, symbol: '₵')}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _CheckoutMethodButton(
                              label: 'Cash',
                              icon: Icons.payments_rounded,
                              selected: selectedMethod == 'cash',
                              accent: AppColors.navy,
                              onTap: () => setSheetState(
                                () => selectedMethod = 'cash',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CheckoutMethodButton(
                              label: 'MoMo',
                              icon: Icons.phone_android_rounded,
                              selected: selectedMethod == 'mobile_money',
                              accent: AppColors.gold,
                              onTap: () => setSheetState(
                                () => selectedMethod = 'mobile_money',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CheckoutMethodButton(
                              label: 'Bank',
                              icon: Icons.account_balance_rounded,
                              selected: selectedMethod == 'bank_transfer',
                              accent: AppColors.navySoft,
                              onTap: () => setSheetState(
                                () => selectedMethod = 'bank_transfer',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            Navigator.of(sheetContext).pop();
                            if (!mounted) return;
                            setState(() => _paymentMethod = selectedMethod);
                            await _recordSale(
                              items: items,
                              paymentMethodLabel: selectedMethod,
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(
                            'Pay ${_formatMajor(totalAmount, symbol: '₵')}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.of(sheetContext).pop();
                            if (!mounted) return;
                            setState(() => _paymentMethod = selectedMethod);
                            await _recordSaleWithPaystackLink(
                              items: items,
                              paymentMethodLabel: selectedMethod,
                            );
                          },
                          icon: const Icon(Icons.link_rounded, size: 18),
                          label: const Text('Send Paystack Payment Link'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.navy,
                            minimumSize: const Size.fromHeight(50),
                            side: const BorderSide(color: AppColors.navy),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.inkSoft,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentSaleTile(LocalSaleRecord sale) {
    final dt = DateTime.fromMillisecondsSinceEpoch(sale.createdAtMillis);
    final voidedAt = sale.voidedAtMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(sale.voidedAtMillis!);
    final syncColor = switch (sale.syncStatus) {
      'applied' || 'duplicate' => AppColors.success,
      'failed' => AppColors.danger,
      'conflict' => AppColors.warning,
      _ => AppColors.warning,
    };

    final fmt = DateFormat('MMM d, HH:mm');
    final subtitle = sale.isVoided
        ? 'Voided${sale.voidReason == null ? '' : ' | ${sale.voidReason}'} '
            '| ${fmt.format((voidedAt ?? dt).toLocal())}'
        : '${_paymentLabel(sale.paymentMethodLabel)} | ${fmt.format(dt.toLocal())}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: sale.isVoided
                    ? AppColors.dangerSoft
                    : AppColors.navy.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                sale.isVoided
                    ? Icons.block_rounded
                    : Icons.receipt_long_rounded,
                color: sale.isVoided ? AppColors.danger : AppColors.navy,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'GHS ${sale.totalAmount}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            decoration: sale.isVoided
                                ? TextDecoration.lineThrough
                                : null,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SaleStatusPill(
                        label: sale.isVoided ? 'Voided' : sale.syncStatus,
                        color: sale.isVoided ? AppColors.danger : syncColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (!sale.isVoided) ...[
              const SizedBox(width: 4),
              PopupMenuButton<_SaleAction>(
                tooltip: 'Sale actions',
                onSelected: (_SaleAction action) async {
                  if (action == _SaleAction.edit) {
                    await _showEditSaleDialog(sale);
                    return;
                  }
                  await _showVoidSaleDialog(sale);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<_SaleAction>(
                    value: _SaleAction.edit,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit sale'),
                    ),
                  ),
                  PopupMenuItem<_SaleAction>(
                    value: _SaleAction.voidSale,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Void sale'),
                    ),
                  ),
                ],
              ),
            ],
          ],
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
      final price = _priceOverrideByItemId[entry.key] ?? item.defaultPrice;
      totalMinor += _moneyToMinor(price) * qty;
    }
    final major = totalMinor ~/ 100;
    final minor = (totalMinor % 100).toString().padLeft(2, '0');
    return '$major.$minor';
  }

  int _parseTotal(String value) {
    final parts = value.split('.');
    final major = int.tryParse(parts[0]) ?? 0;
    final minor =
        parts.length == 2 ? (int.tryParse(parts[1].padRight(2, '0')) ?? 0) : 0;
    return major * 100 + minor;
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

  bool _isSameLocalDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _recordSale({
    required List<LocalInventoryItem> items,
    String? paymentMethodLabel,
  }) async {
    final lines = _buildSaleDraftLines(items);
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item quantity.')),
      );
      return;
    }
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    try {
      await ref.read(salesControllerProvider.notifier).recordSale(
            paymentMethodLabel: paymentMethodLabel ?? _paymentMethod,
            lines: lines,
            note: note,
          );
      if (!mounted) return;
      ref.invalidate(inventoryControllerProvider);
      _resetDraftAfterSale();
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

  Future<void> _recordSaleWithPaystackLink({
    required List<LocalInventoryItem> items,
    required String paymentMethodLabel,
  }) async {
    final lines = _buildSaleDraftLines(items);
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item quantity.')),
      );
      return;
    }

    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    var saleSaved = false;
    try {
      final saleId = await ref
          .read(salesControllerProvider.notifier)
          .recordSaleReturningId(
            paymentMethodLabel: paymentMethodLabel,
            lines: lines,
            note: note,
          );
      saleSaved = true;
      if (!mounted) return;

      final initiated =
          await ref.read(salesPaymentsApiProvider).initiateSalePayment(saleId);
      if (!mounted) return;

      ref.invalidate(inventoryControllerProvider);
      _resetDraftAfterSale();
      await _showPaystackLinkDialog(
        checkoutUrl: initiated.checkoutUrl,
        saleId: initiated.saleId,
        amount: initiated.amount,
        currency: initiated.currency,
      );
    } catch (error) {
      if (!mounted) return;
      if (saleSaved) {
        ref.invalidate(inventoryControllerProvider);
        _resetDraftAfterSale();
      }
      final isPaystackNotConnected = _isPaystackNotConnectedError(error);
      if (isPaystackNotConnected) {
        await _showPaystackSetupPrompt();
        return;
      }
      final message = saleSaved
          ? 'Sale recorded, but payment link failed: ${humanizeSalesPaymentsError(error)}'
          : humanizeInventoryError(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  bool _isPaystackNotConnectedError(Object error) {
    final msg = humanizeSalesPaymentsError(error).toLowerCase();
    return msg.contains('paystack is not connected') ||
        msg.contains('not connected') ||
        msg.contains('paystack connection');
  }

  Future<void> _showPaystackSetupPrompt() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paystack Not Connected'),
        content: const Text(
          'You need to connect your Paystack account before generating payment links.\n\n'
          'Go to Settings → Payments → Connect Paystack to set it up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push(AppRoute.paystack.path);
            },
            child: const Text('Set Up Paystack'),
          ),
        ],
      ),
    );
  }

  List<SaleDraftLine> _buildSaleDraftLines(List<LocalInventoryItem> items) {
    final itemById = {for (final item in items) item.id: item};
    final lines = <SaleDraftLine>[];
    for (final entry in _qtyByItemId.entries) {
      final qty = entry.value;
      if (qty <= 0) continue;
      final item = itemById[entry.key];
      if (item == null) continue;
      final price = _priceOverrideByItemId[entry.key] ?? item.defaultPrice;
      lines
          .add(SaleDraftLine(itemId: item.id, quantity: qty, unitPrice: price));
    }
    return lines;
  }

  void _resetDraftAfterSale() {
    setState(() {
      _qtyByItemId.clear();
      _priceOverrideByItemId.clear();
      _searchQuery = '';
      _showNote = false;
    });
    _noteCtrl.clear();
    _searchCtrl.clear();
  }

  Future<void> _showPaystackLinkDialog({
    required String checkoutUrl,
    required String saleId,
    required String amount,
    required String currency,
  }) async {
    if (!mounted) return;
    var confirmed = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _PaystackQrSheet(
        checkoutUrl: checkoutUrl,
        saleId: saleId,
        onPaymentConfirmed: () {
          confirmed = true;
          Navigator.of(sheetCtx).pop();
        },
      ),
    );
    if (!mounted || !confirmed) return;
    await ref
        .read(salesControllerProvider.notifier)
        .refresh(includeVoided: _showVoided);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _PaymentSuccessSheet(amount: amount, currency: currency),
    );
  }

  Future<void> _showPriceOverrideDialog(LocalInventoryItem item) async {
    final ctrl = TextEditingController(
        text: _priceOverrideByItemId[item.id] ?? item.defaultPrice);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Set price — ${item.name}'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
            ],
            decoration: const InputDecoration(
              labelText: 'Unit price (GHS)',
              prefixText: 'GHS ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _priceOverrideByItemId.remove(item.id));
                Navigator.of(ctx).pop();
              },
              child: const Text('Reset to default'),
            ),
            FilledButton(
              onPressed: () {
                final raw = ctrl.text.trim();
                final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
                if (match == null || double.tryParse(raw) == 0) return;
                setState(() => _priceOverrideByItemId[item.id] = raw);
                Navigator.of(ctx).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  Future<void> _showEditSaleDialog(LocalSaleRecord sale) async {
    final editable = await ref
        .read(salesControllerProvider.notifier)
        .loadSaleEditable(saleId: sale.saleId);
    if (editable == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale cannot be edited anymore.')),
      );
      return;
    }

    var paymentMethod = editable.paymentMethodLabel;
    final qtyByItem = {
      for (final line in editable.lines) line.itemId: line.quantity,
    };
    var isSaving = false;

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Sale'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: paymentMethod,
                      decoration:
                          const InputDecoration(labelText: 'Payment method'),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(
                          value: 'mobile_money',
                          child: Text('Mobile Money'),
                        ),
                        DropdownMenuItem(
                          value: 'bank_transfer',
                          child: Text('Bank Transfer'),
                        ),
                      ],
                      onChanged: isSaving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() => paymentMethod = value);
                            },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Adjust existing line quantities',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ...editable.lines.map((line) {
                      final selectedQty =
                          qtyByItem[line.itemId] ?? line.quantity;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    line.itemName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    'Unit GHS ${line.unitPrice} | Max ${line.maxQuantity}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            _CircleQtyBtn(
                              icon: Icons.remove_rounded,
                              enabled: !isSaving && selectedQty > 1,
                              onTap: () => setDialogState(
                                () => qtyByItem[line.itemId] = selectedQty - 1,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '$selectedQty',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            _CircleQtyBtn(
                              icon: Icons.add_rounded,
                              enabled:
                                  !isSaving && selectedQty < line.maxQuantity,
                              onTap: () => setDialogState(
                                () => qtyByItem[line.itemId] = selectedQty + 1,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          try {
                            final lines = editable.lines
                                .map(
                                  (line) => SaleQuantityUpdateDraft(
                                    itemId: line.itemId,
                                    quantity:
                                        qtyByItem[line.itemId] ?? line.quantity,
                                  ),
                                )
                                .toList(growable: false);
                            await ref
                                .read(salesControllerProvider.notifier)
                                .updateSale(
                                  saleId: sale.saleId,
                                  paymentMethodLabel: paymentMethod,
                                  lines: lines,
                                );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sale updated.')),
                            );
                          } catch (error) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(humanizeInventoryError(error))),
                            );
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() => isSaving = false);
                            }
                          }
                        },
                  child: Text(isSaving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showVoidSaleDialog(LocalSaleRecord sale) async {
    final reasonCtrl = TextEditingController();
    try {
      final shouldVoid = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Void Sale'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will reverse stock quantities and keep the sale as a voided record.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Void Sale'),
              ),
            ],
          );
        },
      );
      if (shouldVoid != true) return;

      await ref.read(salesControllerProvider.notifier).voidSale(
            saleId: sale.saleId,
            reason: reasonCtrl.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale voided.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeInventoryError(error))),
      );
    } finally {
      reasonCtrl.dispose();
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

// ── Payment card ────────────────────────────────────────────────────────────

class _SalesHeroChip extends StatelessWidget {
  const _SalesHeroChip({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
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
              style: TextStyle(
                color: tone,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.56),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleDraftPanel extends StatelessWidget {
  const _SaleDraftPanel({
    required this.itemCount,
    required this.totalAmount,
    required this.noteValue,
    required this.showNote,
    required this.onToggleNote,
  });

  final int itemCount;
  final String totalAmount;
  final String noteValue;
  final bool showNote;
  final VoidCallback onToggleNote;

  @override
  Widget build(BuildContext context) {
    final hasNote = noteValue.isNotEmpty;
    return PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeading(
            title: 'Sale draft',
            caption:
                'Build the cart first. Payment method is chosen once at checkout.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DraftMetric(
                icon: Icons.shopping_bag_rounded,
                iconColor: AppColors.navy,
                label: 'Items selected',
                value: '$itemCount',
              ),
              _DraftMetric(
                icon: Icons.attach_money_rounded,
                iconColor: AppColors.success,
                label: 'Current total',
                value: totalAmount,
              ),
              _DraftMetric(
                icon: Icons.sticky_note_2_rounded,
                iconColor: AppColors.warning,
                label: hasNote ? 'Note added' : 'Sale note',
                value: hasNote ? 'Ready' : 'Optional',
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onToggleNote,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    showNote
                        ? Icons.expand_less_rounded
                        : Icons.note_alt_outlined,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasNote
                          ? 'Edit sale note'
                          : showNote
                              ? 'Hide sale note'
                              : 'Add sale note',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    hasNote ? 'Attached' : 'Optional',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftMetric extends StatelessWidget {
  const _DraftMetric({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 104),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalesSearchBar extends StatelessWidget {
  const _SalesSearchBar({
    required this.controller,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: AppColors.ink),
        decoration: InputDecoration(
          hintText: 'Search products by name',
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 18,
            color: AppColors.muted,
          ),
          suffixIcon: hasQuery
              ? IconButton(
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.muted,
                  ),
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

class _ProductsHeader extends StatelessWidget {
  const _ProductsHeader({
    required this.selectedCount,
    required this.totalCount,
  });

  final int selectedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select products and quantity',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Keep the cart compact and confirm only when it looks right.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color:
                selectedCount > 0 ? AppColors.infoSoft : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            '$selectedCount / $totalCount',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SalesTabBar extends StatelessWidget {
  const _SalesTabBar({
    required this.activeTab,
    required this.onChanged,
  });

  final _SalesViewTab activeTab;
  final ValueChanged<_SalesViewTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        children: [
          Expanded(
            child: _SalesTabPill(
              label: 'New Sale',
              selected: activeTab == _SalesViewTab.newSale,
              onTap: () => onChanged(_SalesViewTab.newSale),
            ),
          ),
          Expanded(
            child: _SalesTabPill(
              label: 'History',
              selected: activeTab == _SalesViewTab.history,
              onTap: () => onChanged(_SalesViewTab.history),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesTabPill extends StatelessWidget {
  const _SalesTabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.inkSoft,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CheckoutMethodButton extends StatelessWidget {
  const _CheckoutMethodButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? accent : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? Colors.white : accent,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Item card ────────────────────────────────────────────────────────────────

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep two cards per row on standard mobile widths.
        final useSingleColumn = constraints.maxWidth < 300;
        final cardExtent = useSingleColumn
            ? 242.0
            : (constraints.maxWidth < 360 ? 278.0 : 262.0);
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: useSingleColumn ? 1 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: cardExtent,
          ),
          children: children,
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.qty,
    required this.priceOverride,
    required this.isSelected,
    required this.onMinus,
    required this.onPlus,
    required this.onPriceTap,
  });

  final LocalInventoryItem item;
  final int qty;
  final String? priceOverride;
  final bool isSelected;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onPriceTap;

  @override
  Widget build(BuildContext context) {
    final displayPrice = priceOverride ?? item.defaultPrice;
    final hasOverride = priceOverride != null;
    final stockTone =
        item.quantityOnHand <= 5 ? AppColors.danger : AppColors.success;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? AppColors.navy : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: isSelected ? AppShadows.card : AppShadows.subtle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.category ?? 'Stock item',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.quantityOnHand <= 5)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Low',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.center,
              child: ItemImage(
                imageAsset: item.imageAsset,
                size: 58,
                fallbackIcon: Icons.inventory_2_outlined,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: AppColors.ink,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onPriceTap,
              child: Text(
                hasOverride ? '₵$displayPrice custom' : '₵$displayPrice',
                style: TextStyle(
                  color: hasOverride ? AppColors.warning : AppColors.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: stockTone.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Stock: ${item.quantityOnHand}',
                style: TextStyle(
                  color: stockTone,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFFEFF3FA) : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  _CircleQtyBtn(
                    icon: Icons.remove_rounded,
                    enabled: qty > 0,
                    onTap: onMinus,
                  ),
                  SizedBox(
                    width: 32,
                    child: Center(
                      child: Text(
                        '$qty',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                  _CircleQtyBtn(
                    icon: Icons.add_rounded,
                    enabled: qty < item.quantityOnHand,
                    onTap: onPlus,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Circular qty button ──────────────────────────────────────────────────────

class _CircleQtyBtn extends StatelessWidget {
  const _CircleQtyBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: enabled ? AppColors.navy : const Color(0xFFDDDDDD),
            width: 1.2,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppColors.navy : AppColors.muted,
        ),
      ),
    );
  }
}

// ── Bottom action bar ────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.itemCount,
    required this.totalAmount,
    required this.paymentMethod,
    required this.hasItems,
    required this.isBusy,
    required this.onConfirm,
  });

  final int itemCount;
  final String totalAmount;
  final String paymentMethod;
  final bool hasItems;
  final bool isBusy;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        boxShadow: AppShadows.elevated,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.shopping_cart_outlined,
                        color: AppColors.navy,
                        size: 20,
                      ),
                    ),
                    if (itemCount > 0)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$itemCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    itemCount == 0 ? 'Cart is empty' : 'Ready to checkout',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '₵$totalAmount',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    hasItems ? 'Payment selected at checkout' : paymentMethod,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: (hasItems && !isBusy) ? onConfirm : null,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                  iconAlignment: IconAlignment.end,
                  label: Text(isBusy ? 'Saving...' : 'Checkout'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCCCCCC),
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Paystack QR payment sheet ─────────────────────────────────────────────────

class _PaystackQrSheet extends ConsumerStatefulWidget {
  const _PaystackQrSheet({
    required this.checkoutUrl,
    required this.saleId,
    required this.onPaymentConfirmed,
  });

  final String checkoutUrl;
  final String saleId;
  final VoidCallback onPaymentConfirmed;

  @override
  ConsumerState<_PaystackQrSheet> createState() => _PaystackQrSheetState();
}

class _PaystackQrSheetState extends ConsumerState<_PaystackQrSheet> {
  Timer? _timer;
  int _pollCount = 0;
  bool _checking = false;
  static const _maxPolls = 20;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _check(auto: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check({bool auto = false}) async {
    if (_checking) return;
    if (auto && _pollCount >= _maxPolls) {
      _timer?.cancel();
      return;
    }
    if (auto) _pollCount++;
    setState(() => _checking = true);
    try {
      final status = await ref
          .read(salesPaymentsApiProvider)
          .fetchSalePaymentStatus(widget.saleId);
      if (!mounted) return;
      if (status.paymentStatus == 'succeeded') {
        _timer?.cancel();
        widget.onPaymentConfirmed();
        return;
      }
      if (!auto) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status.paymentStatus == 'pending_provider'
              ? 'Still waiting for payment...'
              : 'Payment ${status.paymentStatus.replaceAll('_', ' ')}'),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      if (!auto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not check status. Try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppShadows.elevated,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Scan to Pay',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Show this QR to the customer. Payment confirms automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.card,
                ),
                child: QrImageView(
                  data: widget.checkoutUrl,
                  version: QrVersions.auto,
                  size: 210,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.navy,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _checking
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        )
                      : const Icon(Icons.wifi_rounded,
                          size: 12, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    _checking ? 'Checking...' : 'Waiting for payment',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: widget.checkoutUrl));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Payment link copied.'),
                              duration: Duration(seconds: 2)),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Link'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _checking ? null : () => _check(),
                      icon: _checking
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Check Now'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: AppColors.inkSoft,
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Payment success overlay ───────────────────────────────────────────────────

class _PaymentSuccessSheet extends StatefulWidget {
  const _PaymentSuccessSheet({required this.amount, required this.currency});
  final String amount;
  final String currency;

  @override
  State<_PaymentSuccessSheet> createState() => _PaymentSuccessSheetState();
}

class _PaymentSuccessSheetState extends State<_PaymentSuccessSheet>
    with TickerProviderStateMixin {
  late final AnimationController _circleCtrl;
  late final AnimationController _checkCtrl;
  late final AnimationController _contentCtrl;
  late final Animation<double> _circleAnim;
  late final Animation<double> _checkAnim;
  late final Animation<double> _contentAnim;

  @override
  void initState() {
    super.initState();
    _circleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));

    _circleAnim =
        CurvedAnimation(parent: _circleCtrl, curve: Curves.elasticOut);
    _checkAnim = CurvedAnimation(parent: _checkCtrl, curve: Curves.easeOut);
    _contentAnim =
        CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);

    HapticFeedback.heavyImpact();
    _circleCtrl.forward().then((_) {
      _checkCtrl.forward().then((_) {
        HapticFeedback.mediumImpact();
        _contentCtrl.forward();
      });
    });
  }

  @override
  void dispose() {
    _circleCtrl.dispose();
    _checkCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppShadows.elevated,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_circleCtrl, _checkCtrl]),
                builder: (_, __) => SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    painter: _SuccessCheckPainter(
                      circleProgress: _circleAnim.value,
                      checkProgress: _checkAnim.value,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _contentAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(_contentAnim),
                  child: Column(
                    children: [
                      const Text(
                        'Payment Confirmed!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.currency} ${widget.amount}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: AppColors.success,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Received via Paystack · Sale updated',
                        style:
                            TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessCheckPainter extends CustomPainter {
  const _SuccessCheckPainter({
    required this.circleProgress,
    required this.checkProgress,
  });

  final double circleProgress;
  final double checkProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final p = circleProgress.clamp(0.0, 1.0);

    // Soft background circle
    canvas.drawCircle(
      center,
      radius * p,
      Paint()
        ..color = AppColors.success.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );

    // Solid filled circle
    canvas.drawCircle(
      center,
      (radius - 10) * p,
      Paint()
        ..color = AppColors.success
        ..style = PaintingStyle.fill,
    );

    if (checkProgress <= 0 || p < 0.7) return;

    // Animated checkmark drawn progressively
    final p1 = Offset(center.dx - 22, center.dy + 2);
    final p2 = Offset(center.dx - 6, center.dy + 18);
    final p3 = Offset(center.dx + 24, center.dy - 16);

    final seg1 = _dist(p1, p2);
    final seg2 = _dist(p2, p3);
    final total = seg1 + seg2;
    final drawn = total * checkProgress.clamp(0.0, 1.0);

    final path = Path()..moveTo(p1.dx, p1.dy);
    if (drawn <= seg1) {
      final t = drawn / seg1;
      path.lineTo(p1.dx + (p2.dx - p1.dx) * t, p1.dy + (p2.dy - p1.dy) * t);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = (drawn - seg1) / seg2;
      path.lineTo(p2.dx + (p3.dx - p2.dx) * t, p2.dy + (p3.dy - p2.dy) * t);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  double _dist(Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  bool shouldRepaint(_SuccessCheckPainter old) =>
      old.circleProgress != circleProgress ||
      old.checkProgress != checkProgress;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _SaleStatusPill extends StatelessWidget {
  const _SaleStatusPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.muted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
