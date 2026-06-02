import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/providers/session_role_providers.dart';
import '../../../shared/widgets/product_image_catalog.dart';
import '../data/inventory_api.dart';
import '../data/inventory_repository.dart';
import '../providers/inventory_providers.dart';
import 'widgets/inventory_mockup_hero.dart';
import 'widgets/inventory_item_card.dart';
import 'widgets/inventory_sheets.dart';
import 'package:lucide_icons/lucide_icons.dart';

// ─── screen ──────────────────────────────────────────────────────────────────

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchCtrl = TextEditingController();

  bool _showArchived = false;
  String _searchQuery = '';
  String? _filterCategory;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryControllerProvider);
    final items = itemsAsync.valueOrNull ?? const <LocalInventoryItem>[];
    final activeItems = items.where((item) => item.isActive).toList();
    final archivedItems = items.where((item) => !item.isActive).toList();

    int lowStockCount = 0;
    final categories = <String>{};
    for (final item in activeItems) {
      if (item.lowStockThreshold != null &&
          item.quantityOnHand <= item.lowStockThreshold!) {
        lowStockCount++;
      }
    }
    for (final item in items) {
      if (item.category != null) categories.add(item.category!);
    }

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

    final filteredActive = activeItems.where(matchesFilters).toList();
    final filteredArchived = archivedItems.where(matchesFilters).toList();

    // Count items per category for the chip badges
    final Map<String, int> categoryCounts = {};
    for (final item in activeItems) {
      if (item.category != null) {
        categoryCounts[item.category!] =
            (categoryCounts[item.category!] ?? 0) + 1;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddItemSheet(context),
        backgroundColor: const Color(0xFF0F7A4A),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── Hero ─────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF041509),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: InventoryMockupHero(
                activeItemsCount: activeItems.length,
                lowStockCount: lowStockCount,
                onRefresh: () => ref
                    .read(inventoryControllerProvider.notifier)
                    .refresh(userInitiated: true),
              ),
              title: innerBoxIsScrolled
                  ? Text(
                      'Inventory',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    )
                  : null,
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            ),
          ),

          // ── Sticky search + category chips ────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverFilterDelegate(
              child: Container(
                color: const Color(0xFFF6F8F7),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SearchBar(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() {
                        _searchQuery = v;
                        if (v.isEmpty) _filterCategory = null;
                      }),
                    ),
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _CategoryFilter(
                        categories: categories.toList()..sort(),
                        categoryCounts: categoryCounts,
                        totalCount: activeItems.length,
                        selected: _filterCategory,
                        onChanged: (c) =>
                            setState(() => _filterCategory = c),
                      ),
                    ],
                  ],
                ),
              ),
              height: 72.0 + (categories.isNotEmpty ? 42.0 : 0.0),
            ),
          ),
        ],
        body: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: RefreshIndicator(
            onRefresh: () => ref
                .read(inventoryControllerProvider.notifier)
                .refresh(userInitiated: true),
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFFF6F8F7)),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
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
                            letterSpacing: 0.5),
                      ),
                      const Spacer(),
                      if (items.isNotEmpty)
                        Text(
                          '${filteredActive.length} of ${activeItems.length}',
                          style: const TextStyle(
                              color: AppColors.mutedSoft, fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (itemsAsync.isLoading && items.isEmpty)
                    const _LoadingCard()
                  else if (itemsAsync.hasError)
                    _ErrorCard(
                        message: humanizeInventoryError(itemsAsync.error!))
                  else if (items.isEmpty)
                    _EmptyCard(onAdd: () => _openAddItemSheet(context))
                  else if (filteredActive.isEmpty && activeItems.isEmpty)
                    _EmptyActiveCard(archivedCount: archivedItems.length)
                  else if (filteredActive.isEmpty)
                    const _NoMatchCard()
                  else
                    ...filteredActive.map((item) => InventoryItemCard(
                        item: item, onTap: () => _openItemDetail(item))),
                  if (archivedItems.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _ArchivedSection(
                      archivedCount: archivedItems.length,
                      visibleCount: filteredArchived.length,
                      expanded: _showArchived,
                      onToggle: () =>
                          setState(() => _showArchived = !_showArchived),
                    ),
                    if (_showArchived) ...[
                      const SizedBox(height: 10),
                      if (filteredArchived.isEmpty)
                        const _ArchivedNoMatchCard()
                      else
                        ...filteredArchived.map((item) => InventoryItemCard(
                            item: item, onTap: () => _openItemDetail(item))),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openItemDetail(LocalInventoryItem item) {
    final canDelete = ref.read(isMerchantOwnerProvider).valueOrNull ?? true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InventoryItemDetailSheet(
        item: item,
        onEdit: () => _openEdit(item),
        onStockIn: () => _openStockIn(item),
        onAdjust: () => _openAdjust(item),
        onArchive: () => _archiveItem(item),
        onRestore: () => _restoreItem(item),
        onDelete: () => _deleteItem(item),
        canDelete: canDelete,
      ),
    );
  }

  void _openAddItemSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddItemSheet(ref: ref),
    );
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

// ─── Sliver Helpers ───────────────────────────────────────────────────────────

class _SliverFilterDelegate extends SliverPersistentHeaderDelegate {
  _SliverFilterDelegate({required this.child, required this.height});
  final Widget child;
  final double height;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Force the header to paint at the same height it lays out.
    // This avoids "layoutExtent exceeds paintExtent" assertions.
    return SizedBox(
      height: maxExtent,
      child: ColoredBox(
        // Match new hero gradient base so the rounded cutout is seamless.
        color: const Color(0xFF041509),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: AppRadii.heroRadius),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFF6F8F7),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1F0F172A),
                  blurRadius: 28,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: SizedBox.expand(child: child),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverFilterDelegate oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
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
        prefixIcon: const Icon(
          LucideIcons.search,
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
    required this.categoryCounts,
    required this.totalCount,
    required this.selected,
    required this.onChanged,
  });
  final List<String> categories;
  final Map<String, int> categoryCounts;
  final int totalCount;
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
            count: totalCount,
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          ...categories.map(
            (c) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _Chip(
                label: c,
                count: categoryCounts[c] ?? 0,
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
  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF073B2A) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0xFF073B2A)
                : const Color(0xFFE5E7EB),
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x3A073B2A),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: selected ? Colors.white : const Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.20)
                    : const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  color: selected ? Colors.white : const Color(0xFF9AA3AF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── item card ────────────────────────────────────────────────────────────────

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
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InventoryIField(
                controller: _nameCtrl,
                label: 'Item Name',
                hint: 'e.g. Mug (Small) — include size in name',
                prefixIcon: Icons.label_rounded),
            const SizedBox(height: 10),
            InventoryIField(
              controller: _priceCtrl,
              label: 'Selling Price (₵)',
              hint: '0.00',
              prefixIcon: Icons.payments_rounded,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
            variants: const [],
            variantsChanged: widget.item.variants.isNotEmpty,
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

// ─────────────────────────────────────────────────────────────────────────────

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
          '${widget.item.name} · currently ${widget.item.quantityOnHand} units',
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

// ─────────────────────────────────────────────────────────────────────────────

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
          '${widget.item.name} · currently ${widget.item.quantityOnHand} units',
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
          InventoryIField(
            controller: _deltaCtrl,
            label: 'Quantity Delta (+ or −)',
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

// ─── shared sheet wrapper ────────────────────────────────────────────────────

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
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.92;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, viewInsets + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Opacity(
              opacity: 0.5,
              child: Image.asset('assets/images/inventory.png', height: 120),
            ),
            const SizedBox(height: 24),
            const Text(
              'No items yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first product to start tracking stock and making sales.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Product'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyActiveCard extends StatelessWidget {
  const _EmptyActiveCard({required this.archivedCount});
  final int archivedCount;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          archivedCount > 0
              ? 'No active items. All $archivedCount items are archived.'
              : 'No active items.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}

class _NoMatchCard extends StatelessWidget {
  const _NoMatchCard();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Text('No matches found for your search.'),
      ),
    );
  }
}

class _ArchivedNoMatchCard extends StatelessWidget {
  const _ArchivedNoMatchCard();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text('No archived matches.',
            style: TextStyle(fontSize: 12, color: AppColors.muted)),
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
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.archive_outlined,
                size: 18, color: AppColors.muted),
            const SizedBox(width: 10),
            Text(
              'Archived Items ($archivedCount)',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
            const Spacer(),
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

class _ArchiveConfirmSheet extends StatelessWidget {
  const _ArchiveConfirmSheet({required this.itemName});
  final String itemName;
  @override
  Widget build(BuildContext context) {
    return _ConfirmSheet(
      title: 'Archive Item?',
      message:
          'Are you sure you want to archive "$itemName"? It will no longer appear in the sales product list.',
      confirmLabel: 'Archive',
      confirmColor: AppColors.forest,
      icon: Icons.archive_rounded,
    );
  }
}

class _DeleteConfirmSheet extends StatelessWidget {
  const _DeleteConfirmSheet({required this.itemName});
  final String itemName;
  @override
  Widget build(BuildContext context) {
    return _ConfirmSheet(
      title: 'Permanently Delete?',
      message:
          'This will permanently remove "$itemName" and all its history. This action cannot be undone.',
      confirmLabel: 'Delete Permanently',
      confirmColor: Colors.red,
      icon: Icons.delete_forever_rounded,
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.icon,
  });
  final String title, message, confirmLabel;
  final Color confirmColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: confirmColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: confirmColor, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(backgroundColor: confirmColor),
                  child: Text(confirmLabel),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AddItemSheet extends StatefulWidget {
  const _AddItemSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  String? _imageUrl;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _skuCtrl.dispose();
    _categoryCtrl.dispose();
    _thresholdCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Add New Product',
      subtitle: 'Enter product details to add it to your inventory.',
      icon: Icons.add_business_rounded,
      iconColor: AppColors.forest,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InventoryIField(
              controller: _nameCtrl,
              label: 'Product Name',
              hint: 'e.g. Mug (Small) — include size in name',
              prefixIcon: Icons.label_rounded,
            ),
            const SizedBox(height: 12),
            InventoryIField(
              controller: _priceCtrl,
              label: 'Selling Price (₵)',
              hint: '0.00',
              prefixIcon: Icons.payments_rounded,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InventoryIField(
                    controller: _categoryCtrl,
                    label: 'Category',
                    hint: 'e.g. Drinks',
                    prefixIcon: Icons.category_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InventoryIField(
                    controller: _skuCtrl,
                    label: 'SKU / Barcode',
                    hint: 'optional',
                    prefixIcon: Icons.qr_code_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InventoryIField(
                    controller: _qtyCtrl,
                    label: 'Initial Stock',
                    hint: '0',
                    prefixIcon: Icons.inventory_2_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InventoryIField(
                    controller: _thresholdCtrl,
                    label: 'Low Stock Alert',
                    hint: 'optional',
                    prefixIcon: Icons.warning_amber_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ProductImagePicker(
              selected: _imageUrl,
              onChanged: (v) => setState(() => _imageUrl = v),
            ),
            const SizedBox(height: 24),
            InventorySaveBtn(
              label: _saving ? 'Saving...' : 'Save Product',
              onTap: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = _priceCtrl.text.trim();
    if (name.isEmpty || price.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name and price are required.')));
      return;
    }
    final initialQtyText = _qtyCtrl.text.trim();
    final initialQty =
        initialQtyText.isEmpty ? 0 : int.tryParse(initialQtyText);
    if (initialQtyText.isNotEmpty && (initialQty == null || initialQty < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a valid initial stock quantity.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.ref.read(inventoryControllerProvider.notifier).createItem(
            name: name,
            defaultPrice: price,
            sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
            category: _categoryCtrl.text.trim().isEmpty
                ? null
                : _categoryCtrl.text.trim(),
            lowStockThreshold: int.tryParse(_thresholdCtrl.text.trim()),
            initialQuantity: initialQty ?? 0,
            imageUrl: _imageUrl,
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
