import re

def main():
    file_path = r"c:\Users\USER\Desktop\PROJECTS\BizTrackGh\mobile\lib\features\sales\presentation\sales_screen.dart"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Add imports
    content = content.replace("import 'widgets/sales_header.dart';", "import 'widgets/sales_header.dart';\nimport 'widgets/sales_new_sale_view.dart';\nimport 'widgets/sales_history_view.dart';")

    # 2. Find the ListView content block
    # It starts with child: ListView(
    # And ends before "if (_activeTab == SalesViewTab.newSale)" at line 416 (which is the bottom bar)
    
    # Let's target the ListView body.
    # From lines 212 to 411
    
    list_view_body_pattern = r"                                    children: \[\n                                      SalesTabBar\([\s\S]+?                                      \.\.\.historySales\n                                              \.take\(12\)\n                                              \.map\(_buildRecentSaleTile\),\n                                      \],\n                                    \],"
    
    replacement = """                                    children: [
                                      SalesTabBar(
                                        activeTab: _activeTab,
                                        onChanged: (tab) => setState(
                                          () => _activeTab = tab,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (_activeTab == SalesViewTab.newSale)
                                        SalesNewSaleView(
                                          searchCtrl: _searchCtrl,
                                          allItems: allItems,
                                          filteredItems: filtered,
                                          selectedItems: selectedItems,
                                          quickAddItems: quickAddItems,
                                          regularUnselectedItems: regularUnselectedItems,
                                          onPriceTap: _showPriceOverrideDialog,
                                        )
                                      else
                                        SalesHistoryView(
                                          showVoided: _showVoided,
                                          onShowVoidedChanged: (value) async {
                                            setState(() => _showVoided = value);
                                            await ref.read(salesControllerProvider.notifier).refresh(includeVoided: value);
                                          },
                                          historySales: historySales,
                                          buildSaleTile: _buildRecentSaleTile,
                                          isBusy: isBusy,
                                        ),
                                    ],"""

    # We need to find the specific block to replace.
    # It starts at SalesTabBar and ends at the closing bracket of children: [].
    
    start_tag = "                                      SalesTabBar("
    end_tag = "                                      .map(_buildRecentSaleTile),"
    # The end_tag is followed by closing brackets.
    
    start_idx = content.find(start_tag)
    # The children list ends with 3 closing brackets:
    # 411:                                               .map(_buildRecentSaleTile),
    # 412:                                       ],
    # 413:                                     ],
    
    # Let's find the closing bracket of children: []
    end_block = "                                      ...historySales\n                                              .take(12)\n                                              .map(_buildRecentSaleTile),\n                                      ],\n                                    ],"
    if end_block not in content:
        # Fallback for minor variations
        end_block = "                                      ...historySales\n                                              .take(12)\n                                              .map(_buildRecentSaleTile),\n                                      ],"

    # Actually, let's just find the closing bracket after the historySales.map
    map_idx = content.find(".map(_buildRecentSaleTile),")
    if map_idx != -1:
        closing_idx = content.find("],", map_idx)
        if closing_idx != -1:
             # This is the end of the history if block
             final_closing_idx = content.find("],", closing_idx + 1)
             if final_closing_idx != -1:
                  # This is the end of the children list
                  content = content[:start_idx] + replacement + content[final_closing_idx + 2:]

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

if __name__ == "__main__":
    main()
