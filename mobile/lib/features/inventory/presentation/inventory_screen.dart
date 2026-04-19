import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/product_image_catalog.dart';
import '../data/inventory_api.dart';
import '../data/inventory_repository.dart';
import '../providers/inventory_providers.dart';

// ─── helpers ──────────────────────────────────────────────────────────────────

int _priceToMinor(String value) {
  final parts = value.trim().split('.');
  final major = int.tryParse(parts[0]) ?? 0;
  final raw = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
  return (major * 100) + (int.tryParse(raw.substring(0, 2)) ?? 0);
}

String _fmtMoney(int minor) {
  final major = minor ~/ 100;
  final cents = (minor % 100).toString().padLeft(2, '0');
  return 'GHS $major.$cents';
}

// ─── screen ───────────────────────────────────────────────────────────────────

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
  String _searchQuery = '';
  String? _filterCategory;
  String? _newItemImage;

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

    // O(n) stats pass
    int totalValueMinor = 0;
    int lowStockCount = 0;
    final categories = <String>{};
    for (final item in items) {
      totalValueMinor +=
          _priceToMinor(item.defaultPrice) * item.quantityOnHand;
      if (item.category != null) categories.add(item.category!);
      if (item.lowStockThreshold != null &&
          item.quantityOnHand <= item.lowStockThreshold!) {
        lowStockCount++;
      }
    }

    // Filter
    final q = _searchQuery.toLowerCase();
    final filtered = items.where((item) {
      final matchQuery = q.isEmpty ||
          item.name.toLowerCase().contains(q) ||
          (item.category?.toLowerCase().contains(q) ?? false) ||
          (item.sku?.toLowerCase().contains(q) ?? false);
      final matchCat =
          _filterCategory == null || item.category == _filterCategory;
      return matchQuery && matchCat;
    }).toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A3D33), Color(0xFF1A6B5B), AppColors.canvas],
            stops: [0.0, 0.28, 0.28],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                itemCount: items.length,
                lowStockCount: lowStockCount,
                onRefresh: () =>
                    ref.read(inventoryControllerProvider.notifier).refresh(),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  child: Container(
                    color: AppColors.canvas,
                    child: RefreshIndicator(
                      onRefresh: () => ref
                          .read(inventoryControllerProvider.notifier)
                          .refresh(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(16, 20, 16, 100),
                        children: [
                          _StatsRow(
                            itemCount: items.length,
                            lowStockCount: lowStockCount,
                            totalValueMinor: totalValueMinor,
                          ),
                          const SizedBox(height: 16),

                          // ── Add Item accordion ──
                          _AddItemAccordion(
                            expanded: _showForm,
                            nameCtrl: _nameCtrl,
                            priceCtrl: _priceCtrl,
                            skuCtrl: _skuCtrl,
                            categoryCtrl: _categoryCtrl,
                            thresholdCtrl: _thresholdCtrl,
                            qtyCtrl: _qtyCtrl,
                            isLoading: itemsAsync.isLoading,
                            selectedImage: _newItemImage,
                            onToggle: () =>
                                setState(() => _showForm = !_showForm),
                            onSave: _saveItem,
                            onImageChanged: (v) =>
                                setState(() => _newItemImage = v),
                          ),
                          const SizedBox(height: 20),

                          // ── Search + filter ──
                          _SearchBar(
                            controller: _searchCtrl,
                            onChanged: (v) =>
                                setState(() => _searchQuery = v),
                          ),
                          if (categories.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _CategoryFilter(
                              categories: categories.toList()..sort(),
                              selected: _filterCategory,
                              onChanged: (c) =>
                                  setState(() => _filterCategory = c),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // ── Items list ──
                          Row(
                            children: [
                              Text(
                                filtered.isEmpty && q.isNotEmpty
                                    ? 'No matches'
                                    : 'Your Inventory',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.ink,
                                ),
                              ),
                              const Spacer(),
                              if (items.isNotEmpty)
                                Text(
                                  '${filtered.length} of ${items.length}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          if (itemsAsync.isLoading && items.isEmpty)
                            const _LoadingCard()
                          else if (itemsAsync.hasError)
                            _ErrorCard(
                              message: humanizeInventoryError(
                                  itemsAsync.error!),
                            )
                          else if (items.isEmpty)
                            _EmptyCard(
                              onAdd: () =>
                                  setState(() => _showForm = true),
                            )
                          else if (filtered.isEmpty)
                            const _NoMatchCard()
                          else
                            ...filtered.map(
                              (item) => _ItemCard(
                                item: item,
                                onEdit: () => _openEdit(item),
                                onStockIn: () => _openStockIn(item),
                                onAdjust: () => _openAdjust(item),
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
            lowStockThreshold:
                int.tryParse(_thresholdCtrl.text.trim()),
            initialQuantity: initialQty ?? 0,
            imageAsset: _newItemImage,
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
        _newItemImage = null;
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

  void _msg(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));
}

// ─── header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.itemCount,
    required this.lowStockCount,
    required this.onRefresh,
  });
  final int itemCount, lowStockCount;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inventory',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$itemCount item${itemCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (lowStockCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.white, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              '$lowStockCount low stock',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.itemCount,
    required this.lowStockCount,
    required this.totalValueMinor,
  });
  final int itemCount, lowStockCount, totalValueMinor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Items',
            value: '$itemCount',
            icon: Icons.inventory_2_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Low Stock',
            value: '$lowStockCount',
            icon: Icons.warning_amber_rounded,
            valueColor: lowStockCount > 0 ? const Color(0xFFDC2626) : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Est. Value',
            value: _fmtMoney(totalValueMinor),
            icon: Icons.payments_rounded,
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
    required this.icon,
    this.valueColor,
  });
  final String label, value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.forest, size: 17),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: valueColor ?? AppColors.ink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── add item accordion ───────────────────────────────────────────────────────

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
  final TextEditingController nameCtrl, priceCtrl, skuCtrl, categoryCtrl,
      thresholdCtrl, qtyCtrl;
  final bool isLoading;
  final String? selectedImage;
  final VoidCallback onToggle, onSave;
  final ValueChanged<String?> onImageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: expanded
                ? const BorderRadius.vertical(top: Radius.circular(20))
                : BorderRadius.circular(20),
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
                    child: const Icon(Icons.add_box_rounded,
                        color: AppColors.forest, size: 20),
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
                    child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
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
                  _IField(
                    controller: nameCtrl,
                    label: 'Item Name',
                    hint: 'e.g. Sachet Water, Indomie Noodles',
                    prefixIcon: Icons.label_rounded,
                  ),
                  const SizedBox(height: 10),
                  _IField(
                    controller: priceCtrl,
                    label: 'Selling Price (GHS)',
                    hint: 'e.g. 5.00',
                    prefixIcon: Icons.payments_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                  const SizedBox(height: 16),

                  // Stock fields
                  const _FieldGroup(label: 'Stock'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _IField(
                          controller: qtyCtrl,
                          label: 'Initial Qty',
                          hint: '0',
                          prefixIcon: Icons.inventory_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _IField(
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
                        child: _IField(
                          controller: categoryCtrl,
                          label: 'Category',
                          hint: 'e.g. Drinks, Snacks',
                          prefixIcon: Icons.category_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _IField(
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
                      label: Text(isLoading
                          ? 'Saving...'
                          : 'Save Item to Inventory'),
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

// ─── search & filter ──────────────────────────────────────────────────────────

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
        hintText: 'Search items by name, category or SKU…',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: AppColors.forest, width: 1.4),
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
                onTap: () =>
                    onChanged(selected == c ? null : c),
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
      {required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.forest.withValues(alpha: 0.14)
              : Colors.white,
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
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── item card ────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.onEdit,
    required this.onStockIn,
    required this.onAdjust,
  });

  final LocalInventoryItem item;
  final VoidCallback onEdit, onStockIn, onAdjust;

  @override
  Widget build(BuildContext context) {
    final hasThreshold = item.lowStockThreshold != null;
    final isOut = item.quantityOnHand == 0;
    final isLow = hasThreshold &&
        item.quantityOnHand <= item.lowStockThreshold! &&
        !isOut;

    final Color stockColor = isOut
        ? const Color(0xFFDC2626)
        : isLow
            ? const Color(0xFFD97706)
            : AppColors.forest;
    final String stockLabel =
        isOut ? 'Out of Stock' : isLow ? 'Low Stock' : 'In Stock';

    final double progress = hasThreshold && item.lowStockThreshold! > 0
        ? (item.quantityOnHand / (item.lowStockThreshold! * 2.0))
            .clamp(0.0, 1.0)
        : item.quantityOnHand > 0
            ? 1.0
            : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── main info ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image — always neutral background, image contained
                ItemImage(
                  imageAsset: item.imageAsset,
                  size: 56,
                  fallbackIcon: Icons.inventory_2_outlined,
                ),
                const SizedBox(width: 12),
                // Item details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!item.isActive)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'INACTIVE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFDC2626),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.ink,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'GHS ${item.defaultPrice}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.forest,
                        ),
                      ),
                      if (item.category != null || item.sku != null) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 5,
                          runSpacing: 3,
                          children: [
                            if (item.category != null)
                              _SmallBadge(label: item.category!),
                            if (item.sku != null)
                              _SmallBadge(label: item.sku!),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Stock quantity
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.quantityOnHand}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: stockColor,
                        height: 1,
                      ),
                    ),
                    Text(
                      'units',
                      style: TextStyle(
                        fontSize: 10,
                        color: stockColor.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: stockColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOut ? 'Out' : isLow ? 'Low' : 'OK',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: stockColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── stock bar (only when threshold set) ──
          if (hasThreshold)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: stockColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            stockLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: stockColor,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Alert: ${item.lowStockThreshold} units',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(stockColor),
                    ),
                  ),
                ],
              ),
            ),

          // ── divider + actions ──
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
            child: Row(
              children: [
                _ActionBtn(
                  label: 'Edit',
                  icon: Icons.edit_rounded,
                  color: AppColors.forest,
                  onTap: onEdit,
                ),
                const SizedBox(width: 6),
                _ActionBtn(
                  label: 'Stock In',
                  icon: Icons.add_box_rounded,
                  color: const Color(0xFF2563EB),
                  onTap: onStockIn,
                ),
                const SizedBox(width: 6),
                _ActionBtn(
                  label: 'Adjust',
                  icon: Icons.tune_rounded,
                  color: const Color(0xFFD97706),
                  onTap: onAdjust,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.muted,
        ),
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
    return Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: Icon(icon, size: 14),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─── bottom sheets ────────────────────────────────────────────────────────────

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
  late bool _isActive;
  late String? _imageAsset;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _priceCtrl = TextEditingController(text: widget.item.defaultPrice);
    _skuCtrl = TextEditingController(text: widget.item.sku ?? '');
    _categoryCtrl =
        TextEditingController(text: widget.item.category ?? '');
    _thresholdCtrl = TextEditingController(
        text: widget.item.lowStockThreshold?.toString() ?? '');
    _isActive = widget.item.isActive;
    _imageAsset = widget.item.imageAsset;
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
      iconColor: AppColors.forest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IField(
              controller: _nameCtrl,
              label: 'Item Name',
              hint: 'e.g. Sachet Water',
              prefixIcon: Icons.label_rounded),
          const SizedBox(height: 10),
          _IField(
            controller: _priceCtrl,
            label: 'Selling Price (GHS)',
            hint: '0.00',
            prefixIcon: Icons.payments_rounded,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _IField(
                    controller: _categoryCtrl,
                    label: 'Category',
                    hint: 'e.g. Drinks',
                    prefixIcon: Icons.category_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _IField(
                    controller: _skuCtrl,
                    label: 'SKU',
                    hint: 'optional',
                    prefixIcon: Icons.qr_code_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _IField(
            controller: _thresholdCtrl,
            label: 'Low Stock Alert Threshold',
            hint: 'e.g. 10',
            prefixIcon: Icons.warning_amber_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          ProductImagePicker(
            selected: _imageAsset,
            onChanged: (v) => setState(() => _imageAsset = v),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF6F7F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14),
              title: const Text(
                'Item is Active',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _isActive
                    ? 'Visible on the sales screen'
                    : 'Hidden from sales',
                style: const TextStyle(fontSize: 12),
              ),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              activeThumbColor: AppColors.forest,
            ),
          ),
          const SizedBox(height: 18),
          _SaveBtn(
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
      await widget.ref
          .read(inventoryControllerProvider.notifier)
          .updateItem(
            itemId: widget.item.id,
            name: _nameCtrl.text,
            defaultPrice: _priceCtrl.text,
            sku: _skuCtrl.text.trim().isEmpty
                ? null
                : _skuCtrl.text.trim(),
            category: _categoryCtrl.text.trim().isEmpty
                ? null
                : _categoryCtrl.text.trim(),
            lowStockThreshold: threshold,
            isActive: _isActive,
            imageAsset: _imageAsset,
            imageAssetChanged: _imageAsset != widget.item.imageAsset,
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

// ──────────────────────────────────────────────────────────────────────────────

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
      subtitle: '${widget.item.name} · currently ${widget.item.quantityOnHand} units',
      icon: Icons.add_box_rounded,
      iconColor: const Color(0xFF2563EB),
      child: Column(
        children: [
          _IField(
            controller: _qtyCtrl,
            label: 'Quantity Received',
            hint: 'e.g. 50',
            prefixIcon: Icons.add_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          _IField(
            controller: _reasonCtrl,
            label: 'Reason / Note (optional)',
            hint: 'e.g. Restocked from supplier',
            prefixIcon: Icons.notes_rounded,
          ),
          const SizedBox(height: 18),
          _SaveBtn(
            label: _saving ? 'Applying...' : 'Apply Stock In',
            color: const Color(0xFF2563EB),
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
      await widget.ref
          .read(inventoryControllerProvider.notifier)
          .stockIn(
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

// ──────────────────────────────────────────────────────────────────────────────

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
      subtitle: '${widget.item.name} · currently ${widget.item.quantityOnHand} units',
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
                    'Use + to add and − to remove. '
                    'e.g. +5 adds 5 units; −3 removes 3.',
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
          _IField(
            controller: _deltaCtrl,
            label: 'Quantity Delta (+ or −)',
            hint: 'e.g. -2 or 5',
            prefixIcon: Icons.swap_vert_rounded,
            keyboardType: const TextInputType.numberWithOptions(
                signed: true),
          ),
          const SizedBox(height: 10),
          _IField(
            controller: _reasonCtrl,
            label: 'Reason (optional)',
            hint: 'e.g. Damaged goods, manual count',
            prefixIcon: Icons.notes_rounded,
          ),
          const SizedBox(height: 18),
          _SaveBtn(
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
      await widget.ref
          .read(inventoryControllerProvider.notifier)
          .adjustStock(
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

// ─── shared sheet wrapper ─────────────────────────────────────────────────────

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
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: iconColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── placeholder / state cards ────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
            child: const Icon(Icons.inventory_2_outlined,
                color: AppColors.forest, size: 30),
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
              style: const TextStyle(
                  color: AppColors.muted, fontSize: 13),
            ),
          ),
        ),
      ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
              style: const TextStyle(
                  color: Color(0xFF991B1B), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── shared field widgets ─────────────────────────────────────────────────────

class _IField extends StatelessWidget {
  const _IField({
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
        fillColor: const Color(0xFFF6F7F9),
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
          borderSide:
              const BorderSide(color: AppColors.forest, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _SaveBtn extends StatelessWidget {
  const _SaveBtn({required this.label, this.onTap, this.color});
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
