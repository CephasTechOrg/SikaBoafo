import 'dart:async';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../data/local/kv_cache_repository.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../../shared/widgets/stale_banner.dart';

import '../../inventory/data/inventory_api.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../data/sales_payments_api.dart';
import '../data/sales_repository.dart';
import '../providers/sales_providers.dart';
import '../providers/sales_cart_provider.dart';
import 'widgets/empty_card.dart';
import 'widgets/sales_search_bar.dart';
import 'widgets/sales_tab_bar.dart';
import 'widgets/section_label.dart';
import 'widgets/item_card.dart';
import 'widgets/sales_bottom_bar.dart';
import 'widgets/products_header.dart';
import '../../settings/presentation/connect_paystack_screen.dart';
import 'widgets/paystack_momo_sheet.dart';
import 'widgets/paystack_qr_sheet.dart';
import 'widgets/sale_success_sheet.dart';
import 'widgets/checkout_sheet.dart';
import 'widgets/review_sale_sheet.dart';
import 'widgets/edit_sale_sheet.dart';
import 'widgets/void_sale_sheet.dart';
import 'widgets/recent_sale_tile.dart';
import 'widgets/sales_header.dart';
import 'widgets/sales_new_sale_view.dart';
import 'widgets/sales_history_view.dart';
import 'utils/sales_ui_utils.dart';



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
    final hasItems = SalesUiUtils.parseTotal(totalAmount) > 0;
    final visibleSales = recentSales.where((sale) => !sale.isVoided).toList();
    final historySales = _showVoided ? recentSales : visibleSales;
    final todaySales = visibleSales.where((sale) {
      final createdAt =
          DateTime.fromMillisecondsSinceEpoch(sale.createdAtMillis).toLocal();
      return SalesUiUtils.isSameLocalDay(createdAt, DateTime.now());
    }).toList(growable: false);
    final todayRevenueMinor = todaySales.fold<int>(
      0,
      (sum, sale) => sum + SalesUiUtils.parseTotal(sale.totalAmount),
    );
    final cashTotalMinor = todaySales
        .where((s) => s.paymentMethodLabel == 'cash')
        .fold<int>(0, (sum, s) => sum + SalesUiUtils.parseTotal(s.totalAmount));
    final momoTotalMinor = todaySales
        .where((s) => s.paymentMethodLabel == 'mobile_money')
        .fold<int>(0, (sum, s) => sum + SalesUiUtils.parseTotal(s.totalAmount));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(color: AppColors.canvas),
        child: Column(
          children: [
            SalesHeader(
              todayRevenueMinor: todayRevenueMinor,
              todayTxnsCount: todaySales.length,
              cashTotalMinor: cashTotalMinor,
              momoTotalMinor: momoTotalMinor,
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
                                      if (_activeTab == SalesViewTab.newSale)
                                        SalesNewSaleView(
                                          searchCtrl: _searchCtrl,
                                          allItems: allItems,
                                          filteredItems: filtered,
                                          selectedItems: selectedItems,
                                          quickAddItems: quickAddItems,
                                          regularUnselectedItems: regularUnselectedItems,
                                          onPriceTap: _showPriceOverrideDialog,
                                        )
                                      else
                                        SalesHistoryView(
                                          showVoided: _showVoided,
                                          onShowVoidedChanged: (value) async {
                                            setState(() => _showVoided = value);
                                            await ref.read(salesControllerProvider.notifier).refresh(includeVoided: value);
                                          },
                                          historySales: historySales,
                                          buildSaleTile: _buildRecentSaleTile,
                                          isBusy: isBusy,
                                        ),
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




  Future<void> _showCheckoutSheet({
    required List<LocalInventoryItem> items,
    required int itemCount,
    required String totalAmount,
    required bool isBusy,
  }) async {
    if (SalesUiUtils.parseTotal(totalAmount) <= 0 || isBusy) return;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckoutSheet(
        items: items,
        itemCount: itemCount,
        totalAmount: totalAmount,
        formatMajor: (val, {symbol = 'GHS '}) => SalesUiUtils.formatMinor(SalesUiUtils.parseTotal(val), symbol: symbol),
        onRecordCash: (method) => _recordSale(
          items: items,
          paymentMethodLabel: method,
        ),
        onRecordMomo: (method) => _recordSaleWithPaystackLink(
          items: items,
          paymentMethodLabel: method,
        ),
        onPayWithMomoNumber: (method) => _recordSaleWithPaystackMomoNumber(
          items: items,
          paymentMethodLabel: method,
          totalAmount: totalAmount,
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
      totalMinor += SalesUiUtils.moneyToMinor(price) * qty;
    }
    final major = totalMinor ~/ 100;
    final minor = (totalMinor % 100).toString().padLeft(2, '0');
    return '$major.$minor';
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

  Future<void> _recordSaleWithPaystackMomoNumber({
    required List<LocalInventoryItem> items,
    required String paymentMethodLabel,
    required String totalAmount,
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

      ref.invalidate(inventoryControllerProvider);
      _resetDraftAfterSale();

      var confirmed = false;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) {
          final mode = ref.read(paystackConnectionProvider).valueOrNull?.mode.toLowerCase();
          final paystackTestMode = mode == 'test';
          return PaystackMomoSheet(
            saleId: saleId,
            amountDisplay: totalAmount,
            paystackTestMode: paystackTestMode,
            onPaymentConfirmed: () {
              confirmed = true;
              Navigator.of(sheetCtx).pop();
            },
          );
        },
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
        builder: (_) => SaleSuccessSheet(
          amount: totalAmount,
          method: 'mobile_money',
        ),
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
          ? 'Sale recorded, but MoMo prompt failed: ${humanizeSalesPaymentsError(error)}'
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
        formatMajor: (val, {symbol = 'GHS '}) => SalesUiUtils.formatMinor(SalesUiUtils.parseTotal(val), symbol: symbol),
        formatMinor: SalesUiUtils.formatMinor,
        moneyToMinor: SalesUiUtils.moneyToMinor,
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
        totalMinor: SalesUiUtils.moneyToMinorSafe(row.salesTotal),
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
            salesTotal: SalesUiUtils.minorToMoney(row.totalMinor),
          ),
        )
        .toList(growable: false);
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



