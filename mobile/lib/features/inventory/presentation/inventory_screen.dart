import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../data/local/kv_cache_repository.dart';
import '../../../shared/widgets/data_freshness_label.dart';
import '../../sales/presentation/widgets/hero_stat_chip.dart';
import '../../../shared/widgets/stale_banner.dart';
import '../../../shared/widgets/product_image_catalog.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../data/inventory_api.dart';
import '../data/inventory_repository.dart';
import '../providers/inventory_providers.dart';
import 'widgets/inventory_header.dart';
import 'widgets/inventory_item_card.dart';
import 'widgets/inventory_sheets.dart';

// â”€â”€â”€ helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

int _priceToMinor(String value) {
  final parts = value.trim().split('.');
  final major = int.tryParse(parts[0]) ?? 0;
  final raw = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
  return (major * 100) + (int.tryParse(raw.substring(0, 2)) ?? 0);
}

String _fmtMoney(int minor) {
  final major = minor ~/ 100;
  final cents = (minor % 100).toString().padLeft(2, '0');
  return '\u20B5$major.$cents';
}

// â”€â”€â”€ screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  bool _showForm = false;
  bool _showArchived = false;
  String _searchQuery = '';
  String? _filterCategory;
  String? _newItemUrl;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _skuCtrl.dispose();
    _categoryCtrl.dispose();
    _thresholdCtrl.dispose();
    _qtyCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryControllerProvider);
    final items = itemsAsync.valueOrNull ?? const <LocalInventoryItem>[];
    final activeItems =
        items.where((item) => item.isActive).toList(growable: false);
    final archivedItems =
        items.where((item) => !item.isActive).toList(growable: false);

    // O(n) stats pass
    int totalValueMinor = 0;
    int lowStockCount = 0;
    final categories = <String>{};
    for (final item in activeItems) {
      totalValueMinor += _priceToMinor(item.defaultPrice) * item.quantityOnHand;
      if (item.lowStockThreshold != null &&
          item.quantityOnHand <= item.lowStockThreshold!) {
        lowStockCount++;
      }
    }
    for (final item in items) {
      if (item.category != null) categories.add(item.category!);
    }

    // Filter
    final q = _searchQuery.toLowerCase();
    bool matchesFilters(LocalInventoryItem item) {
      final matchQuery = q.isEmpty ||
          item.name.toLowerCase().contains(q) ||
          (item.category?.toLowerCase().contains(q) ?? false) ||
          (item.sku?.toLowerCase().contains(q) ?? false);
      final matchCat =
          _filterCategory == null || item.category == _filterCategory;
      return matchQuery && matchCat;
    }

    final filteredActive =
        activeItems.where(matchesFilters).toList(growable: false);
    final filteredArchived =
        archivedItems.where(matchesFilters).toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.canvas,

      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddItemSheet(context),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    
      body: Column(
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
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF041C0B),
                              Color(0xFF083A1A),
                              Color(0xFF0F5A30),
                              Color(0xFF196E3D),
                            ],
                            stops: [0.0, 0.28, 0.62, 1.0],
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                          ),
                        ),
                      ),
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
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF010A04).withValues(alpha: 0.36),
                              Colors.transparent,
                              const Color(0xFF010A04).withValues(alpha: 0.12),
                            ],
                            stops: const [0.0, 0.50, 1.0],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
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
                      'assets/images/inventory.png',
                      width: 185,
                      height: 185,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(width: 185, height: 185),
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
                                Icons.inventory_2_rounded,
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
                                  'Inventory',
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
                                  kvKey: KvCacheRepository.kInventoryTs,
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
                                'STOCK VALUE',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _fmtMoney(totalValueMinor),
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
                              icon: Icons.inventory_2_rounded,
                              value: '${activeItems.length}',
                              label: 'active items',
                            ),
                            const SizedBox(width: 8),
                            HeroStatChip(
                              icon: Icons.warning_amber_rounded,
                              value: '$lowStockCount',
                              label: 'low stock',
                            ),
                            const SizedBox(width: 8),
                            HeroStatChip(
                              icon: Icons.category_rounded,
                              value: '${categories.length}',
                              label: 'categories',
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
                    screenKey: 'inventory',
                    kvKey: KvCacheRepository.kInventoryTs,
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
                        child: RefreshIndicator(
                          onRefresh: () => ref
                              .read(inventoryControllerProvider.notifier)
                              .refresh(),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 100),
                            children: [

                        _SearchBar(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                        if (categories.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _CategoryFilter(
                            categories: categories.toList()..sort(),
                            selected: _filterCategory,
                            onChanged: (c) =>
                                setState(() => _filterCategory = c),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Text(
                              filteredActive.isEmpty && q.isNotEmpty
                                  ? 'NO MATCHES'
                                  : 'ACTIVE ITEMS',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: AppColors.muted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            if (items.isNotEmpty)
                              Text(
                                '${filteredActive.length} of ${activeItems.length}',
                                style: const TextStyle(
                                  color: AppColors.mutedSoft,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (itemsAsync.isLoading && items.isEmpty)
                          const _LoadingCard()
                        else if (itemsAsync.hasError)
                          _ErrorCard(
                            message: humanizeInventoryError(itemsAsync.error!),
                          )
                        else if (items.isEmpty)
                          _EmptyCard(
                            onAdd: () => setState(() => _showForm = true),
                          )
                        else if (filteredActive.isEmpty && activeItems.isEmpty)
                          _EmptyActiveCard(
                            archivedCount: archivedItems.length,
                          )
                        else if (filteredActive.isEmpty)
                          const _NoMatchCard()
                        else
                          ...filteredActive.map(
                            (item) => InventoryItemCard(
                              item: item,
                              onTap: () => _openItemDetail(item),
                            ),
                          ),
                        if (archivedItems.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _ArchivedSection(
                            archivedCount: archivedItems.length,
                            visibleCount: filteredArchived.length,
                            expanded: _showArchived,
                            onToggle: () => setState(
                              () => _showArchived = !_showArchived,
                            ),
                          ),
                          if (_showArchived) ...[
                            const SizedBox(height: 10),
                            if (filteredArchived.isEmpty)
                              const _ArchivedNoMatchCard()
                            else
                              ...filteredArchived.map(
                                (item) => InventoryItemCard(
                                  item: item,
                                  onTap: () => _openItemDetail(item),
                                ),
                              ),
                          ],
                        ],
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
    );
  }

  Future<void> _saveItem() async {
    final name = _nameCtrl.text.trim();
    final price = _priceCtrl.text.trim();
    if (name.isEmpty || price.isEmpty) {
      _msg('Name and price are required.');
      return;
    }
    final initialQtyText = _qtyCtrl.text.trim();
    final initialQty =
        initialQtyText.isEmpty ? 0 : int.tryParse(initialQtyText);
    if (initialQtyText.isNotEmpty && (initialQty == null || initialQty < 0)) {
      _msg('Enter a valid initial stock quantity.');
      return;
    }
    try {
      await ref.read(inventoryControllerProvider.notifier).createItem(
            name: name,
            defaultPrice: price,
            sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
            category: _categoryCtrl.text.trim().isEmpty
                ? null
                : _categoryCtrl.text.trim(),
            lowStockThreshold: int.tryParse(_thresholdCtrl.text.trim()),
            initialQuantity: initialQty ?? 0,
            imageUrl: _newItemUrl,
          );
      _nameCtrl.clear();
      _priceCtrl.clear();
      _skuCtrl.clear();
      _categoryCtrl.clear();
      _thresholdCtrl.clear();
      _qtyCtrl.clear();
      if (!mounted) return;
      setState(() {
        _showForm = false;
        _newItemUrl = null;
      });
      _msg('Item added to inventory.');
    } catch (error) {
      if (!mounted) return;
      _msg(humanizeInventoryError(error));
    }
  }

  void _openEdit(LocalInventoryItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(item: item, ref: ref),
    );
  }

  void _openStockIn(LocalInventoryItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StockInSheet(item: item, ref: ref),
    );
  }

  void _openAdjust(LocalInventoryItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdjustSheet(item: item, ref: ref),
    );
  }

  Future<void> _archiveItem(LocalInventoryItem item) async {
    if (item.quantityOnHand > 0) {
      _msg(archiveRequiresZeroStockMessage);
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _ArchiveConfirmSheet(itemName: item.name),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await ref
          .read(inventoryControllerProvider.notifier)
          .archiveItem(itemId: item.id);
      if (!mounted) return;
      setState(() => _showArchived = true);
      _msg('${item.name} archived.');
    } catch (error) {
      if (!mounted) return;
      _msg(humanizeInventoryError(error));
    }
  }

  Future<void> _restoreItem(LocalInventoryItem item) async {
    try {
      await ref
          .read(inventoryControllerProvider.notifier)
          .restoreItem(itemId: item.id);
      if (!mounted) return;
      _msg('${item.name} restored to active inventory.');
    } catch (error) {
      if (!mounted) return;
      _msg(humanizeInventoryError(error));
    }
  }

  Future<void> _deleteItem(LocalInventoryItem item) async {
    final confirmed = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _DeleteConfirmSheet(itemName: item.name),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await ref
          .read(inventoryControllerProvider.notifier)
          .deleteItem(itemId: item.id);
      if (!mounted) return;
      _msg('${item.name} permanently deleted.');
    } catch (error) {
      if (!mounted) return;
      _msg(humanizeInventoryError(error));
    }
  }

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

// â”€â”€â”€ header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€


// â”€â”€â”€ add item accordion â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AddItemAccordion extends StatelessWidget {
  const _AddItemAccordion({
    required this.expanded,
    required this.nameCtrl,
    required this.priceCtrl,
    required this.skuCtrl,
    required this.categoryCtrl,
    required this.thresholdCtrl,
    required this.qtyCtrl,
    required this.isLoading,
    required this.selectedImage,
    required this.onToggle,
    required this.onSave,
    required this.onImageChanged,
  });

  final bool expanded;
  final TextEditingController nameCtrl,
      priceCtrl,
      skuCtrl,
      categoryCtrl,
      thresholdCtrl,
      qtyCtrl;
  final bool isLoading;
  final String? selectedImage;
  final VoidCallback onToggle, onSave;
  final ValueChanged<String?> onImageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border:
            Border.all(color: AppColors.borderStrong.withValues(alpha: 0.45)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: expanded
                ? const BorderRadius.vertical(top: Radius.circular(AppRadii.sm))
                : BorderRadius.circular(AppRadii.sm),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_box_rounded,
                      color: AppColors.forest,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add New Item',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          'Name, price, stock & more',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Required fields label
                  const _FieldGroup(label: 'Required'),
                  const SizedBox(height: 8),
                  InventoryIField(
                    controller: nameCtrl,
                    label: 'Item Name',
                    hint: 'e.g. Sachet Water, Indomie Noodles',
                    prefixIcon: Icons.label_rounded,
                  ),
                  const SizedBox(height: 10),
                  InventoryIField(
                    controller: priceCtrl,
                    label: 'Selling Price (â‚µ)',
                    hint: 'e.g. 5.00',
                    prefixIcon: Icons.payments_rounded,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),

                  // Stock fields
                  const _FieldGroup(label: 'Stock'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InventoryIField(
                          controller: qtyCtrl,
                          label: 'Initial Qty',
                          hint: '0',
                          prefixIcon: Icons.inventory_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InventoryIField(
                          controller: thresholdCtrl,
                          label: 'Low Stock Alert',
                          hint: 'e.g. 10',
                          prefixIcon: Icons.warning_amber_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Optional fields
                  const _FieldGroup(label: 'Optional'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InventoryIField(
                          controller: categoryCtrl,
                          label: 'Category',
                          hint: 'e.g. Drinks, Snacks',
                          prefixIcon: Icons.category_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InventoryIField(
                          controller: skuCtrl,
                          label: 'SKU / Code',
                          hint: 'e.g. SKU-001',
                          prefixIcon: Icons.qr_code_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ProductImagePicker(
                    selected: selectedImage,
                    onChanged: onImageChanged,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : onSave,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: Text(
                          isLoading ? 'Saving...' : 'Save Item to Inventory'),
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

class _FieldGroup extends StatelessWidget {
  const _FieldGroup({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(height: 1)),
      ],
    );
  }
}

// â”€â”€â”€ search & filter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search items by name, category or SKUâ€¦',
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: AppColors.forest,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.4),
        ),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: 'All',
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          ...categories.map(
            (c) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _Chip(
                label: c,
                selected: selected == c,
                onTap: () => onChanged(selected == c ? null : c),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.mint : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.border,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.forest : AppColors.muted,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€ item card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    this.onEdit,
    this.onStockIn,
    this.onAdjust,
    this.onArchive,
    this.onRestore,
    this.onDelete,
  });

  final LocalInventoryItem item;
  final VoidCallback? onEdit;
  final VoidCallback? onStockIn;
  final VoidCallback? onAdjust;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final hasThreshold = item.lowStockThreshold != null;
    final isOut = item.quantityOnHand == 0;
    final isLow = hasThreshold &&
        item.quantityOnHand <= item.lowStockThreshold! &&
        !isOut;
    final hasIssue = isOut || isLow;
    final Color statusColor = isOut ? AppColors.danger : AppColors.warning;

    final double progress = hasThreshold && item.lowStockThreshold! > 0
        ? (item.quantityOnHand / (item.lowStockThreshold! * 2.0))
            .clamp(0.0, 1.0)
        : item.quantityOnHand > 0
            ? 1.0
            : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ItemImage(
                  imageUrl: item.imageUrl,
                  size: 48,
                  fallbackIcon: Icons.inventory_2_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!item.isActive) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.dangerSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ARCHIVED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: AppColors.ink,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            '₵${item.defaultPrice}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                              color: AppColors.forestDark,
                            ),
                          ),
                          if (item.category != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                color: AppColors.border,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                item.category!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (item.sku != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'SKU ${item.sku}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.mutedSoft,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${item.quantityOnHand}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: hasIssue ? statusColor : AppColors.ink,
                        height: 1,
                      ),
                    ),
                    const Text(
                      'units',
                      style: TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                    if (hasIssue) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isOut ? 'Out' : 'Low',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (hasThreshold)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOut
                        ? AppColors.danger
                        : isLow
                            ? AppColors.warning
                            : AppColors.forest,
                  ),
                ),
              ),
            ),
          const Divider(height: 1, color: AppColors.border),
          IntrinsicHeight(
            child: Row(
              children: [
                if (onEdit != null)
                  Expanded(
                    child: _ActionBtn(
                      label: 'Edit',
                      icon: Icons.edit_rounded,
                      color: AppColors.forestDark,
                      onTap: onEdit!,
                    ),
                  ),
                if (item.isActive && onStockIn != null) ...[
                  const VerticalDivider(width: 1, color: AppColors.border),
                  Expanded(
                    child: _ActionBtn(
                      label: 'Stock In',
                      icon: Icons.add_box_rounded,
                      color: AppColors.forest,
                      onTap: onStockIn!,
                    ),
                  ),
                ],
                if (item.isActive && onAdjust != null) ...[
                  const VerticalDivider(width: 1, color: AppColors.border),
                  Expanded(
                    child: _ActionBtn(
                      label: 'Adjust',
                      icon: Icons.tune_rounded,
                      color: const Color(0xFFD97706),
                      onTap: onAdjust!,
                    ),
                  ),
                ],
                if (item.isActive && onArchive != null) ...[
                  const VerticalDivider(width: 1, color: AppColors.border),
                  Expanded(
                    child: _ActionBtn(
                      label: 'Archive',
                      icon: Icons.archive_outlined,
                      color: const Color(0xFF6B7280),
                      onTap: onArchive!,
                    ),
                  ),
                ],
                if (!item.isActive && onRestore != null)
                  Expanded(
                    child: _ActionBtn(
                      label: 'Restore',
                      icon: Icons.unarchive_outlined,
                      color: AppColors.forestDark,
                      onTap: onRestore!,
                    ),
                  ),
                if (!item.isActive && onDelete != null) ...[
                  const VerticalDivider(width: 1, color: AppColors.border),
                  Expanded(
                    child: _ActionBtn(
                      label: 'Delete',
                      icon: Icons.delete_forever_rounded,
                      color: AppColors.danger,
                      onTap: onDelete!,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
      ),
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// â”€â”€â”€ bottom sheets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.item, required this.ref});
  final LocalInventoryItem item;
  final WidgetRef ref;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _thresholdCtrl;
  late String? _imageUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _priceCtrl = TextEditingController(text: widget.item.defaultPrice);
    _skuCtrl = TextEditingController(text: widget.item.sku ?? '');
    _categoryCtrl = TextEditingController(text: widget.item.category ?? '');
    _thresholdCtrl = TextEditingController(
        text: widget.item.lowStockThreshold?.toString() ?? '');
    _imageUrl = widget.item.imageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _skuCtrl.dispose();
    _categoryCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Edit Item',
      subtitle: widget.item.name,
      icon: Icons.edit_rounded,
      iconColor: AppColors.forestDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InventoryIField(
              controller: _nameCtrl,
              label: 'Item Name',
              hint: 'e.g. Sachet Water',
              prefixIcon: Icons.label_rounded),
          const SizedBox(height: 10),
          InventoryIField(
            controller: _priceCtrl,
            label: 'Selling Price (â‚µ)',
            hint: '0.00',
            prefixIcon: Icons.payments_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InventoryIField(
                    controller: _categoryCtrl,
                    label: 'Category',
                    hint: 'e.g. Drinks',
                    prefixIcon: Icons.category_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InventoryIField(
                    controller: _skuCtrl,
                    label: 'SKU',
                    hint: 'optional',
                    prefixIcon: Icons.qr_code_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InventoryIField(
            controller: _thresholdCtrl,
            label: 'Low Stock Alert Threshold',
            hint: 'e.g. 10',
            prefixIcon: Icons.warning_amber_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          ProductImagePicker(
            selected: _imageUrl,
            onChanged: (v) => setState(() => _imageUrl = v),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(14),
            child: Text(
              widget.item.isActive
                  ? 'Use the Archive item action on the inventory card to remove this item from future sales.'
                  : 'This item is archived. Use Restore item on the inventory card to make it available for sales again.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 18),
          InventorySaveBtn(
            label: _saving ? 'Saving...' : 'Save Changes',
            onTap: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final thresholdText = _thresholdCtrl.text.trim();
      final threshold = thresholdText.isEmpty
          ? widget.item.lowStockThreshold
          : int.tryParse(thresholdText);
      await widget.ref.read(inventoryControllerProvider.notifier).updateItem(
            itemId: widget.item.id,
            name: _nameCtrl.text,
            defaultPrice: _priceCtrl.text,
            sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
            category: _categoryCtrl.text.trim().isEmpty
                ? null
                : _categoryCtrl.text.trim(),
            lowStockThreshold: threshold,
            isActive: widget.item.isActive,
            imageUrl: _imageUrl,
            imageUrlChanged: _imageUrl != widget.item.imageUrl,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(humanizeInventoryError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StockInSheet extends StatefulWidget {
  const _StockInSheet({required this.item, required this.ref});
  final LocalInventoryItem item;
  final WidgetRef ref;

  @override
  State<_StockInSheet> createState() => _StockInSheetState();
}

class _StockInSheetState extends State<_StockInSheet> {
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Stock In',
      subtitle:
          '${widget.item.name} Â· currently ${widget.item.quantityOnHand} units',
      icon: Icons.add_box_rounded,
      iconColor: AppColors.forest,
      child: Column(
        children: [
          InventoryIField(
            controller: _qtyCtrl,
            label: 'Quantity Received',
            hint: 'e.g. 50',
            prefixIcon: Icons.add_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          InventoryIField(
            controller: _reasonCtrl,
            label: 'Reason / Note (optional)',
            hint: 'e.g. Restocked from supplier',
            prefixIcon: Icons.notes_rounded,
          ),
          const SizedBox(height: 18),
          InventorySaveBtn(
            label: _saving ? 'Applying...' : 'Apply Stock In',
            color: AppColors.forest,
            onTap: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final qty = int.tryParse(_qtyCtrl.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.ref.read(inventoryControllerProvider.notifier).stockIn(
            itemId: widget.item.id,
            quantity: qty,
            reason: _reasonCtrl.text.trim().isEmpty
                ? null
                : _reasonCtrl.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(humanizeInventoryError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AdjustSheet extends StatefulWidget {
  const _AdjustSheet({required this.item, required this.ref});
  final LocalInventoryItem item;
  final WidgetRef ref;

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  final _deltaCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _deltaCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Adjust Stock',
      subtitle:
          '${widget.item.name} Â· currently ${widget.item.quantityOnHand} units',
      icon: Icons.tune_rounded,
      iconColor: const Color(0xFFD97706),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Color(0xFFD97706), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Use + to add and âˆ’ to remove. '
                    'e.g. +5 adds 5 units; âˆ’3 removes 3.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InventoryIField(
            controller: _deltaCtrl,
            label: 'Quantity Delta (+ or âˆ’)',
            hint: 'e.g. -2 or 5',
            prefixIcon: Icons.swap_vert_rounded,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
          ),
          const SizedBox(height: 10),
          InventoryIField(
            controller: _reasonCtrl,
            label: 'Reason (optional)',
            hint: 'e.g. Damaged goods, manual count',
            prefixIcon: Icons.notes_rounded,
          ),
          const SizedBox(height: 18),
          InventorySaveBtn(
            label: _saving ? 'Applying...' : 'Apply Adjustment',
            color: const Color(0xFFD97706),
            onTap: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final delta = int.tryParse(_deltaCtrl.text.trim());
    if (delta == null || delta == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a non-zero delta.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.ref.read(inventoryControllerProvider.notifier).adjustStock(
            itemId: widget.item.id,
            quantityDelta: delta,
            reason: _reasonCtrl.text.trim().isEmpty
                ? null
                : _reasonCtrl.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(humanizeInventoryError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// â”€â”€â”€ shared sheet wrapper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.child,
  });
  final String title, subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PremiumSheetFrame(
      title: title,
      subtitle: subtitle,
      badge: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      bottomInset: MediaQuery.of(context).viewInsets.bottom,
      child: child,
    );
  }
}

// â”€â”€â”€ placeholder / state cards â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.forest,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No items yet',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first inventory item above.\nTrack stock, restock quickly, and keep\nlow-stock risk visible at a glance.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 14),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tip: fill these first',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.ink),
            ),
          ),
          const SizedBox(height: 10),
          const _HintRow(
            icon: Icons.label_rounded,
            text: 'Item name and default selling price',
          ),
          const SizedBox(height: 8),
          const _HintRow(
            icon: Icons.inventory_rounded,
            text: 'Initial stock qty so your count is accurate',
          ),
          const SizedBox(height: 8),
          const _HintRow(
            icon: Icons.warning_amber_rounded,
            text: 'Low stock threshold to get early alerts',
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_box_rounded, size: 18),
              label: const Text('Add First Item'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.forest, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyActiveCard extends StatelessWidget {
  const _EmptyActiveCard({required this.archivedCount});

  final int archivedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.archive_outlined,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              archivedCount == 1
                  ? 'Your active inventory is empty. 1 archived item is still available below.'
                  : 'Your active inventory is empty. $archivedCount archived items are still available below.',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedSection extends StatelessWidget {
  const _ArchivedSection({
    required this.archivedCount,
    required this.visibleCount,
    required this.expanded,
    required this.onToggle,
  });

  final int archivedCount;
  final int visibleCount;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.archive_outlined,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Archived Items',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    visibleCount == archivedCount
                        ? '$archivedCount hidden from sales'
                        : '$visibleCount of $archivedCount match your filters',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedNoMatchCard extends StatelessWidget {
  const _ArchivedNoMatchCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.search_off_rounded, color: AppColors.muted),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No archived items match your current search or category filter.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoMatchCard extends StatelessWidget {
  const _NoMatchCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: const Row(
        children: [
          Icon(Icons.search_off_rounded, color: AppColors.muted),
          SizedBox(width: 12),
          Text(
            'No items match your search.',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ shared field widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _IField extends StatelessWidget {
  const InventoryIField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String label, hint;
  final IconData prefixIcon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, size: 18),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _SaveBtn extends StatelessWidget {
  const InventorySaveBtn({required this.label, this.onTap, this.color});
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color ?? AppColors.forest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ─── archive confirm sheet ────────────────────────────────────────────────────

class _ArchiveConfirmSheet extends StatelessWidget {
  const _ArchiveConfirmSheet({required this.itemName});
  final String itemName;

  @override
  Widget build(BuildContext context) {
    return PremiumSheetFrame(
      title: 'Archive Item',
      subtitle: 'This item will be hidden from new sales',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.archive_outlined,
              color: Color(0xFF6B7280),
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Archive "$itemName"?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.inkSoft,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.muted,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6B7280),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Archive Item'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── delete confirm sheet ─────────────────────────────────────────────────────

class _DeleteConfirmSheet extends StatelessWidget {
  const _DeleteConfirmSheet({required this.itemName});
  final String itemName;

  @override
  Widget build(BuildContext context) {
    return PremiumSheetFrame(
      title: 'Delete Forever',
      subtitle: 'This action cannot be undone',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.dangerSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_forever_rounded,
              color: AppColors.danger,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Delete "$itemName"?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.inkSoft,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'The item and its stock history will be removed permanently. '
            'Your recorded sales are not affected.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.muted,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Delete Forever'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
