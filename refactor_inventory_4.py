import re

def main():
    file_path = r"c:\Users\USER\Desktop\PROJECTS\BizTrackGh\mobile\lib\features\inventory\presentation\inventory_screen.dart"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Remove unused imports
    content = content.replace("import '../../../shared/widgets/data_freshness_label.dart';\n", "")
    content = content.replace("import '../../sales/presentation/widgets/hero_stat_chip.dart';\n", "")
    
    # Remove _fmtMoney function
    content = re.sub(r"int _priceToMinor\(String value\) \{[\s\S]*?\}\n\nString _fmtMoney\(int minor\) \{[\s\S]*?\}\n", r"int _priceToMinor(String value) {\n  final parts = value.split('.');\n  if (parts.length == 1) return int.parse(parts[0]) * 100;\n  final major = int.parse(parts[0]) * 100;\n  final minor = int.parse(parts[1].padRight(2, '0').substring(0, 2));\n  return major + minor;\n}\n", content)
    
    content = re.sub(r"String _fmtMoney\(int minor\) \{[\s\S]*?\}\n", "", content)
    
    # Remove _showForm field and its usages
    content = content.replace("  bool _showForm = false;\n", "")
    content = content.replace("        _showForm = false;\n", "")
    content = content.replace("  bool _showForm = false;\r\n", "")
    
    # Remove _AddItemAccordion class completely
    content = re.sub(r"class _AddItemAccordion extends StatelessWidget \{[\s\S]+?\}\n\}", "", content)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

if __name__ == "__main__":
    main()
