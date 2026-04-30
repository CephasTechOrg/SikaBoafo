import sys

filepath = r'mobile\lib\features\sales\presentation\sales_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

def extract_class(name):
    start = -1
    for i, l in enumerate(lines):
        if l is not None and (l.startswith(f'class {name} ') or l.startswith(f'class {name}\n') or l.startswith(f'class {name}{{') or l.startswith(f'class {name}extends') or l.startswith(f'class {name}implements') or l.startswith(f'class {name}<')):
            start = i
            break

    if start == -1: return []
    
    end = -1
    nesting = 0
    for i in range(start, len(lines)):
        if lines[i] is None: continue
        code = lines[i].split('//')[0]
        nesting += code.count('{')
        nesting -= code.count('}')
        
        seen_brace = False
        for j in range(start, i+1):
            if lines[j] is not None and '{' in lines[j]:
                seen_brace = True
                break
                
        if nesting == 0 and seen_brace:
            end = i
            break
    
    if end == -1: return []
    
    block = [lines[i] for i in range(start, end+1) if lines[i] is not None]
    
    for i in range(start, end+1):
        lines[i] = None
        
    return block

header = extract_class('_ProductsHeader')
checkout = extract_class('_CheckoutMethodButton')
status = extract_class('_SaleStatusPill')
qr = extract_class('_PaystackQrSheet') + extract_class('_PaystackQrSheetState')
success = extract_class('_SaleSuccessSheet') + extract_class('_SaleSuccessSheetState') + extract_class('_SuccessCheckPainter')

lines = [l for l in lines if l is not None]

def write_file(filename, content, is_riverpod=False, extra_imports=""):
    content = content.replace('_ProductsHeader', 'ProductsHeader')
    content = content.replace('_CheckoutMethodButton', 'CheckoutMethodButton')
    content = content.replace('_SaleStatusPill', 'SaleStatusPill')
    content = content.replace('_PaystackQrSheet', 'PaystackQrSheet')
    content = content.replace('_SaleSuccessSheet', 'SaleSuccessSheet')
    content = content.replace('_SuccessCheckPainter', 'SuccessCheckPainter')
    
    content = content.replace('const ProductsHeader({', 'const ProductsHeader({super.key, ')
    content = content.replace('const CheckoutMethodButton({', 'const CheckoutMethodButton({super.key, ')
    content = content.replace('const SaleStatusPill({', 'const SaleStatusPill({super.key, ')
    content = content.replace('const PaystackQrSheet({', 'const PaystackQrSheet({super.key, ')
    content = content.replace('const SaleSuccessSheet({', 'const SaleSuccessSheet({super.key, ')
    
    imports = "import 'package:flutter/material.dart';\n"
    if is_riverpod:
        imports += "import 'package:flutter_riverpod/flutter_riverpod.dart';\n"
    imports += "import '../../../../app/theme/app_theme.dart';\n"
    if extra_imports:
        imports += extra_imports + "\n"
        
    with open(f'mobile\\lib\\features\\sales\\presentation\\widgets\\{filename}', 'w', encoding='utf-8') as f:
        f.write(imports + "\n" + content)

write_file('products_header.dart', "".join(header))
write_file('checkout_method_button.dart', "".join(checkout))
write_file('sale_status_pill.dart', "".join(status))

qr_imports = "import 'package:flutter/services.dart';\nimport 'package:qr_flutter/qr_flutter.dart';\nimport '../../data/sales_payments_api.dart';\n"
write_file('paystack_qr_sheet.dart', "".join(qr), is_riverpod=True, extra_imports=qr_imports)

success_imports = "import 'dart:math' show sqrt;\nimport 'package:flutter/services.dart';\n"
write_file('sale_success_sheet.dart', "".join(success), is_riverpod=False, extra_imports=success_imports)


content = "".join(lines)
new_imports = """import 'widgets/products_header.dart';
import 'widgets/checkout_method_button.dart';
import 'widgets/sale_status_pill.dart';
import 'widgets/paystack_qr_sheet.dart';
import 'widgets/sale_success_sheet.dart';
"""
content = content.replace("import 'widgets/sales_bottom_bar.dart';", "import 'widgets/sales_bottom_bar.dart';\n" + new_imports)

content = content.replace('_ProductsHeader', 'ProductsHeader')
content = content.replace('_CheckoutMethodButton', 'CheckoutMethodButton')
content = content.replace('_SaleStatusPill', 'SaleStatusPill')
content = content.replace('_PaystackQrSheet', 'PaystackQrSheet')
content = content.replace('_SaleSuccessSheet', 'SaleSuccessSheet')
content = content.replace('_SuccessCheckPainter', 'SuccessCheckPainter')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Phase 3 script executed")
