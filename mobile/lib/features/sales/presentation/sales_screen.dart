import 'dart:async';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';


import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../data/local/kv_cache_repository.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../../shared/widgets/data_freshness_label.dart';
import '../../../shared/widgets/stale_banner.dart';

import '../../inventory/data/inventory_api.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../data/sales_payments_api.dart';
import '../data/sales_repository.dart';
import '../providers/sales_providers.dart';
import '../providers/sales_cart_provider.dart';
import 'widgets/empty_card.dart';
import 'widgets/hero_stat_chip.dart';
import 'widgets/sales_search_bar.dart';
import 'widgets/sales_tab_bar.dart';
import 'widgets/section_label.dart';
import 'widgets/item_card.dart';
import 'widgets/sales_bottom_bar.dart';
import 'widgets/products_header.dart';
import 'widgets/paystack_qr_sheet.dart';
import 'widgets/sale_success_sheet.dart';
import 'widgets/checkout_sheet.dart';
import 'widgets/review_sale_sheet.dart';
import 'widgets/edit_sale_sheet.dart';
import 'widgets/void_sale_sheet.dart';
import 'widgets/recent_sale_tile.dart';



class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
      final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
      SalesViewTab _activeTab = SalesViewTab.newSale;
  bool _showVoided = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(salesCartProvider);
    final cartNotifier = ref.read(salesCartProvider.notifier);

    final inventoryAsync = ref.watch(inventoryControllerProvider);
    final salesAsync = ref.watch(salesControllerProvider);
    final dashboardInsightsAsync = ref.watch(dashboardInsightsProvider);
    final dashboardOverlayAsync = ref.watch(localDashboardOverlayProvider);
    final allItems =
        (inventoryAsync.valueOrNull ?? const <LocalInventoryItem>[])
            .where((item) => item.isActive)
            .toList(growable: false);
    final recentSales = salesAsync.valueOrNull ?? const <LocalSaleRecord>[];
    final isBusy = salesAsync.isLoading;

    // O(n·m) search filter — acceptable for n < 500 items.
    final filtered = cart.searchQuery.isEmpty
        ? allItems
        : allItems
            .where((i) =>
                i.name.toLowerCase().contains(cart.searchQuery.toLowerCase()))
            .toList(growable: false);

    // O(n) single-pass partition — stable within each group.
    final selectedItems = <LocalInventoryItem>[];
    final unselectedItems = <LocalInventoryItem>[];
    for (final item in filtered) {
      ((cart.qtyByItemId[item.id] ?? 0) > 0 ? selectedItems : unselectedItems)
          .add(item);
    }

    final topSellingRows = _mergeTopSelling(
      dashboardInsightsAsync.valueOrNull?.monthlyTopSellingItems ?? const [],
      dashboardOverlayAsync.valueOrNull?.monthPendingTopSelling ?? const [],
      limit: 3,
    );

    // Build set of top-selling item IDs to filter from available list.
    final topSellingIds = <String>{
      for (final row in topSellingRows) row.itemId,
    };

    // Filter top-selling items from unselected for separate "Quick Add" section.
    final quickAddItems = unselectedItems
        .where((item) => topSellingIds.contains(item.id))
        .toList(growable: false);
    final regularUnselectedItems = unselectedItems
        .where((item) => !topSellingIds.contains(item.id))
        .toList(growable: false);

    // Sort regular items by name.
    regularUnselectedItems.sort((a, b) => a.name.compareTo(b.name));

    final itemCount = cart.qtyByItemId.values.fold(0, (a, b) => a + b);
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
    final cashTotalMinor = todaySales
        .where((s) => s.paymentMethodLabel == 'cash')
        .fold<int>(0, (sum, s) => sum + _parseTotal(s.totalAmount));
    final momoTotalMinor = todaySales
        .where((s) => s.paymentMethodLabel == 'mobile_money')
        .fold<int>(0, (sum, s) => sum + _parseTotal(s.totalAmount));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(color: AppColors.canvas),
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A0F172A),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Layer 1 — deep anchor: very dark at bottom-left,
                        // rich forest green toward top-right
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF020F06),
                                Color(0xFF063318),
                                Color(0xFF0B5228),
                                Color(0xFF116438),
                              ],
                              stops: [0.0, 0.32, 0.66, 1.0],
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                            ),
                          ),
                        ),
                        // Layer 2 — vivid emerald bloom, top-right quadrant
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0.68, -0.72),
                              radius: 0.92,
                              colors: [
                                const Color(0xFF27A84E).withValues(alpha: 0.56),
                                const Color(0xFF1A7A38).withValues(alpha: 0.22),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                        // Layer 3 — secondary warm glow, center
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(-0.10, 0.0),
                              radius: 1.2,
                              colors: [
                                const Color(0xFF0D6030).withValues(alpha: 0.35),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 1.0],
                            ),
                          ),
                        ),
                        // Layer 4 — deep shadow vignette at all edges
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF010A04).withValues(alpha: 0.72),
                                Colors.transparent,
                                const Color(0xFF010A04).withValues(alpha: 0.30),
                              ],
                              stops: const [0.0, 0.50, 1.0],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                        // Layer 5 — top-edge sheen for premium depth
                        const Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: 1.5,
                          child: ColoredBox(color: Color(0x22FFFFFF)),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: -10,
                    bottom: -8,
                    child: Opacity(
                      opacity: 0.42,
                      child: Image.asset(
                        'assets/images/sales.png',
                        width: 185,
                        height: 185,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.point_of_sale_rounded,
                                  color: Colors.white,
                                  size: 17,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Sales',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.2,
                                      height: 1.1,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  DataFreshnessLabel(
                                    kvKey: KvCacheRepository.kSalesTs,
                                    color: AppColors.heroSubtitle,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "TODAY'S REVENUE",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatMinor(todayRevenueMinor, symbol: '₵'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'Constantia',
                                    letterSpacing: -0.8,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              HeroStatChip(
                                icon: Icons.receipt_long_rounded,
                                value: '${todaySales.length}',
                                label: 'txns today',
                              ),
                              const SizedBox(width: 8),
                              HeroStatChip(
                                icon: Icons.payments_rounded,
                                value:
                                    _formatMinor(cashTotalMinor, symbol: '₵'),
                                label: 'Cash',
                              ),
                              const SizedBox(width: 8),
                              HeroStatChip(
                                icon: Icons.phone_android_rounded,
                                value:
                                    _formatMinor(momoTotalMinor, symbol: '₵'),
                                label: 'MoMo',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -8),
                child: Column(
                  children: [
                    const StaleBanner(
                      screenKey: 'sales',
                      kvKey: KvCacheRepository.kSalesTs,
                    ),
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.canvas,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          child: inventoryAsync.when(
                            loading: () => const Center(
                                child: CircularProgressIndicator()),
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
                                          .read(inventoryControllerProvider
                                              .notifier)
                                          .refresh(),
                                      ref
                                          .read(
                                              salesControllerProvider.notifier)
                                          .refresh(includeVoided: _showVoided),
                                    ]);
                                  },
                                  child: ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      14,
                                      16,
                                      _activeTab == SalesViewTab.newSale
                                          ? 108
                                          : 24,
                                    ),
                                    children: [
                                      SalesTabBar(
                                        activeTab: _activeTab,
                                        onChanged: (tab) => setState(
                                          () => _activeTab = tab,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (_activeTab ==
                                          SalesViewTab.newSale) ...[
                                        SalesSearchBar(
                                          controller: _searchCtrl,
                                          hasQuery: cart.searchQuery.isNotEmpty,
                                          onChanged: (v) {
                                            _searchCtrl.value = _searchCtrl.value.copyWith(text: v.trim());
                                            ref.read(salesCartProvider.notifier).setSearchQuery(v.trim());
                                          },
                                          onClear: () {
                                            _searchCtrl.clear();
                                            ref.read(salesCartProvider.notifier).setSearchQuery('');
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        ProductsHeader(
                                          selectedCount: selectedItems.length,
                                          totalCount: allItems.length,
                                        ),
                                        const SizedBox(height: 5),
                                        if (allItems.isEmpty)
                                          const EmptyCard(
                                            icon: Icons.inventory_2_outlined,
                                            message:
                                                'No inventory items. Add stock in Inventory first.',
                                          )
                                        else ...[
                                          if (selectedItems.isNotEmpty) ...[
                                            SectionLabel(
                                              label:
                                                  'In cart (${selectedItems.length})',
                                            ),
                                            const SizedBox(height: 7),
                                            ItemGrid(
                                              children: selectedItems
                                                  .map(
                                                    (item) => ItemCard(
                                                      item: item,
                                                      qty: cart.qtyByItemId[
                                                              item.id] ??
                                                          0,
                                                      priceOverride:
                                                          cart.priceOverrideByItemId[
                                                              item.id],
                                                      isSelected: true,
                                                      onMinus: () => setState(
                                                        () => cartNotifier.decrementQty(
                                                          item.id,
                                                        ),
                                                      ),
                                                      onPlus: () => setState(
                                                        () => cartNotifier.incrementQty(
                                                          item,
                                                        ),
                                                      ),
                                                      onPriceTap: () =>
                                                          _showPriceOverrideDialog(
                                                        item,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(growable: false),
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          // Quick Add: Top 3 selling items.
                                          if (quickAddItems.isNotEmpty) ...[
                                            const SectionLabel(
                                              label: 'Quick Add',
                                            ),
                                            const SizedBox(height: 7),
                                            ItemGrid(
                                              children: quickAddItems
                                                  .map(
                                                    (item) => ItemCard(
                                                      item: item,
                                                      qty: 0,
                                                      priceOverride: null,
                                                      isSelected: false,
                                                      onMinus: () {},
                                                      onPlus: () => setState(
                                                        () => cartNotifier.incrementQty(
                                                          item,
                                                        ),
                                                      ),
                                                      onPriceTap: () =>
                                                          _showPriceOverrideDialog(
                                                        item,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(growable: false),
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          if (regularUnselectedItems
                                              .isNotEmpty) ...[
                                            SectionLabel(
                                              label: selectedItems.isNotEmpty
                                                  ? 'Add more products'
                                                  : 'Available products',
                                            ),
                                            const SizedBox(height: 7),
                                            ItemGrid(
                                              children: regularUnselectedItems
                                                  .map(
                                                    (item) => ItemCard(
                                                      item: item,
                                                      qty: 0,
                                                      priceOverride: null,
                                                      isSelected: false,
                                                      onMinus: () {},
                                                      onPlus: () => setState(
                                                        () => cartNotifier.incrementQty(
                                                          item,
                                                        ),
                                                      ),
                                                      onPriceTap: () =>
                                                          _showPriceOverrideDialog(
                                                        item,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(growable: false),
                                            ),
                                          ],
                                          if (filtered.isEmpty &&
                                              cart.searchQuery.isNotEmpty)
                                            EmptyCard(
                                              icon: Icons.search_off_rounded,
                                              message:
                                                  'No items match "$cart.searchQuery".',
                                            ),
                                        ],
                                        const SizedBox(height: 24),
                                      ],
                                      if (_activeTab ==
                                          SalesViewTab.history) ...[
                                        Row(
                                          children: [
                                            const Text(
                                              'Recent Transactions',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.ink,
                                              ),
                                            ),
                                            const Spacer(),
                                            FilterChip(
                                              label: const Text('Show voided'),
                                              selected: _showVoided,
                                              onSelected: isBusy
                                                  ? null
                                                  : (value) async {
                                                      setState(() =>
                                                          _showVoided = value);
                                                      await ref
                                                          .read(
                                                            salesControllerProvider
                                                                .notifier,
                                                          )
                                                          .refresh(
                                                            includeVoided:
                                                                value,
                                                          );
                                                    },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        if (salesAsync.isLoading &&
                                            recentSales.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 20,
                                            ),
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          )
                                        else if (historySales.isEmpty)
                                          EmptyCard(
                                            icon: Icons.receipt_long_outlined,
                                            message: _showVoided
                                                ? 'No sales found yet.'
                                                : 'No sales yet. Switch to New Sale to record your first one.',
                                          )
                                        else
                                          ...historySales
                                              .take(12)
                                              .map(_buildRecentSaleTile),
                                      ],
                                    ],
                                  ),
                                ),
                                if (_activeTab == SalesViewTab.newSale)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: SalesBottomBar(
                                      itemCount: itemCount,
                                      totalAmount: totalAmount,
                                      paymentMethod: _paymentLabel(
                                        cart.paymentMethod,
                                      ),
                                      hasItems: hasItems,
                                      isBusy: isBusy,
                                      onConfirm: () => _showReviewSaleSheet(
                                        items: allItems,
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
            ),
          ],
        ),
      ),
    );
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
    if (_parseTotal(totalAmount) <= 0 || isBusy) return;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckoutSheet(
        items: items,
        itemCount: itemCount,
        totalAmount: totalAmount,
        formatMajor: _formatMajor,
        onRecordCash: (method) => _recordSale(
          items: items,
          paymentMethodLabel: method,
        ),
        onRecordMomo: (method) => _recordSaleWithPaystackLink(
          items: items,
          paymentMethodLabel: method,
        ),
      ),
    );
  }

  Widget _buildRecentSaleTile(LocalSaleRecord sale) {
    return RecentSaleTile(
      sale: sale,
      onEdit: () => _showEditSaleDialog(sale),
      onVoid: () => _showVoidSaleDialog(sale),
    );
  }

  String _calculateTotal(List<LocalInventoryItem> items) {
    final cart = ref.read(salesCartProvider);
    final itemById = {for (final item in items) item.id: item};
    int totalMinor = 0;
    for (final entry in cart.qtyByItemId.entries) {
      final qty = entry.value;
      if (qty <= 0) continue;
      final item = itemById[entry.key];
      if (item == null) continue;
      final price = cart.priceOverrideByItemId[entry.key] ?? item.defaultPrice;
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

  Future<bool> _recordSale({
    required List<LocalInventoryItem> items,
    String? paymentMethodLabel,
  }) async {
    final lines = _buildSaleDraftLines(items);
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item quantity.')),
      );
      return false;
    }
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    try {
      await ref.read(salesControllerProvider.notifier).recordSale(
            paymentMethodLabel: paymentMethodLabel ?? ref.read(salesCartProvider).paymentMethod,
            lines: lines,
            note: note,
          );
      if (!mounted) return false;
      ref.invalidate(inventoryControllerProvider);
      _resetDraftAfterSale();
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeInventoryError(error))),
      );
      return false;
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
    final cart = ref.read(salesCartProvider);
    final itemById = {for (final item in items) item.id: item};
    final lines = <SaleDraftLine>[];
    for (final entry in cart.qtyByItemId.entries) {
      final qty = entry.value;
      if (qty <= 0) continue;
      final item = itemById[entry.key];
      if (item == null) continue;
      final price = cart.priceOverrideByItemId[entry.key] ?? item.defaultPrice;
      lines
          .add(SaleDraftLine(itemId: item.id, quantity: qty, unitPrice: price));
    }
    return lines;
  }

  void _resetDraftAfterSale() {
    ref.read(salesCartProvider.notifier).clearCart();
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
      builder: (sheetCtx) => PaystackQrSheet(
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
      builder: (_) => SaleSuccessSheet(amount: amount, method: 'mobile_money'),
    );
  }

  Future<void> _showReviewSaleSheet({
    required List<LocalInventoryItem> items,
  }) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReviewSaleSheet(
        items: items,
        noteController: _noteCtrl,
        calculateTotal: _calculateTotal,
        formatMajor: _formatMajor,
        formatMinor: _formatMinor,
        moneyToMinor: _moneyToMinor,
        onProceedToCheckout: () async {
          if (!mounted) return;
          await _showCheckoutSheet(
            items: items,
            itemCount: ref.read(salesCartProvider).qtyByItemId.values.fold(0, (a, b) => a + b),
            totalAmount: _calculateTotal(items),
            isBusy: false,
          );
        },
      ),
    );
  }

  Future<void> _showPriceOverrideDialog(LocalInventoryItem item) async {
    final ctrl = TextEditingController(
        text: ref.read(salesCartProvider).priceOverrideByItemId[item.id] ?? item.defaultPrice);
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
                ref.read(salesCartProvider.notifier).removeOverride(item.id);
                Navigator.of(ctx).pop();
              },
              child: const Text('Reset to default'),
            ),
            FilledButton(
              onPressed: () {
                final raw = ctrl.text.trim();
                final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
                if (match == null || double.tryParse(raw) == 0) return;
                ref.read(salesCartProvider.notifier).overridePrice(item.id, raw);
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
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditSaleSheet(sale: sale, editable: editable),
    );
  }

  Future<void> _showVoidSaleDialog(LocalSaleRecord sale) async {
    final reasonCtrl = TextEditingController();
    try {
      final shouldVoid = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => VoidSaleSheet(sale: sale, reasonController: reasonCtrl),
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

  List<DashboardTopSellingItem> _mergeTopSelling(
    List<DashboardTopSellingItem> server,
    List<LocalTopSellingOverlayRow> pending, {
    int limit = 3,
  }) {
    final byId = <String, _TopAgg>{};
    for (final row in server) {
      byId[row.itemId] = _TopAgg(
        itemId: row.itemId,
        itemName: row.itemName,
        qty: row.quantitySold,
        totalMinor: _moneyToMinorSafe(row.salesTotal),
      );
    }
    for (final row in pending) {
      final existing = byId[row.itemId];
      if (existing == null) {
        byId[row.itemId] = _TopAgg(
          itemId: row.itemId,
          itemName: row.itemName,
          qty: row.quantitySold,
          totalMinor: row.salesTotalMinor,
        );
      } else {
        byId[row.itemId] = existing.copyWith(
          qty: existing.qty + row.quantitySold,
          totalMinor: existing.totalMinor + row.salesTotalMinor,
        );
      }
    }

    final list = byId.values.toList(growable: false);
    list.sort((a, b) {
      final byQty = b.qty.compareTo(a.qty);
      if (byQty != 0) return byQty;
      return b.totalMinor.compareTo(a.totalMinor);
    });

    return list
        .take(limit)
        .map(
          (row) => DashboardTopSellingItem(
            itemId: row.itemId,
            itemName: row.itemName,
            quantitySold: row.qty,
            salesTotal: minorToMoney(row.totalMinor),
          ),
        )
        .toList(growable: false);
  }

  int _moneyToMinorSafe(String value) {
    final raw = value.trim();
    final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
    if (match == null) return 0;
    final parts = raw.split('.');
    final major = int.tryParse(parts[0]) ?? 0;
    final decimals = parts.length == 2 ? (parts[1].padRight(2, '0')) : '00';
    return (major * 100) + (int.tryParse(decimals) ?? 0);
  }
}

class _TopAgg {
  const _TopAgg({
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.totalMinor,
  });

  final String itemId;
  final String itemName;
  final int qty;
  final int totalMinor;

  _TopAgg copyWith({int? qty, int? totalMinor}) => _TopAgg(
        itemId: itemId,
        itemName: itemName,
        qty: qty ?? this.qty,
        totalMinor: totalMinor ?? this.totalMinor,
      );
}







// ── Item card ────────────────────────────────────────────────────────────────



// ── Circular qty button ──────────────────────────────────────────────────────


// ── Bottom action bar ────────────────────────────────────────────────────────


// ── Paystack QR payment sheet ─────────────────────────────────────────────────



// ── Payment success overlay ───────────────────────────────────────────────────




// ── Helpers ──────────────────────────────────────────────────────────────────



