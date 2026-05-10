import re

def main():
    file_path = r"c:\Users\USER\Desktop\PROJECTS\BizTrackGh\mobile\lib\features\inventory\presentation\inventory_screen.dart"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Insert methods above _saveItem
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
    if "void _openItemDetail" not in content:
        content = content.replace("  Future<void> _saveItem() async {", open_detail_method + "\n  Future<void> _saveItem() async {")

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
    return PremiumSheetFrame(
      title: 'Add New Item',
      subtitle: 'Name, price, stock & more',
      badge: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.forest.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.add_box_rounded, color: AppColors.forest, size: 20),
      ),
      bottomInset: MediaQuery.of(context).viewInsets.bottom,
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
        content += "\n" + add_item_sheet_code

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

if __name__ == "__main__":
    main()
