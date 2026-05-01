import re

def main():
    file_path = r"c:\Users\USER\Desktop\PROJECTS\BizTrackGh\mobile\lib\features\sales\presentation\sales_screen.dart"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Remove the mangled declarations
    content = re.sub(r"  int SalesUiUtils\.moneyToMinorSafe[\s\S]+?\}\n", "", content)
    content = re.sub(r"  String minorToMoney[\s\S]+?\}\n", "", content)
    
    # 2. Replace any remaining calls
    content = content.replace("minorToMoney(", "SalesUiUtils.minorToMoney(")
    
    # 3. Remove unused imports
    content = content.replace("import 'package:intl/intl.dart';\n", "")
    content = content.replace("import '../../../shared/widgets/data_freshness_label.dart';\n", "")
    content = content.replace("import 'widgets/hero_stat_chip.dart';\n", "")

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

if __name__ == "__main__":
    main()
