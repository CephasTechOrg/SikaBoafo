import re

def main():
    file_path = r"c:\Users\USER\Desktop\PROJECTS\BizTrackGh\mobile\lib\features\sales\presentation\sales_screen.dart"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Fix import
    content = content.replace("import '../utils/sales_ui_utils.dart';", "import 'utils/sales_ui_utils.dart';")

    # 2. Global replace for all remaining private names to static calls
    # We must be careful not to double-replace.
    # We can use a regex that matches the name NOT preceded by "SalesUiUtils."
    
    replacements = {
        "_formatMinor": "SalesUiUtils.formatMinor",
        "_parseTotal": "SalesUiUtils.parseTotal",
        "_moneyToMinor": "SalesUiUtils.moneyToMinor",
        "_isSameLocalDay": "SalesUiUtils.isSameLocalDay"
    }
    
    for old, new in replacements.items():
        # Match old name NOT preceded by SalesUiUtils.
        pattern = r"(?<!SalesUiUtils\.)" + re.escape(old)
        content = re.sub(pattern, new, content)

    # 3. Fix the double SalesUiUtils that might have occurred from previous runs
    content = content.replace("SalesUiUtils.SalesUiUtils.", "SalesUiUtils.")

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

if __name__ == "__main__":
    main()
