import re

filepath = r'mobile\lib\features\sales\presentation\sales_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# ── 1. Replace _buildRecentSaleTile ──────────────────────────────────────────
old_tile_sig = '  Widget _buildRecentSaleTile(LocalSaleRecord sale) {'
new_tile = '''  Widget _buildRecentSaleTile(LocalSaleRecord sale) {
    return RecentSaleTile(
      sale: sale,
      onEdit: () => _showEditSaleDialog(sale),
      onVoid: () => _showVoidSaleDialog(sale),
    );
  }'''

# Find the old method body using brace counting
def replace_method(content, signature, replacement):
    idx = content.find(signature)
    if idx == -1:
        print(f'NOT FOUND: {signature}')
        return content
    nesting = 0
    found_open = False
    end = idx
    for i in range(idx, len(content)):
        c = content[i]
        if c == '{':
            nesting += 1
            found_open = True
        elif c == '}':
            nesting -= 1
        if found_open and nesting == 0:
            end = i
            break
    old_body = content[idx:end+1]
    return content.replace(old_body, replacement, 1)

content = replace_method(content, old_tile_sig, new_tile)

# ── 2. Replace _showReviewSaleSheet ──────────────────────────────────────────
old_review_sig = '  Future<void> _showReviewSaleSheet({'
new_review = '''  Future<void> _showReviewSaleSheet({
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
  }'''

content = replace_method(content, old_review_sig, new_review)

# ── 3. Replace _showEditSaleDialog ───────────────────────────────────────────
old_edit_sig = '  Future<void> _showEditSaleDialog(LocalSaleRecord sale) async {'
new_edit = '''  Future<void> _showEditSaleDialog(LocalSaleRecord sale) async {
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
  }'''

content = replace_method(content, old_edit_sig, new_edit)

# ── 4. Replace _showVoidSaleDialog ───────────────────────────────────────────
old_void_sig = '  Future<void> _showVoidSaleDialog(LocalSaleRecord sale) async {'
new_void = '''  Future<void> _showVoidSaleDialog(LocalSaleRecord sale) async {
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
  }'''

content = replace_method(content, old_void_sig, new_void)

# ── 5. Also remove the now-unused _showPriceOverrideDialog's internal setState wiring
#       that still calls 'setState' around cartNotifier — no change needed there.

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print('All methods replaced')
