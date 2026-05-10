import os
import re

SCREEN_FILE = r'mobile/lib/features/reports/presentation/reports_screen.dart'
WIDGETS_DIR = r'mobile/lib/features/reports/presentation/widgets'

if not os.path.exists(WIDGETS_DIR):
    os.makedirs(WIDGETS_DIR)

with open(SCREEN_FILE, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix relative imports for dashboard
content = content.replace("import '../data/dashboard_api.dart';", "import '../../dashboard/data/dashboard_api.dart';")
content = content.replace("import '../providers/dashboard_providers.dart';", "import '../../dashboard/providers/dashboard_providers.dart';")

# Find all classes
class_pattern = re.compile(r'^class (_?\w+) (?:extends|implements) .*?{', re.MULTILINE)
classes = []
for match in class_pattern.finditer(content):
    class_name = match.group(1)
    start_idx = match.start()
    classes.append({"name": class_name, "start": start_idx})

for i in range(len(classes)):
    start_idx = classes[i]["start"]
    
    # Find matching closing brace
    brace_count = 0
    in_class = False
    end_idx = start_idx
    for j in range(start_idx, len(content)):
        char = content[j]
        if char == '{':
            brace_count += 1
            in_class = True
        elif char == '}':
            brace_count -= 1
            if in_class and brace_count == 0:
                end_idx = j + 1
                break
    classes[i]["end"] = end_idx
    classes[i]["code"] = content[start_idx:end_idx]

# Map class names to filenames
def camel_to_snake(name):
    name = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
    return re.sub('([a-z0-9])([A-Z])', r'\1_\2', name).lower().lstrip('_')

# Identify classes to extract (skip ReportsScreen and its state)
classes_to_extract = [c for c in classes if c['name'] not in ('ReportsScreen', '_ReportsScreenState', '_DebtAging')]

extracted_files = {}

# Group classes
groupings = {
    'bar_chart_card.dart': ['_BarChartCard', '_BarChartPainter'],
    'donut_card.dart': ['_DonutCard', '_DonutPainter'],
    'top_customers_card.dart': ['_TopCustomersCard'],
    'payment_breakdown_card.dart': ['_PaymentBreakdownCard', '_LegendDot'],
    'top_items_card.dart': ['_TopItemsCard'],
    'debt_aging_card.dart': ['_DebtAgingCard', '_AgingRow'],
    'business_summary_card.dart': ['_BusinessSummaryCard', '_SummaryStat'],
    'period_tabs.dart': ['_PeriodTabs'],
    'kpi_row.dart': ['_KpiRow'],
    'report_hero_chip.dart': ['_ReportHeroChip'],
    'section_header.dart': ['_SectionHeader'],
    'empty_card.dart': ['_EmptyCard'],
    'offline_card.dart': ['_OfflineCard'],
    'reports_loading.dart': ['_ReportsLoading'],
    'error_view.dart': ['_ErrorView']
}

class_to_file = {}
for filename, class_list in groupings.items():
    for c_name in class_list:
        class_to_file[c_name] = filename

for c in classes_to_extract:
    c_name = c['name']
    if c_name not in class_to_file:
        print(f"Skipping {c_name}")
        continue
    
    filename = class_to_file[c_name]
    
    # Make class public
    public_name = c_name.lstrip('_')
    code = c['code']
    code = re.sub(fr'\b{c_name}\b', public_name, code)
    
    if filename not in extracted_files:
        extracted_files[filename] = []
    extracted_files[filename].append(code)

# Common imports for the widget files
common_imports = """import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../../shared/widgets/mockup_ui.dart';
import '../../../../shared/widgets/premium_ui.dart';
import '../../../dashboard/data/dashboard_api.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import '../../../debts/data/debts_repository.dart';
import '../../../debts/providers/debts_providers.dart';
import '../../../expenses/data/expenses_repository.dart';
import '../../../expenses/providers/expenses_providers.dart';
"""

# Write the new files
for filename, code_list in extracted_files.items():
    filepath = os.path.join(WIDGETS_DIR, filename)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(common_imports + "\n")
        f.write("\n\n".join(code_list) + "\n")
    print(f"Created {filepath}")

# Remove extracted classes from main file
new_content = content
for c in classes_to_extract:
    new_content = new_content.replace(c['code'], "")
    # Update references in the rest of the file to use public names
    c_name = c['name']
    public_name = c_name.lstrip('_')
    new_content = re.sub(fr'\b{c_name}\b', public_name, new_content)

# Add imports for the new files into reports_screen.dart
new_imports = ""
for filename in extracted_files.keys():
    new_imports += f"import 'widgets/{filename}';\n"

# Insert after the last import
last_import_idx = new_content.rfind("import '")
if last_import_idx != -1:
    end_of_last_import = new_content.find(";\n", last_import_idx) + 2
    new_content = new_content[:end_of_last_import] + new_imports + "\n" + new_content[end_of_last_import:]

with open(SCREEN_FILE, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Done extracting!")
