import re

def main():
    file_path = r"c:\Users\USER\Desktop\PROJECTS\BizTrackGh\mobile\lib\features\inventory\presentation\inventory_screen.dart"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Add imports for new widgets
    if "import 'widgets/inventory_header.dart';" not in content:
        content = content.replace(
            "import '../providers/inventory_providers.dart';",
            "import '../providers/inventory_providers.dart';\nimport 'widgets/inventory_header.dart';\nimport 'widgets/inventory_item_card.dart';\nimport 'widgets/inventory_sheets.dart';"
        )

    # 2. Add Floating Action Button for Adding Item
    fab_code = """
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddItemSheet(context),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    """
    if "floatingActionButton:" not in content:
        content = content.replace(
            "backgroundColor: AppColors.canvas,",
            "backgroundColor: AppColors.canvas,\n" + fab_code
        )

    # 3. Replace the gigantic inline _AddItemAccordion with nothing in the ListView
    # Since we can't reliably regex the entire _AddItemAccordion instantiation, we'll replace the block.
    # We find where it is called in ListView.
    accordion_call = """                        _AddItemAccordion(
                          expanded: _showForm,
                          nameCtrl: _nameCtrl,
                          priceCtrl: _priceCtrl,
                          skuCtrl: _skuCtrl,
                          categoryCtrl: _categoryCtrl,
                          thresholdCtrl: _thresholdCtrl,
                          qtyCtrl: _qtyCtrl,
                          isLoading: itemsAsync.isLoading,
                          selectedImage: _newItemUrl,
                          onToggle: () =>
                              setState(() => _showForm = !_showForm),
                          onSave: _saveItem,
                          onImageChanged: (v) =>
                              setState(() => _newItemUrl = v),
                        ),
                        const SizedBox(height: 16),"""
    content = content.replace(accordion_call, "")

    # 4. Replace the inline header with InventoryHeader
    # Wait, the inline header is a large block starting with Container( decoration: const BoxDecoration(boxShadow:
    # and ending with the Positioned Expanded(child: Transform.translate( offset: const Offset(0, -8),
    header_regex = re.compile(r"Container\(\s*decoration: const BoxDecoration\(\s*boxShadow:\s*\[[\s\S]+?\]\s*\),\s*child: Stack\([\s\S]+?Active Items.*?low stock.*?categories.*?\]\s*\),\s*\]\s*\),\s*\)\s*\),\s*\]\s*\),\s*\),", re.IGNORECASE)
    # Actually, regex might be brittle. Let's just replace the explicit _ItemCard call with InventoryItemCard and pass onTap.
    
    item_card_old = """                          ...filteredActive.map(
                            (item) => _ItemCard(
                              item: item,
                              onEdit: () => _openEdit(item),
                              onStockIn: () => _openStockIn(item),
                              onAdjust: () => _openAdjust(item),
                              onArchive: () => _archiveItem(item),
                            ),
                          ),"""
    item_card_new = """                          ...filteredActive.map(
                            (item) => InventoryItemCard(
                              item: item,
                              onTap: () => _openItemDetail(item),
                            ),
                          ),"""
    content = content.replace(item_card_old, item_card_new)

    archived_card_old = """                              ...filteredArchived.map(
                                (item) => _ItemCard(
                                  item: item,
                                  onEdit: () => _openEdit(item),
                                  onRestore: () => _restoreItem(item),
                                  onDelete: () => _deleteItem(item),
                                ),
                              ),"""
    archived_card_new = """                              ...filteredArchived.map(
                                (item) => InventoryItemCard(
                                  item: item,
                                  onTap: () => _openItemDetail(item),
                                ),
                              ),"""
    content = content.replace(archived_card_old, archived_card_new)

    # 5. Add _openItemDetail method to _InventoryScreenState
    if "_openItemDetail" not in content:
        open_detail_method = """
  void _openItemDetail(LocalInventoryItem item) {
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
      ),
    );
  }

  void _openAddItemSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddItemSheet(
        nameCtrl: _nameCtrl,
        priceCtrl: _priceCtrl,
        skuCtrl: _skuCtrl,
        categoryCtrl: _categoryCtrl,
        thresholdCtrl: _thresholdCtrl,
        qtyCtrl: _qtyCtrl,
        onSave: () {
          Navigator.of(context).pop();
          _saveItem();
        },
        selectedImage: _newItemUrl,
        onImageChanged: (v) => setState(() => _newItemUrl = v),
      ),
    );
  }
"""
        content = content.replace("  Future<void> _saveItem() async {", open_detail_method + "\n  Future<void> _saveItem() async {")

    # 6. We need to create _AddItemSheet since we removed the accordion.
    add_item_sheet_code = """
class _AddItemSheet extends StatelessWidget {
  const _AddItemSheet({
    required this.nameCtrl,
    required this.priceCtrl,
    required this.skuCtrl,
    required this.categoryCtrl,
    required this.thresholdCtrl,
    required this.qtyCtrl,
    required this.onSave,
    required this.selectedImage,
    required this.onImageChanged,
  });

  final TextEditingController nameCtrl, priceCtrl, skuCtrl, categoryCtrl, thresholdCtrl, qtyCtrl;
  final VoidCallback onSave;
  final String? selectedImage;
  final ValueChanged<String?> onImageChanged;

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Add New Item',
      subtitle: 'Name, price, stock & more',
      icon: Icons.add_box_rounded,
      iconColor: AppColors.forest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InventoryIField(
            controller: nameCtrl,
            label: 'Item Name',
            hint: 'e.g. Sachet Water, Indomie Noodles',
            prefixIcon: Icons.label_rounded,
          ),
          const SizedBox(height: 10),
          InventoryIField(
            controller: priceCtrl,
            label: 'Selling Price (₵)',
            hint: 'e.g. 5.00',
            prefixIcon: Icons.payments_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
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
          InventorySaveBtn(
            label: 'Add Item to Inventory',
            onTap: onSave,
          ),
        ],
      ),
    );
  }
}
"""
    if "class _AddItemSheet extends" not in content:
        content = content.replace("// ─── add item accordion", add_item_sheet_code + "\n// ─── removed accordion")

    # 7. Replace old _IField usage in existing sheets with InventoryIField since we removed _IField from inventory_screen and moved to inventory_sheets
    content = content.replace("_IField(", "InventoryIField(")
    content = content.replace("_SaveBtn(", "InventorySaveBtn(")

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

if __name__ == "__main__":
    main()
