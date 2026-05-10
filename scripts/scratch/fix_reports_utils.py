import os
import re

WIDGETS_DIR = r'mobile/lib/features/reports/presentation/widgets'
SCREEN_FILE = r'mobile/lib/features/reports/presentation/reports_screen.dart'
UTILS_FILE = os.path.join(WIDGETS_DIR, 'reports_utils.dart')

# 1. Create reports_utils.dart
with open(SCREEN_FILE, 'r', encoding='utf-8') as f:
    screen_content = f.read()

# Extract constants and functions
utils_content = """import 'package:flutter/material.dart';

const List<Color> kPieColors = [
  Color(0xFF34C759),
  Color(0xFF007AFF),
  Color(0xFFFF9500),
  Color(0xFFFF3B30),
  Color(0xFFA2845E),
  Color(0xFF5856D6),
];

String fmtMoney(String v) => '\\u20B5$v';

int toMinor(String? val) {
  if (val == null) return 0;
  final match = RegExp(r'^\\d+(\\.\\d{1,2})?$').firstMatch(val.trim());
  if (match == null) return 0;
  final parts = val.trim().split('.');
  final major = int.tryParse(parts[0]) ?? 0;
  final decimals = parts.length == 2 ? (parts[1].padRight(2, '0')) : '00';
  return (major * 100) + (int.tryParse(decimals) ?? 0);
}

class DebtAging {
  const DebtAging({
    required this.current,
    required this.thirtyDays,
    required this.sixtyDays,
    required this.ninetyPlus,
  });

  final int current;
  final int thirtyDays;
  final int sixtyDays;
  final int ninetyPlus;

  int get total => current + thirtyDays + sixtyDays + ninetyPlus;
}
"""
with open(UTILS_FILE, 'w', encoding='utf-8') as f:
    f.write(utils_content)

# Remove these from reports_screen.dart
screen_content = re.sub(r'const List<Color> _kPieColors.*?\];', '', screen_content, flags=re.DOTALL)
screen_content = re.sub(r'String _fmtMoney.*?\\u20B5\$v\';', '', screen_content)
screen_content = re.sub(r'String fmtMoney.*?\\u20B5\$v\';', '', screen_content)
screen_content = re.sub(r'int _toMinor\(.*?\}', '', screen_content, flags=re.DOTALL)
screen_content = re.sub(r'class DebtAging.*?\}', '', screen_content, flags=re.DOTALL)

# Add import to reports_utils.dart in reports_screen.dart
screen_content = screen_content.replace("import 'widgets/error_view.dart';", "import 'widgets/error_view.dart';\nimport 'widgets/reports_utils.dart';")

# Rename all internal classes to public
replacements = {
    '_BarChartPainter': 'BarChartPainter',
    '_DonutPainter': 'DonutPainter',
    '_LegendDot': 'LegendDot',
    '_SummaryStat': 'SummaryStat',
    '_AgingRow': 'AgingRow',
    '_kPieColors': 'kPieColors',
    '_toMinor': 'toMinor',
    '_fmtMoney': 'fmtMoney',
    '_DebtAging': 'DebtAging'
}
for old, new in replacements.items():
    screen_content = re.sub(fr'\b{old}\b', new, screen_content)

with open(SCREEN_FILE, 'w', encoding='utf-8') as f:
    f.write(screen_content)


# 2. Fix widget files
widget_files = [f for f in os.listdir(WIDGETS_DIR) if f.endswith('.dart') and f != 'reports_utils.dart']
exports = {
    'EmptyCard': 'empty_card.dart',
    'LegendDot': 'payment_breakdown_card.dart',
    'SummaryStat': 'business_summary_card.dart',
    'AgingRow': 'debt_aging_card.dart',
    'BarChartPainter': 'bar_chart_card.dart',
    'DonutPainter': 'donut_card.dart'
}

for widget_file in widget_files:
    filepath = os.path.join(WIDGETS_DIR, widget_file)
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Replace privates
    for old, new in replacements.items():
        content = re.sub(fr'\b{old}\b', new, content)
        
    # Add imports for other widgets if used
    new_imports = set()
    if 'fmtMoney(' in content or 'DebtAging' in content or 'kPieColors' in content or 'toMinor(' in content:
        new_imports.add("import 'reports_utils.dart';")
        
    for w, file in exports.items():
        if w in content and file != widget_file:
            new_imports.add(f"import '{file}';")
            
    if new_imports:
        # replace existing relative reports_screen import
        content = content.replace("import '../reports_screen.dart';\n", "")
        # insert after last import
        last_import_idx = content.rfind("import '")
        if last_import_idx != -1:
            end_of_last_import = content.find(";\n", last_import_idx) + 2
            imports_str = "\n".join(new_imports) + "\n"
            content = content[:end_of_last_import] + imports_str + content[end_of_last_import:]
            
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

print("Fixed utils and widgets.")
