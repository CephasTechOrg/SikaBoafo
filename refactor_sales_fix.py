import re

def main():
    file_path = r"c:\Users\USER\Desktop\PROJECTS\BizTrackGh\mobile\lib\features\sales\presentation\sales_screen.dart"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Remove the mangled declarations entirely.
    # We look for blocks starting with "  String SalesUiUtils" or similar.
    content = re.sub(r"  String SalesUiUtils\.formatMinor[\s\S]+?\}\n", "", content)
    content = re.sub(r"  int SalesUiUtils\.parseTotal[\s\S]+?\}\n", "", content)
    content = re.sub(r"  int SalesUiUtils\.moneyToMinor[\s\S]+?\}\n", "", content)
    content = re.sub(r"  bool SalesUiUtils\.isSameLocalDay[\s\S]+?\}\n", "", content)

    # 2. Fix the _formatMajor usage in CheckoutSheet
    # It was: formatMajor: _formatMajor,
    # We should change it to: formatMajor: (val, {symbol = 'GHS '}) => SalesUiUtils.formatMinor(SalesUiUtils.parseTotal(val), symbol: symbol),
    content = content.replace("formatMajor: _formatMajor,", "formatMajor: (val, {symbol = 'GHS '}) => SalesUiUtils.formatMinor(SalesUiUtils.parseTotal(val), symbol: symbol),")

    # 3. Ensure all calls are clean.
    # The previous script might have left some half-replaced strings if it matched partially.
    # Let's check for any remaining "_formatMinor", "_parseTotal" etc. and replace them with static calls.
    # But be careful not to replace them if they are part of "SalesUiUtils.formatMinor".
    
    # We can do a negative lookbehind or just be very specific.
    # Actually, a simple global replace of the private names should work if the declarations are gone.
    # But wait, I already did that in phase1.
    
    # 4. Final check for any mangled strings like "SalesUiUtils.SalesUiUtils.formatMinor"
    content = content.replace("SalesUiUtils.SalesUiUtils.", "SalesUiUtils.")

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

if __name__ == "__main__":
    main()
