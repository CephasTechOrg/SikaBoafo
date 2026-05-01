import re

def main():
    file_path = r"c:\Users\USER\Desktop\PROJECTS\BizTrackGh\mobile\lib\features\inventory\presentation\inventory_screen.dart"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Remove unused classes _IField, _SaveBtn, _ActionBtn, _ItemCard
    
    # We will just find their class declarations and remove them using regex, or since we know they are at the end,
    # let's just find them by string blocks.
    
    # We know the approximate string contents. To be safe, we can regex remove them.
    content = re.sub(r"class _IField extends StatelessWidget \{[\s\S]+?\}\n\}", "", content)
    content = re.sub(r"class _SaveBtn extends StatelessWidget \{[\s\S]+?\}\n\}", "", content)
    content = re.sub(r"class _ActionBtn extends StatelessWidget \{[\s\S]+?\}\n\}", "", content)
    content = re.sub(r"class _ItemCard extends StatelessWidget \{[\s\S]+?\}\n\}", "", content)
    
    # Also delete the inline header that we missed earlier (replaced by InventoryHeader)
    header_block_start = "          Container(\n            decoration: const BoxDecoration(\n              boxShadow: [\n                BoxShadow("
    header_block_end = "          Expanded(\n            child: Transform.translate("
    
    if header_block_start in content:
        # We can extract the total values logic to pass to InventoryHeader
        # We replace the entire header block with InventoryHeader
        import_str = "import 'widgets/inventory_header.dart';"
        
        # We need to construct the InventoryHeader
        replacement = """          InventoryHeader(
            totalValueMinor: totalValueMinor,
            activeItemsCount: activeItems.length,
            lowStockCount: lowStockCount,
            categoriesCount: categories.length,
          ),
          Expanded(
            child: Transform.translate("""
            
        start_idx = content.find(header_block_start)
        end_idx = content.find(header_block_end)
        if start_idx != -1 and end_idx != -1:
            content = content[:start_idx] + replacement + content[end_idx + len(header_block_end):]

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

if __name__ == "__main__":
    main()
