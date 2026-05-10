import os

SCREEN_FILE = r'mobile/lib/features/reports/presentation/reports_screen.dart'
UTILS_FILE = r'mobile/lib/features/reports/presentation/widgets/reports_utils.dart'

with open(SCREEN_FILE, 'r', encoding='utf-8') as f:
    screen_content = f.read()

# We need to grab the helpers block from screen_content and remove it.
# Lines 34 to 90 roughly.
import re
start_marker = "// ── Chart palette ─────────────────────────────────────────────────────────────"
end_marker = "// ── Reports screen ────────────────────────────────────────────────────────────"

start_idx = screen_content.find(start_marker)
end_idx = screen_content.find(end_marker)

if start_idx != -1 and end_idx != -1:
    helpers_code = screen_content[start_idx:end_idx]
    
    # We will rename the private identifiers to public
    helpers_code = helpers_code.replace('const _kPieColors =', 'const kPieColors =')
    helpers_code = helpers_code.replace('int _toMinor(', 'int toMinor(')
    helpers_code = helpers_code.replace('String _fmtMoney(', 'String fmtMoney(')
    helpers_code = helpers_code.replace('class _DebtAging', 'class DebtAging')
    helpers_code = helpers_code.replace('const _DebtAging(', 'const DebtAging(')
    helpers_code = helpers_code.replace('_DebtAging _computeAging(', 'DebtAging computeAging(')
    helpers_code = helpers_code.replace('return _DebtAging(', 'return DebtAging(')
    
    # Remove it from screen_content
    screen_content = screen_content[:start_idx] + screen_content[end_idx:]
    
    # create reports_utils.dart
    utils_code = """import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../debts/data/debts_repository.dart';

""" + helpers_code

    with open(UTILS_FILE, 'w', encoding='utf-8') as f:
        f.write(utils_code)
        
    with open(SCREEN_FILE, 'w', encoding='utf-8') as f:
        f.write(screen_content)

print("Extracted utils perfectly.")
