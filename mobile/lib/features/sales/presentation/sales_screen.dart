import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/services/notifications_service.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/session_role_providers.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../inventory/data/inventory_api.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/providers/inventory_providers.dart';
import 'package:dio/dio.dart';

import '../../../shared/providers/sync_providers.dart';
import '../utils/sale_sync_error.dart';
import '../data/sales_payments_api.dart';
import '../data/sales_repository.dart';
import '../providers/sales_providers.dart';
import '../providers/sales_cart_provider.dart';
import '../../settings/providers/notification_prefs_provider.dart';
import 'widgets/sales_search_bar.dart';
import 'widgets/sales_tab_bar.dart';
import 'widgets/sales_bottom_bar.dart';
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
  bool _cartReadyForOnlinePay = true;
  bool _cartSyncingForOnlinePay = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(salesCartProvider);
    final merchantAsync = ref.watch(merchantContextProvider);
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

    // Sorted unique categories for the chip bar (only items with a category set).
    final categories =
        (allItems.map((i) => i.category).whereType<String>().toSet().toList()
              ..sort())
            .toList(growable: false);

    final filtered = allItems.where((i) {
      final matchesSearch = cart.searchQuery.isEmpty ||
          i.name.toLowerCase().contains(cart.searchQuery.toLowerCase());
      final matchesCategory =
          cart.selectedCategory == null || i.category == cart.selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList(growable: false);

    final itemIdsWithQty = cart.qtyByItemId.entries
        .where((e) => e.value > 0)
        .map((e) => itemIdFromKey(e.key))
        .toSet();
    final selectedItems = <LocalInventoryItem>[];
    final unselectedItems = <LocalInventoryItem>[];
    for (final item in filtered) {
      (itemIdsWithQty.contains(item.id) ? selectedItems : unselectedItems)
          .add(item);
    }

    final topSellingRows = _mergeTopSelling(
      dashboardInsightsAsync.valueOrNull?.monthlyTopSellingItems ?? const [],
      dashboardOverlayAsync.valueOrNull?.monthPendingTopSelling ?? const [],
      limit: 4,
    );
    final topSellingIds = {for (final row in topSellingRows) row.itemId};
    final quickAddItems = unselectedItems
        .where((item) => topSellingIds.contains(item.id))
        .toList();
    final regularUnselectedItems = unselectedItems
        .where((item) => !topSellingIds.contains(item.id))
        .toList();
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
    }).toList();

    final todayRevenueMinor = todaySales.fold<int>(
      0,
      (sum, sale) => sum + SalesUiUtils.parseTotal(sale.totalAmount),
    );
    final cashTotalMinor =
        todaySales.where((s) => s.paymentMethodLabel == 'cash').fold<int>(
              0,
              (sum, s) => sum + SalesUiUtils.parseTotal(s.totalAmount),
            );
    final momoTotalMinor = todaySales
        .where((s) => s.paymentMethodLabel == 'mobile_money')
        .fold<int>(
          0,
          (sum, s) => sum + SalesUiUtils.parseTotal(s.totalAmount),
        );

    // Extract top seller details
    final topSellingMonth =
        dashboardInsightsAsync.valueOrNull?.monthlyTopSellingItems;
    final topItem =
        topSellingMonth?.isNotEmpty == true ? topSellingMonth!.first : null;
    final topItemName = topItem?.itemName;
    final topItemQty = topItem?.quantitySold;

    String? topItemImageUrl;
    if (topItem != null) {
      final match = allItems.where((i) => i.id == topItem.itemId).firstOrNull;
      topItemImageUrl = match?.imageUrl;
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: 270,
                pinned: true,
                backgroundColor: const Color(0xFF071D11),
                elevation: 0,
                centerTitle: false,
                title: innerBoxIsScrolled
                    ? const Text(
                        'Sales',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      )
                    : null,
                actions: innerBoxIsScrolled
                    ? [
                        Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: Center(
                            child: Text(
                              SalesUiUtils.formatMinor(todayRevenueMinor,
                                  symbol: '₵'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                fontFamily: 'Constantia',
                              ),
                            ),
                          ),
                        ),
                      ]
                    : null,
                flexibleSpace: FlexibleSpaceBar(
                  background: SalesHeader(
                    businessName:
                        merchantAsync.valueOrNull?.businessName ?? 'My Shop',
                    todayRevenueMinor: todayRevenueMinor,
                    todayTxnsCount: todaySales.length,
                    cashTotalMinor: cashTotalMinor,
                    momoTotalMinor: momoTotalMinor,
                    topSellingItemName: topItemName,
                    topSellingQty: topItemQty,
                    topSellingImageUrl: topItemImageUrl,
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabDelegate(
                  activeTab: _activeTab,
                  child: SalesTabBar(
                    activeTab: _activeTab,
                    onChanged: (tab) => setState(() => _activeTab = tab),
                  ),
                ),
              ),
            ],
            body: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: inventoryAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text(humanizeInventoryError(error))),
                data: (_) => RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      ref.read(inventoryControllerProvider.notifier).refresh(),
                      ref
                          .read(salesControllerProvider.notifier)
                          .refresh(includeVoided: _showVoided),
                    ]);
                  },
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: AppColors.surface),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        _activeTab == SalesViewTab.newSale ? 110 : 28,
                      ),
                      children: [
                        if (_activeTab == SalesViewTab.newSale) ...[
                          const SizedBox(height: 8),
                          SalesSearchBar(
                            controller: _searchCtrl,
                            hasQuery: cart.searchQuery.isNotEmpty,
                            onChanged: (q) => ref
                                .read(salesCartProvider.notifier)
                                .setSearchQuery(q),
                            onClear: () {
                              _searchCtrl.clear();
                              ref
                                  .read(salesCartProvider.notifier)
                                  .setSearchQuery('');
                            },
                          ),
                          if (categories.length >= 2) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 38,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: categories.length + 1,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return _CategoryChip(
                                      label: 'All',
                                      selected: cart.selectedCategory == null,
                                      onTap: () => ref
                                          .read(salesCartProvider.notifier)
                                          .setCategory(null),
                                    );
                                  }
                                  final cat = categories[index - 1];
                                  return _CategoryChip(
                                    label: cat,
                                    selected: cart.selectedCategory == cat,
                                    onTap: () => ref
                                        .read(salesCartProvider.notifier)
                                        .setCategory(
                                          cart.selectedCategory == cat
                                              ? null
                                              : cat,
                                        ),
                                  );
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          SalesNewSaleView(
                            allItems: allItems,
                            filteredItems: filtered,
                            selectedItems: selectedItems,
                            quickAddItems: quickAddItems,
                            regularUnselectedItems: regularUnselectedItems,
                            onPriceTap: _showPriceOverrideDialog,
                          ),
                        ] else
                          SalesHistoryView(
                            showVoided: _showVoided,
                            onShowVoidedChanged: (value) async {
                              setState(() => _showVoided = value);
                              await ref
                                  .read(salesControllerProvider.notifier)
                                  .refresh(includeVoided: value);
                            },
                            historySales: historySales,
                            buildSaleTile: _buildRecentSaleTile,
                            isBusy: isBusy,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
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
                paymentMethod: _paymentLabel(cart.paymentMethod),
                hasItems: hasItems,
                isBusy: isBusy,
                onConfirm: () => _showReviewSaleSheet(items: allItems),
              ),
            ),
        ],
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
    await _refreshCartOnlinePayReadiness(items);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckoutSheet(
        items: items,
        itemCount: itemCount,
        totalAmount: totalAmount,
        cartReadyForOnlinePay: _cartReadyForOnlinePay,
        syncingForOnlinePay: _cartSyncingForOnlinePay,
        onSyncCartForOnlinePay: () => _syncCartForOnlinePayment(items),
        formatMajor: (val, {symbol = 'GHS '}) => SalesUiUtils.formatMinor(
            SalesUiUtils.parseTotal(val),
            symbol: symbol),
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

  Set<String> _cartItemIdsForOnlinePay(List<LocalInventoryItem> items) {
    final cart = ref.read(salesCartProvider);
    final knownIds = {for (final item in items) item.id};
    return cart.qtyByItemId.entries
        .where((e) => e.value > 0)
        .map((e) => itemIdFromKey(e.key))
        .where(knownIds.contains)
        .toSet();
  }

  Future<void> _refreshCartOnlinePayReadiness(
    List<LocalInventoryItem> items,
  ) async {
    final itemIds = _cartItemIdsForOnlinePay(items);
    if (itemIds.isEmpty) {
      if (mounted) setState(() => _cartReadyForOnlinePay = true);
      return;
    }
    final blocked = await ref
        .read(appDatabaseProvider)
        .syncQueue
        .hasUnresolvedItemCreatesForIds(itemIds);
    if (!mounted) return;
    setState(() => _cartReadyForOnlinePay = !blocked);
  }

  Future<bool> _ensureCartReadyForOnlinePayment(
    List<LocalInventoryItem> items,
  ) async {
    await _refreshCartOnlinePayReadiness(items);
    if (!mounted) return false;
    if (_cartReadyForOnlinePay) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Some items must sync before online payment. Tap Sync now in checkout.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
    return false;
  }

  Future<bool> _syncCartForOnlinePayment(
    List<LocalInventoryItem> items,
  ) async {
    if (_cartSyncingForOnlinePay) return _cartReadyForOnlinePay;
    setState(() => _cartSyncingForOnlinePay = true);
    try {
      await ref.read(syncStatusControllerProvider.notifier).syncNow();
      if (!mounted) return _cartReadyForOnlinePay;
      await _refreshCartOnlinePayReadiness(items);
      if (!mounted) return _cartReadyForOnlinePay;
      if (_cartReadyForOnlinePay) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Items synced. You can collect online now.'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Some items still need to sync. Check your connection and try again.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return _cartReadyForOnlinePay;
    } finally {
      if (mounted) setState(() => _cartSyncingForOnlinePay = false);
    }
  }

  void _logSaleFlowError(String flow, Object error, StackTrace? stackTrace) {
    if (kDebugMode) {
      debugPrint('[$flow] ${error.runtimeType}: $error');
      if (stackTrace != null) {
        debugPrintStack(stackTrace: stackTrace, label: flow);
      }
    }
  }

  Widget _buildRecentSaleTile(LocalSaleRecord sale) {
    final canVoidSales = ref.watch(isMerchantOwnerProvider).valueOrNull ?? true;
    return RecentSaleTile(
      sale: sale,
      onEdit: () => _showEditSaleDialog(sale),
      onVoid: canVoidSales ? () => _showVoidSaleDialog(sale) : null,
    );
  }

  String _calculateTotal(List<LocalInventoryItem> items) {
    final cart = ref.read(salesCartProvider);
    final itemById = {for (final item in items) item.id: item};
    int totalMinor = 0;
    for (final entry in cart.qtyByItemId.entries) {
      final qty = entry.value;
      if (qty <= 0) continue;
      final item = itemById[itemIdFromKey(entry.key)];
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
    final method =
        paymentMethodLabel ?? ref.read(salesCartProvider).paymentMethod;
    final totalAmount = _calculateTotal(items);
    try {
      await ref.read(salesControllerProvider.notifier).recordSale(
            paymentMethodLabel: method,
            lines: lines,
            note: note,
          );
      if (!mounted) return false;
      ref.invalidate(inventoryControllerProvider);
      _resetDraftAfterSale();
      // Cash sales are confirmed locally and immediately, so we surface the
      // success animation here. MoMo flows show their own success sheet after
      // payment confirmation in `_recordSaleWithPaystack*`.
      if (method == 'cash' && mounted) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          isDismissible: false,
          enableDrag: false,
          builder: (_) => SaleSuccessSheet(
            amount: totalAmount,
            method: 'cash',
          ),
        );
      }
      // Notify for all non-Paystack sales (cash, card, etc.).
      // Paystack sales fire their own notification after payment confirmation.
      final prefs = ref.read(notificationPrefsProvider).valueOrNull;
      if (mounted && prefs?.paymentEventsEnabled == true) {
        const android = AndroidNotificationDetails(
          'payment_events',
          'Payment events',
          channelDescription: 'Payment confirmation and failure alerts',
          importance: Importance.high,
          priority: Priority.high,
          color: AppColors.forest,
        );
        await ref.read(notificationsServiceProvider).showNow(
              id: 2202,
              type: AppNotificationType.paystack,
              title: 'Sale recorded',
              body:
                  '${method.isNotEmpty ? _friendlyMethod(method) : 'Sale'} · ₵$totalAmount',
              android: android,
              route: AppRoute.sales.path,
            );
      }
      return true;
    } catch (error, stackTrace) {
      _logSaleFlowError('recordSale', error, stackTrace);
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeSaleSyncError(error))),
      );
      return false;
    }
  }

  static String _friendlyMethod(String method) {
    return switch (method.toLowerCase()) {
      'cash' => 'Cash',
      'card' => 'Card',
      'mobile_money' || 'momo' => 'Mobile Money',
      _ => method,
    };
  }

  Future<void> _recordSaleWithPaystackLink({
    required List<LocalInventoryItem> items,
    required String paymentMethodLabel,
  }) async {
    if (!await _ensureCartReadyForOnlinePayment(items)) return;

    final lines = _buildSaleDraftLines(items);
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item quantity.')),
      );
      return;
    }

    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    var saleSaved = false;
    bool loadingShown = false;

    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) =>
            const _PaymentLoadingDialog(message: 'Generating QR code...'),
      );
      loadingShown = true;
    }

    try {
      final saleId = await ref
          .read(salesControllerProvider.notifier)
          .recordSaleReturningId(
            paymentMethodLabel: paymentMethodLabel,
            lines: lines,
            note: note,
            awaitBackendSaleForPayment: true,
          );
      saleSaved = true;
      if (!mounted) return;

      final initiated =
          await ref.read(salesPaymentsApiProvider).initiateSalePayment(saleId);
      if (!mounted) return;

      if (loadingShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingShown = false;
      }

      ref.invalidate(inventoryControllerProvider);
      _resetDraftAfterSale();
      await _showPaystackLinkDialog(
        checkoutUrl: initiated.checkoutUrl,
        saleId: initiated.saleId,
        amount: initiated.amount,
        currency: initiated.currency,
      );
    } catch (error, stackTrace) {
      _logSaleFlowError('paystackQrLink', error, stackTrace);
      if (loadingShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingShown = false;
      }

      if (!mounted) return;
      if (saleSaved) {
        ref.invalidate(inventoryControllerProvider);
        _resetDraftAfterSale();
      } else if (error is TimeoutException || error is StateError) {
        // Local sale row exists but Paystack flow aborted mid-flight.
        ref.invalidate(inventoryControllerProvider);
      }
      final isPaystackNotConnected = _isPaystackNotConnectedError(error);
      if (isPaystackNotConnected) {
        await _showPaystackSetupPrompt();
        return;
      }
      final message = saleSaved
          ? 'Sale recorded, but payment link failed: ${humanizeSalesPaymentsError(error)}'
          : humanizeSaleSyncError(error);
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
    if (!await _ensureCartReadyForOnlinePayment(items)) return;

    final lines = _buildSaleDraftLines(items);
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item quantity.')),
      );
      return;
    }

    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    var saleSaved = false;
    bool loadingShown = false;

    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) =>
            const _PaymentLoadingDialog(message: 'Setting up payment...'),
      );
      loadingShown = true;
    }

    try {
      final saleId = await ref
          .read(salesControllerProvider.notifier)
          .recordSaleReturningId(
            paymentMethodLabel: paymentMethodLabel,
            lines: lines,
            note: note,
            awaitBackendSaleForPayment: true,
          );
      saleSaved = true;
      if (!mounted) return;

      if (loadingShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingShown = false;
      }

      ref.invalidate(inventoryControllerProvider);
      _resetDraftAfterSale();

      var confirmed = false;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) {
          final mode = ref
              .read(paystackConnectionProvider)
              .valueOrNull
              ?.mode
              .toLowerCase();
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

      final prefs = ref.read(notificationPrefsProvider).valueOrNull;
      if (prefs?.paymentEventsEnabled == true) {
        const android = AndroidNotificationDetails(
          'payment_events',
          'Payment events',
          channelDescription: 'Payment confirmation and failure alerts',
          importance: Importance.high,
          priority: Priority.high,
          color: AppColors.forest,
        );
        await ref.read(notificationsServiceProvider).showNow(
              id: 2201,
              type: AppNotificationType.paystack,
              title: 'Payment successful',
              body: 'Paystack · ₵ $totalAmount',
              android: android,
              route: AppRoute.sales.path,
              entityId: saleId,
            );
      }

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
    } catch (error, stackTrace) {
      _logSaleFlowError('paystackMomoNumber', error, stackTrace);
      if (loadingShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingShown = false;
      }

      if (!mounted) return;
      if (saleSaved) {
        ref.invalidate(inventoryControllerProvider);
        _resetDraftAfterSale();
      } else if (error is TimeoutException || error is StateError) {
        ref.invalidate(inventoryControllerProvider);
      }
      final isPaystackNotConnected = _isPaystackNotConnectedError(error);
      if (isPaystackNotConnected) {
        await _showPaystackSetupPrompt();
        return;
      }
      final message = saleSaved
          ? 'Sale recorded, but MoMo prompt failed: ${humanizeSalesPaymentsError(error)}'
          : humanizeSaleSyncError(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  bool _isPaystackNotConnectedError(Object error) {
    if (error is! DioException) return false;
    if (error.response?.statusCode != 409) return false;
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = (data['detail'] as String? ?? '').toLowerCase();
      return detail.contains('paystack') && detail.contains('connect');
    }
    return false;
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
    final aggregatedQty = <String, int>{};
    final prices = <String, String>{};

    for (final entry in cart.qtyByItemId.entries) {
      final qty = entry.value;
      if (qty <= 0) continue;
      final itemId = itemIdFromKey(entry.key);
      final item = itemById[itemId];
      if (item == null) continue;
      aggregatedQty[itemId] = (aggregatedQty[itemId] ?? 0) + qty;
      final override = cart.priceOverrideByItemId[entry.key] ??
          cart.priceOverrideByItemId[itemId];
      if (override != null) {
        prices[itemId] = override;
      } else {
        prices.putIfAbsent(itemId, () => item.defaultPrice);
      }
    }

    return aggregatedQty.entries
        .map(
          (entry) => SaleDraftLine(
            itemId: entry.key,
            quantity: entry.value,
            unitPrice: prices[entry.key] ?? itemById[entry.key]!.defaultPrice,
          ),
        )
        .toList(growable: false);
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
        formatMajor: (val, {symbol = 'GHS '}) => SalesUiUtils.formatMinor(
            SalesUiUtils.parseTotal(val),
            symbol: symbol),
        formatMinor: SalesUiUtils.formatMinor,
        moneyToMinor: SalesUiUtils.moneyToMinor,
        onProceedToCheckout: () async {
          if (!mounted) return;
          await _showCheckoutSheet(
            items: items,
            itemCount: ref
                .read(salesCartProvider)
                .qtyByItemId
                .values
                .fold(0, (a, b) => a + b),
            totalAmount: _calculateTotal(items),
            isBusy: false,
          );
        },
      ),
    );
  }

  Future<void> _showPriceOverrideDialog(LocalInventoryItem item) async {
    final cart = ref.read(salesCartProvider);
    final key = item.id;
    final ctrl = TextEditingController(
      text: cart.priceOverrideByItemId[key] ?? item.defaultPrice,
    );
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
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              labelText: 'Unit price (GHS)',
              prefixText: 'GHS ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(salesCartProvider.notifier).removeOverride(key);
                Navigator.of(ctx).pop();
              },
              child: const Text('Reset to default'),
            ),
            FilledButton(
              onPressed: () {
                final raw = ctrl.text.trim();
                final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
                if (match == null || double.tryParse(raw) == 0) return;
                ref.read(salesCartProvider.notifier).overridePrice(key, raw);
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
    LocalSaleEditable? editable;
    try {
      editable = await ref
          .read(salesControllerProvider.notifier)
          .loadSaleEditable(saleId: sale.saleId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeSaleSyncError(error))),
      );
      return;
    }
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
      builder: (_) => EditSaleSheet(sale: sale, editable: editable!),
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
      final wasMobileMoney = sale.paymentMethodLabel == 'mobile_money';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasMobileMoney
                ? 'Sale voided. Please return the Mobile Money payment to the customer manually.'
                : 'Sale voided.',
          ),
          duration: Duration(seconds: wasMobileMoney ? 6 : 3),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeSaleSyncError(error))),
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

class _SliverTabDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabDelegate({required this.activeTab, required this.child});
  final SalesViewTab activeTab;
  final Widget child;

  @override
  double get minExtent => 78;
  @override
  double get maxExtent => 78;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      // Match Sales hero background so the rounded cutouts show green.
      color: const Color(0xFF071D11),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: AppRadii.heroRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: overlapsContent
                ? const [
                    BoxShadow(
                      color: Color(0x1F0F172A),
                      blurRadius: 28,
                      offset: Offset(0, -8),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: SizedBox(height: maxExtent - 22, child: child),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverTabDelegate oldDelegate) =>
      oldDelegate.activeTab != activeTab;
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.forest
              : AppColors.forest.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.forest
                : AppColors.forest.withValues(alpha: 0.22),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.forest,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PaymentLoadingDialog extends StatelessWidget {
  const _PaymentLoadingDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppShadows.elevated,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: AppColors.forest,
                    strokeWidth: 3.5,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
