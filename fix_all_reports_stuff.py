import os
import re

WIDGETS_DIR = r'mobile/lib/features/reports/presentation/widgets'
SCREEN_FILE = r'mobile/lib/features/reports/presentation/reports_screen.dart'

# 1. Update reports_screen.dart
with open(SCREEN_FILE, 'r', encoding='utf-8') as f:
    screen_content = f.read()

replacements = {
    '_computeAging': 'computeAging',
    '_toMinor': 'toMinor',
    '_fmtMoney': 'fmtMoney',
    '_DebtAging': 'DebtAging',
    '_kPieColors': 'kPieColors',
    '_BarChartPainter': 'BarChartPainter',
    '_DonutPainter': 'DonutPainter',
    '_LegendDot': 'LegendDot',
    '_SummaryStat': 'SummaryStat',
    '_AgingRow': 'AgingRow',
}

for old, new in replacements.items():
    screen_content = re.sub(fr'\b{old}\b', new, screen_content)

# add import for reports_utils.dart
if "import 'widgets/reports_utils.dart';" not in screen_content:
    screen_content = screen_content.replace("import 'widgets/error_view.dart';", "import 'widgets/error_view.dart';\nimport 'widgets/reports_utils.dart';")

with open(SCREEN_FILE, 'w', encoding='utf-8') as f:
    f.write(screen_content)


# 2. Update all widgets
widget_files = [f for f in os.listdir(WIDGETS_DIR) if f.endswith('.dart') and f != 'reports_utils.dart']

for widget_file in widget_files:
    filepath = os.path.join(WIDGETS_DIR, widget_file)
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    for old, new in replacements.items():
        content = re.sub(fr'\b{old}\b', new, content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

print("Fixed references across all files.")
