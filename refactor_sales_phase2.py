import sys

filepath = r'mobile\lib\features\sales\presentation\sales_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

def extract_class(name):
    start = -1
    for i, l in enumerate(lines):
        if l is not None and l.startswith(f'class {name} '):
            start = i
            break
    if start == -1: return []
    
    end = -1
    nesting = 0
    for i in range(start, len(lines)):
        if lines[i] is None: continue
        # ignore comments
        code = lines[i].split('//')[0]
        nesting += code.count('{')
        nesting -= code.count('}')
        
        # Check if we've seen at least one '{'
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

grid_lines = extract_class('_ItemGrid')
card_lines = extract_class('_ItemCard')
btn_lines = extract_class('_CircleQtyBtn')
bar_lines = extract_class('_BottomBar')

lines = [l for l in lines if l is not None]

item_card_content = "".join(grid_lines + ["\n"] + card_lines + ["\n"] + btn_lines)
item_card_content = item_card_content.replace('_ItemGrid', 'ItemGrid')
item_card_content = item_card_content.replace('_ItemCard', 'ItemCard')
item_card_content = item_card_content.replace('_CircleQtyBtn', 'CircleQtyBtn')

item_card_file = """import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../shared/widgets/product_image_catalog.dart';
import '../../inventory/data/inventory_repository.dart';

""" + item_card_content

with open(r'mobile\lib\features\sales\presentation\widgets\item_card.dart', 'w', encoding='utf-8') as f:
    f.write(item_card_file)

bar_content = "".join(bar_lines)
bar_content = bar_content.replace('_BottomBar', 'SalesBottomBar')

bar_file = """import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';

""" + bar_content

with open(r'mobile\lib\features\sales\presentation\widgets\sales_bottom_bar.dart', 'w', encoding='utf-8') as f:
    f.write(bar_file)

content = "".join(lines)
imports = """import 'widgets/item_card.dart';
import 'widgets/sales_bottom_bar.dart';
"""
content = content.replace("import 'widgets/section_label.dart';", "import 'widgets/section_label.dart';\n" + imports)

content = content.replace('_ItemGrid', 'ItemGrid')
content = content.replace('_ItemCard', 'ItemCard')
content = content.replace('_CircleQtyBtn', 'CircleQtyBtn')
content = content.replace('_BottomBar', 'SalesBottomBar')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print('Phase 2 complete')
