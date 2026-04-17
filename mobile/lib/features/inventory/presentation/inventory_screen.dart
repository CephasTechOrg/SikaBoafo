import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../data/inventory_api.dart';
import '../data/inventory_repository.dart';
import '../providers/inventory_providers.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryControllerProvider);
    final query = _searchCtrl.text.trim().toLowerCase();

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
          child: itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                _InventoryErrorView(message: humanizeInventoryError(error)),
            data: (items) {
              final filtered = items.where((item) {
                if (query.isEmpty) return true;
                return item.name.toLowerCase().contains(query) ||
                    (item.category?.toLowerCase().contains(query) ?? false) ||
                    (item.sku?.toLowerCase().contains(query) ?? false);
              }).toList(growable: false);

              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(inventoryControllerProvider.notifier).refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    _InventoryHero(
                        onAdd: () => _showCreateItemDialog(context, ref)),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search inventory',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (items.isEmpty)
                      const _InventoryEmptyView()
                    else if (filtered.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('No inventory item matches your search.'),
                        ),
                      )
                    else
                      ...filtered.map((item) => _InventoryCard(item: item)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateItemDialog(context, ref),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item'),
      ),
    );
  }
}

class _InventoryHero extends StatelessWidget {
  const _InventoryHero({required this.onAdd});

  final VoidCallback onAdd;

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
                Text('Inventory',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'Track stock, restock quickly, and keep low-stock risk visible.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _InventoryCard extends ConsumerWidget {
  const _InventoryCard({required this.item});

  final LocalInventoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLowStock = item.lowStockThreshold != null &&
        item.quantityOnHand <= item.lowStockThreshold!;
    final stockColor = isLowStock ? AppColors.coral : AppColors.forest;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: stockColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.inventory_2_rounded, color: stockColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.category ?? item.sku ?? 'General stock item',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: stockColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    isLowStock
                        ? 'Low ${item.quantityOnHand}'
                        : 'Stock ${item.quantityOnHand}',
                    style: TextStyle(
                      color: stockColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'GHS ${item.defaultPrice}'
              '${item.lowStockThreshold == null ? '' : ' | Threshold ${item.lowStockThreshold}'}',
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InventoryActionButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  onPressed: () => _showEditItemDialog(context, ref, item),
                ),
                _InventoryActionButton(
                  label: 'Stock In',
                  icon: Icons.add_box_outlined,
                  onPressed: () => _showStockInDialog(context, ref, item),
                ),
                _InventoryActionButton(
                  label: 'Adjust',
                  icon: Icons.tune_rounded,
                  onPressed: () => _showAdjustDialog(context, ref, item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryActionButton extends StatelessWidget {
  const _InventoryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _InventoryErrorView extends StatelessWidget {
  const _InventoryErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryEmptyView extends StatelessWidget {
  const _InventoryEmptyView();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            Text('No items yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Create your first inventory item to start recording sales cleanly.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showCreateItemDialog(BuildContext context, WidgetRef ref) async {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final skuCtrl = TextEditingController();
  final categoryCtrl = TextEditingController();
  final thresholdCtrl = TextEditingController();
  final initialQtyCtrl = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Add Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              TextField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Default price'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: skuCtrl,
                decoration: const InputDecoration(labelText: 'SKU (optional)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: categoryCtrl,
                decoration:
                    const InputDecoration(labelText: 'Category (optional)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: thresholdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Low stock threshold (optional)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: initialQtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Initial stock quantity (optional)',
                  hintText: 'Default is 0',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final initialQtyText = initialQtyCtrl.text.trim();
              final initialQty =
                  initialQtyText.isEmpty ? 0 : int.tryParse(initialQtyText);
              if (initialQtyText.isNotEmpty &&
                  (initialQty == null || initialQty < 0)) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                      content: Text('Enter a valid initial stock quantity.')),
                );
                return;
              }
              try {
                await ref.read(inventoryControllerProvider.notifier).createItem(
                      name: nameCtrl.text,
                      defaultPrice: priceCtrl.text,
                      sku: skuCtrl.text,
                      category: categoryCtrl.text,
                      lowStockThreshold:
                          int.tryParse(thresholdCtrl.text.trim()),
                      initialQuantity: initialQty ?? 0,
                    );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(humanizeInventoryError(error))),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

Future<void> _showEditItemDialog(
  BuildContext context,
  WidgetRef ref,
  LocalInventoryItem item,
) async {
  final nameCtrl = TextEditingController(text: item.name);
  final priceCtrl = TextEditingController(text: item.defaultPrice);
  final skuCtrl = TextEditingController(text: item.sku ?? '');
  final categoryCtrl = TextEditingController(text: item.category ?? '');
  final thresholdCtrl = TextEditingController(
    text: item.lowStockThreshold?.toString() ?? '',
  );
  var isActive = item.isActive;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Item'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Default price'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: skuCtrl,
                    decoration:
                        const InputDecoration(labelText: 'SKU (optional)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: categoryCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Category (optional)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: thresholdCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Low stock threshold',
                      hintText: 'Leave unchanged to keep current threshold',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active item'),
                    value: isActive,
                    onChanged: (value) =>
                        setDialogState(() => isActive = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final thresholdText = thresholdCtrl.text.trim();
                  final lowStockThreshold = thresholdText.isEmpty
                      ? item.lowStockThreshold
                      : int.tryParse(thresholdText);
                  if (thresholdText.isNotEmpty && lowStockThreshold == null) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Enter a valid threshold.')),
                    );
                    return;
                  }
                  try {
                    await ref
                        .read(inventoryControllerProvider.notifier)
                        .updateItem(
                          itemId: item.id,
                          name: nameCtrl.text,
                          defaultPrice: priceCtrl.text,
                          sku: skuCtrl.text,
                          category: categoryCtrl.text,
                          lowStockThreshold: lowStockThreshold,
                          isActive: isActive,
                        );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  } catch (error) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(humanizeInventoryError(error))),
                    );
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showStockInDialog(
  BuildContext context,
  WidgetRef ref,
  LocalInventoryItem item,
) async {
  final quantityCtrl = TextEditingController();
  final reasonCtrl = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text('Stock In: ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final qty = int.tryParse(quantityCtrl.text.trim());
              if (qty == null || qty <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Enter a valid quantity.')),
                );
                return;
              }
              try {
                await ref.read(inventoryControllerProvider.notifier).stockIn(
                      itemId: item.id,
                      quantity: qty,
                      reason: reasonCtrl.text,
                    );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(humanizeInventoryError(error))),
                );
              }
            },
            child: const Text('Apply'),
          ),
        ],
      );
    },
  );
}

Future<void> _showAdjustDialog(
  BuildContext context,
  WidgetRef ref,
  LocalInventoryItem item,
) async {
  final deltaCtrl = TextEditingController();
  final reasonCtrl = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text('Adjust: ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: deltaCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Delta (+ / -)',
                hintText: 'e.g. -2 or 5',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final delta = int.tryParse(deltaCtrl.text.trim());
              if (delta == null || delta == 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Enter a non-zero delta.')),
                );
                return;
              }
              try {
                await ref
                    .read(inventoryControllerProvider.notifier)
                    .adjustStock(
                      itemId: item.id,
                      quantityDelta: delta,
                      reason: reasonCtrl.text,
                    );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(humanizeInventoryError(error))),
                );
              }
            },
            child: const Text('Apply'),
          ),
        ],
      );
    },
  );
}
