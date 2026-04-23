import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/product_image_catalog.dart';
import '../../inventory/data/inventory_api.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../data/sales_repository.dart';
import '../providers/sales_providers.dart';

enum _SaleAction { edit, voidSale }

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
    final allItems = (inventoryAsync.valueOrNull ?? const <LocalInventoryItem>[])
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

    return Scaffold(
      body: Column(
        children: [
          // ── Green gradient header ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: AppGradients.hero),
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
                            'Record Sale',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Add items, choose payment & complete sale',
                            style: TextStyle(
                              color: Color(0xFFB2D8CE),
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
                            'Total Amount',
                            style: TextStyle(
                              color: Color(0xFFB2D8CE),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'GHS $totalAmount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
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
                borderRadius: BorderRadius.vertical(top: AppRadii.heroRadius),
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: AppRadii.heroRadius),
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
                          padding:
                              const EdgeInsets.fromLTRB(16, 20, 16, 100),
                          children: [
                            // Payment method card
                            _PaymentCard(
                              paymentMethod: _paymentMethod,
                              onSelected: (v) =>
                                  setState(() => _paymentMethod = v),
                            ),
                            const SizedBox(height: 14),

                            // Collapsible note
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _showNote = !_showNote),
                              child: Row(
                                children: [
                                  Icon(
                                    _showNote
                                        ? Icons.expand_less_rounded
                                        : Icons.note_alt_outlined,
                                    size: 15,
                                    color: AppColors.muted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _showNote
                                        ? 'Hide note'
                                        : 'Add a note (optional)',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
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

                            // Items section header with inline search
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Select items and quantity',
                                    style: TextStyle(
                                      color: AppColors.ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                _CompactSearch(
                                  controller: _searchCtrl,
                                  hasQuery: _searchQuery.isNotEmpty,
                                  onChanged: (v) =>
                                      setState(() => _searchQuery = v.trim()),
                                  onClear: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                ),
                              ],
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
                                        'Selected (${selectedItems.length})'),
                                const SizedBox(height: 8),
                                ...selectedItems.map((item) {
                                  return _ItemCard(
                                    item: item,
                                    qty: _qtyByItemId[item.id] ?? 0,
                                    priceOverride:
                                        _priceOverrideByItemId[item.id],
                                    isSelected: true,
                                    onMinus: () => setState(() =>
                                        _qtyByItemId[item.id] =
                                            (_qtyByItemId[item.id] ?? 1) - 1),
                                    onPlus: () => setState(() =>
                                        _qtyByItemId[item.id] =
                                            (_qtyByItemId[item.id] ?? 0) + 1),
                                    onPriceTap: () =>
                                        _showPriceOverrideDialog(item),
                                  );
                                }),
                                const SizedBox(height: 10),
                              ],
                              if (unselectedItems.isNotEmpty) ...[
                                if (selectedItems.isNotEmpty)
                                  const _SectionLabel(label: 'All items'),
                                if (selectedItems.isNotEmpty)
                                  const SizedBox(height: 8),
                                ...unselectedItems.map((item) {
                                  return _ItemCard(
                                    item: item,
                                    qty: 0,
                                    priceOverride: null,
                                    isSelected: false,
                                    onMinus: () {},
                                    onPlus: () => setState(
                                        () => _qtyByItemId[item.id] = 1),
                                    onPriceTap: () =>
                                        _showPriceOverrideDialog(item),
                                  );
                                }),
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

                            // Recent sales
                            Row(
                              children: [
                                Text(
                                  'Recent Sales',
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
                            else if (recentSales.isEmpty)
                              _EmptyCard(
                                icon: Icons.receipt_long_outlined,
                                message: _showVoided
                                    ? 'No sales found yet.'
                                    : 'No sales yet. Record your first sale above.',
                              )
                            else
                              ...recentSales.take(8).map(_buildRecentSaleTile),
                          ],
                        ),
                      ),

                      // ── Persistent bottom action bar ────────────────
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _BottomBar(
                          itemCount: itemCount,
                          totalAmount: totalAmount,
                          hasItems: hasItems,
                          isBusy: isBusy,
                          onConfirm: () => _recordSale(items: allItems),
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
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(
          'GHS ${sale.totalAmount}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            decoration: sale.isVoided ? TextDecoration.lineThrough : null,
            letterSpacing: -0.2,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sale.isVoided ? 'voided' : sale.syncStatus,
              style: TextStyle(
                color: sale.isVoided ? AppColors.danger : syncColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
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
    final minor = parts.length == 2
        ? (int.tryParse(parts[1].padRight(2, '0')) ?? 0)
        : 0;
    return major * 100 + minor;
  }

  int _moneyToMinor(String value) {
    final raw = value.trim();
    final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
    if (match == null) return 0;
    final parts = raw.split('.');
    final major = int.parse(parts[0]);
    final decimals =
        parts.length == 2 ? parts[1].padRight(2, '0') : '00';
    return (major * 100) + int.parse(decimals);
  }

  Future<void> _recordSale(
      {required List<LocalInventoryItem> items}) async {
    final itemById = {for (final item in items) item.id: item};
    final lines = <SaleDraftLine>[];
    for (final entry in _qtyByItemId.entries) {
      final qty = entry.value;
      if (qty <= 0) continue;
      final item = itemById[entry.key];
      if (item == null) continue;
      final price =
          _priceOverrideByItemId[entry.key] ?? item.defaultPrice;
      lines.add(
          SaleDraftLine(itemId: item.id, quantity: qty, unitPrice: price));
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select at least one item quantity.')),
      );
      return;
    }
    final note =
        _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    try {
      await ref.read(salesControllerProvider.notifier).recordSale(
            paymentMethodLabel: _paymentMethod,
            lines: lines,
            note: note,
          );
      ref.invalidate(inventoryControllerProvider);
      setState(() {
        _qtyByItemId.clear();
        _priceOverrideByItemId.clear();
        _searchQuery = '';
        _showNote = false;
      });
      _noteCtrl.clear();
      _searchCtrl.clear();
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
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,2}'))
            ],
            decoration: const InputDecoration(
              labelText: 'Unit price (GHS)',
              prefixText: 'GHS ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(
                    () => _priceOverrideByItemId.remove(item.id));
                Navigator.of(ctx).pop();
              },
              child: const Text('Reset to default'),
            ),
            FilledButton(
              onPressed: () {
                final raw = ctrl.text.trim();
                final match =
                    RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
                if (match == null || double.tryParse(raw) == 0) return;
                setState(
                    () => _priceOverrideByItemId[item.id] = raw);
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
        const SnackBar(
            content: Text('Sale cannot be edited anymore.')),
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
                      decoration: const InputDecoration(
                          labelText: 'Payment method'),
                      items: const [
                        DropdownMenuItem(
                            value: 'cash', child: Text('Cash')),
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
                              setDialogState(
                                  () => paymentMethod = value);
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
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    line.itemName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    'Unit GHS ${line.unitPrice} | Max ${line.maxQuantity}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            _CircleQtyBtn(
                              icon: Icons.remove_rounded,
                              enabled: !isSaving && selectedQty > 1,
                              onTap: () => setDialogState(
                                () => qtyByItem[line.itemId] =
                                    selectedQty - 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10),
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
                              enabled: !isSaving &&
                                  selectedQty < line.maxQuantity,
                              onTap: () => setDialogState(
                                () => qtyByItem[line.itemId] =
                                    selectedQty + 1,
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
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
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
                                    quantity: qtyByItem[line.itemId] ??
                                        line.quantity,
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
                              const SnackBar(
                                  content: Text('Sale updated.')),
                            );
                          } catch (error) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      humanizeInventoryError(error))),
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
                onPressed: () =>
                    Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(true),
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

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.paymentMethod,
    required this.onSelected,
  });

  final String paymentMethod;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Payment Method',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PaymentTile(
                  label: 'Cash',
                  icon: Icons.account_balance_wallet_rounded,
                  selected: paymentMethod == 'cash',
                  onTap: () => onSelected('cash'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PaymentTile(
                  label: 'Mobile\nMoney',
                  icon: Icons.phone_android_rounded,
                  selected: paymentMethod == 'mobile_money',
                  onTap: () => onSelected('mobile_money'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PaymentTile(
                  label: 'Bank\nTransfer',
                  icon: Icons.account_balance_rounded,
                  selected: paymentMethod == 'bank_transfer',
                  onTap: () => onSelected('bank_transfer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.forest.withValues(alpha: 0.10)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.forest : AppColors.muted,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.forest : AppColors.ink,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Item card ────────────────────────────────────────────────────────────────

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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(
          color: isSelected ? AppColors.forest : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: AppShadows.subtle,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            ItemImage(
              imageAsset: item.imageAsset,
              size: 44,
              fallbackIcon: Icons.inventory_2_outlined,
              borderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(width: 12),

            // Name + price + stock
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  GestureDetector(
                    onTap: onPriceTap,
                    child: Row(
                      children: [
                        Text(
                          'GHS $displayPrice',
                          style: TextStyle(
                            color: hasOverride
                                ? AppColors.warning
                                : AppColors.forest,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (hasOverride) ...[
                          const SizedBox(width: 4),
                          const Text(
                            '(custom)',
                            style: TextStyle(
                                color: AppColors.warning, fontSize: 11),
                          ),
                        ],
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'In stock: ${item.quantityOnHand}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Qty controls
            Row(
              mainAxisSize: MainAxisSize.min,
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
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: enabled ? AppColors.forest : const Color(0xFFDDDDDD),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 15,
          color: enabled ? AppColors.forest : AppColors.muted,
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
    required this.hasItems,
    required this.isBusy,
    required this.onConfirm,
  });

  final int itemCount;
  final String totalAmount;
  final bool hasItems;
  final bool isBusy;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Cart icon
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: AppColors.forest,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),

              // Item count + total
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'GHS $totalAmount',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // CTA button
              SizedBox(
                height: 44,
                child: FilledButton.icon(
                  onPressed: (hasItems && !isBusy) ? onConfirm : null,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                  iconAlignment: IconAlignment.end,
                  label: Text(isBusy ? 'Saving…' : 'Review Sale'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forestDark,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCCCCCC),
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

// ── Compact search ────────────────────────────────────────────────────────────

class _CompactSearch extends StatelessWidget {
  const _CompactSearch({
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
    return SizedBox(
      width: 148,
      height: 36,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13, color: AppColors.ink),
        decoration: InputDecoration(
          hintText: 'Search items...',
          hintStyle:
              const TextStyle(fontSize: 13, color: AppColors.muted),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 17, color: AppColors.muted),
          suffixIcon: hasQuery
              ? GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close_rounded,
                      size: 15, color: AppColors.muted),
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.forest, width: 1.2),
          ),
        ),
      ),
    );
  }
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
