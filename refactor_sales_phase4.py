import sys
import re

filepath = r'mobile\lib\features\sales\presentation\sales_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add import
content = content.replace("import '../providers/sales_providers.dart';", "import '../providers/sales_providers.dart';\nimport '../providers/sales_cart_provider.dart';")

# 2. Inject `final cart = ...` at the top of build()
build_signature = "Widget build(BuildContext context) {"
build_injections = """
    final cart = ref.watch(salesCartProvider);
    final cartNotifier = ref.read(salesCartProvider.notifier);
"""
content = content.replace(build_signature, build_signature + build_injections)

# 3. Remove variable declarations from class state
content = re.sub(r'final Map<String, int> _qtyByItemId = {};\n', '', content)
content = re.sub(r'// O\(1\) lookup per item for price override.\n\s*final Map<String, String> _priceOverrideByItemId = {};\n', '', content)
content = re.sub(r"String _paymentMethod = 'cash';\n", '', content)
content = re.sub(r"String _searchQuery = '';\n", '', content)

# 4. Replace variable usages
content = content.replace('_qtyByItemId', 'cart.qtyByItemId')
content = content.replace('_priceOverrideByItemId', 'cart.priceOverrideByItemId')
content = content.replace('_paymentMethod', 'cart.paymentMethod')
content = content.replace('_searchQuery', 'cart.searchQuery')

# 5. Replace state mutation methods
content = content.replace('_incrementQty(', 'cartNotifier.incrementQty(')
content = content.replace('_decrementQty(', 'cartNotifier.decrementQty(')

# setState(() => _searchQuery = val) -> cartNotifier.setSearchQuery(val)
# wait, replacing '_searchQuery = ' won't work well because it became 'cart.searchQuery = '.
# we can fix that:
content = content.replace('cart.searchQuery =', 'cartNotifier.setSearchQuery')
# wait, 'cartNotifier.setSearchQuery(val)' requires different syntax from '='.
# original: `onChanged: (val) => setState(() => _searchQuery = val),`
content = content.replace('setState(() => cart.searchQuery = val)', 'cartNotifier.setSearchQuery(val)')
content = content.replace('setState(() => cart.paymentMethod = m)', 'cartNotifier.setPaymentMethod(m)')

# price override:
# original: `setState(() => _priceOverrideByItemId[item.id] = formatted);`
# it became `setState(() => cart.priceOverrideByItemId[item.id] = formatted);`
# change to `cartNotifier.overridePrice(item.id, formatted);`
content = re.sub(r'setState\(\s*\(\)\s*=>\s*cart\.priceOverrideByItemId\[([^\]]+)\]\s*=\s*([^;]+?)\s*\);', r'cartNotifier.overridePrice(\1, \2);', content)

# _resetDraftAfterSale
# original: `_qtyByItemId.clear(); _priceOverrideByItemId.clear(); _paymentMethod = 'cash'; _noteCtrl.clear();`
content = content.replace('cart.qtyByItemId.clear();', '')
content = content.replace('cart.priceOverrideByItemId.clear();', 'cartNotifier.clearCart();')
content = content.replace("cart.paymentMethod = 'cash';", "")

# 6. Remove original `_incrementQty` and `_decrementQty` definitions.
content = re.sub(r'void _incrementQty\(LocalInventoryItem item\) \{.*?\n  \}\n', '', content, flags=re.DOTALL)
content = re.sub(r'void _decrementQty\(String itemId\) \{.*?\n  \}\n', '', content, flags=re.DOTALL)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Phase 4 script executed")
