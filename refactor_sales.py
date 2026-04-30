import sys
import os

filepath = r'mobile\lib\features\sales\presentation\sales_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

def delete_lines(start, end):
    for i in range(start-1, end):
        lines[i] = None

# _HeroStatChip
delete_lines(2325, 2377)
# _SalesSearchBar
delete_lines(2379, 2437)
# _SalesTabBar
delete_lines(2490, 2529)
# _SalesTabPill
delete_lines(2531, 2565)
# _SectionLabel
delete_lines(3585, 3601)
# _EmptyCard
delete_lines(3632, 3660)

lines = [l for l in lines if l is not None]
content = ''.join(lines)

imports = """import 'widgets/empty_card.dart';
import 'widgets/hero_stat_chip.dart';
import 'widgets/sales_search_bar.dart';
import 'widgets/sales_tab_bar.dart';
import 'widgets/section_label.dart';
"""
content = content.replace("import '../providers/sales_providers.dart';", "import '../providers/sales_providers.dart';\n" + imports)

content = content.replace('_SalesViewTab', 'SalesViewTab')
content = content.replace('_HeroStatChip', 'HeroStatChip')
content = content.replace('_EmptyCard', 'EmptyCard')
content = content.replace('_SectionLabel', 'SectionLabel')
content = content.replace('_SalesTabBar', 'SalesTabBar')
content = content.replace('_SalesSearchBar', 'SalesSearchBar')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated sales_screen.dart')
