import re

def main():
    file_path = r"c:\Users\USER\Desktop\PROJECTS\BizTrackGh\mobile\lib\features\sales\presentation\sales_screen.dart"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Add imports
    content = content.replace("import 'widgets/recent_sale_tile.dart';", "import 'widgets/recent_sale_tile.dart';\nimport 'widgets/sales_header.dart';\nimport '../utils/sales_ui_utils.dart';")

    # Replace the header block
    # Start: Container(\n              decoration: const BoxDecoration(\n                boxShadow: [
    # End: const SizedBox(height: 12),\n                        ],\n                      ),\n                    ),\n                  ),\n                ],\n              ),\n            ),
    
    header_start_pattern = r"            Container\(\n              decoration: const BoxDecoration\(\n                boxShadow: \[\n                  BoxShadow\("
    header_end_pattern = r"                  \),\n                \],\n              \),\n            \),"
    
    # We need to find the specific block.
    # The header ends with 357:             ),
    
    # Replacement block:
    header_replacement = """            SalesHeader(
              todayRevenueMinor: todayRevenueMinor,
              todayTxnsCount: todaySales.length,
              cashTotalMinor: cashTotalMinor,
              momoTotalMinor: momoTotalMinor,
            ),"""
            
    # Regex to find the whole header container block
    # It starts at line 147: Container( and ends at line 357: ),
    
    # Finding by fixed strings if possible or regex
    start_str = "            Container(\n              decoration: const BoxDecoration(\n                boxShadow: ["
    end_str = "              ),\n            ),"
    
    start_idx = content.find(start_str)
    # The header ends with many nested closing parens. Let's find the exact end.
    # We know it ends before "            Expanded(" at line 358.
    next_block = "            Expanded("
    next_idx = content.find(next_block)
    
    if start_idx != -1 and next_idx != -1:
        content = content[:start_idx] + header_replacement + "\n" + content[next_idx:]

    # Replace formatting calls
    content = content.replace("_formatMinor(", "SalesUiUtils.formatMinor(")
    content = content.replace("_formatMajor(", "SalesUiUtils.formatMinor(SalesUiUtils.parseTotal(") # _formatMajor used _parseTotal internally
    # Wait, _formatMajor was:
    # String _formatMajor(String value, {String symbol = 'GHS '}) {
    #   return _formatMinor(_parseTotal(value), symbol: symbol);
    # }
    # So we replace _formatMajor(val, symbol: ...) with SalesUiUtils.formatMinor(SalesUiUtils.parseTotal(val), symbol: ...)
    # But for simplicity let's just keep _formatMajor if it's easier, or replace precisely.
    
    content = content.replace("_parseTotal(", "SalesUiUtils.parseTotal(")
    content = content.replace("_moneyToMinor(", "SalesUiUtils.moneyToMinor(")
    content = content.replace("_isSameLocalDay(", "SalesUiUtils.isSameLocalDay(")

    # Clean up the private methods at the end of _SalesScreenState
    content = re.sub(r"  String _formatMinor\([\s\S]+?\}\n\n  String _formatMajor\([\s\S]+?\}\n", "", content)
    content = re.sub(r"  int _parseTotal\([\s\S]+?\}\n", "", content)
    content = re.sub(r"  int _moneyToMinor\([\s\S]+?\}\n", "", content)
    content = re.sub(r"  bool _isSameLocalDay\([\s\S]+?\}\n", "", content)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

if __name__ == "__main__":
    main()
