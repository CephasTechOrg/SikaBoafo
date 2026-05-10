import os
import re

WIDGETS_DIR = r'mobile/lib/features/reports/presentation/widgets'
SCREEN_FILE = r'mobile/lib/features/reports/presentation/reports_screen.dart'
TEST_FILE = r'mobile/test/features/reports_screen_test.dart'

# 1. Fix reports_screen.dart
with open(SCREEN_FILE, 'r', encoding='utf-8') as f:
    screen_content = f.read()

# Make _fmtMoney and _DebtAging public
screen_content = screen_content.replace('String _fmtMoney(', 'String fmtMoney(')
screen_content = screen_content.replace('class _DebtAging', 'class DebtAging')
screen_content = screen_content.replace('_DebtAging(', 'DebtAging(')
screen_content = screen_content.replace('<_DebtAging>', '<DebtAging>')
screen_content = screen_content.replace('_fmtMoney(', 'fmtMoney(')

# Also ensure all widgets have public names in screen_content
public_widgets = ['BarChartCard', 'DonutCard', 'TopCustomersCard', 'PaymentBreakdownCard', 
                  'TopItemsCard', 'DebtAgingCard', 'BusinessSummaryCard', 'PeriodTabs', 
                  'KpiRow', 'ReportHeroChip', 'SectionHeader', 'EmptyCard', 'OfflineCard', 
                  'ReportsLoading', 'ErrorView']
for widget in public_widgets:
    screen_content = re.sub(fr'\b_{widget}\b', widget, screen_content)

with open(SCREEN_FILE, 'w', encoding='utf-8') as f:
    f.write(screen_content)


# 2. Fix widget files
widget_files = [f for f in os.listdir(WIDGETS_DIR) if f.endswith('.dart')]
available_widgets = {
    'EmptyCard': 'empty_card.dart',
    'LegendDot': 'payment_breakdown_card.dart', # wait, LegendDot is IN payment_breakdown_card
    'SummaryStat': 'business_summary_card.dart',
    'AgingRow': 'debt_aging_card.dart',
}

for widget_file in widget_files:
    filepath = os.path.join(WIDGETS_DIR, widget_file)
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Replace privates
    content = content.replace('_fmtMoney(', 'fmtMoney(')
    content = content.replace('_DebtAging', 'DebtAging')
    for w in public_widgets:
        content = re.sub(fr'\b_{w}\b', w, content)
        
    # Add imports for other widgets if used
    new_imports = set()
    if 'fmtMoney(' in content or 'DebtAging' in content:
        new_imports.add("import '../reports_screen.dart';")
        
    for w, file in available_widgets.items():
        if w in content and file != widget_file:
            new_imports.add(f"import '{file}';")
            
    if new_imports:
        # insert after last import
        last_import_idx = content.rfind("import '")
        if last_import_idx != -1:
            end_of_last_import = content.find(";\n", last_import_idx) + 2
            imports_str = "\n".join(new_imports) + "\n"
            content = content[:end_of_last_import] + imports_str + content[end_of_last_import:]
            
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

# 3. Fix test file
if os.path.exists(TEST_FILE):
    with open(TEST_FILE, 'r', encoding='utf-8') as f:
        test_content = f.read()
    test_content = test_content.replace('features/dashboard/presentation/reports_screen.dart', 'features/reports/presentation/reports_screen.dart')
    with open(TEST_FILE, 'w', encoding='utf-8') as f:
        f.write(test_content)

print("Widgets and tests fixed.")
