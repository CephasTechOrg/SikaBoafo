import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/product_image_catalog.dart';
import '../../../inventory/data/inventory_repository.dart';

class ItemGrid extends StatelessWidget {
  const ItemGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep two cards per row on standard mobile widths.
        final useSingleColumn = constraints.maxWidth < 300;
        final cardExtent = useSingleColumn
            ? 200.0
            : (constraints.maxWidth < 360 ? 226.0 : 214.0);
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: useSingleColumn ? 1 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: cardExtent,
          ),
          children: children,
        );
      },
    );
  }
}

class ItemCard extends StatelessWidget {
  const ItemCard({super.key, 
    required this.item,
    required this.qty,
    required this.priceOverride,
    required this.isSelected,
    required this.onMinus,
    required this.onPlus,
    required this.onPriceTap,
  });

  final LocalInventoryItem item;
  final int qty;
  final String? priceOverride;
  final bool isSelected;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onPriceTap;

  @override
  Widget build(BuildContext context) {
    final displayPrice = priceOverride ?? item.defaultPrice;
    final hasOverride = priceOverride != null;
    final stockTone =
        item.quantityOnHand <= 5 ? AppColors.danger : AppColors.success;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? AppColors.forest : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: isSelected ? AppShadows.card : AppShadows.subtle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 14,
              child: item.quantityOnHand <= 5
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Low',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.center,
              child: ItemImage(
                imageUrl: item.imageUrl,
                size: 74,
                fallbackIcon: Icons.inventory_2_outlined,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: AppColors.ink,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onPriceTap,
                    child: Text(
                      hasOverride ? '₵$displayPrice ✎' : '₵$displayPrice',
                      style: TextStyle(
                        color: hasOverride
                            ? AppColors.warning
                            : AppColors.forest,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: stockTone.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${item.quantityOnHand}',
                    style: TextStyle(
                      color: stockTone,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFFF0FAF3) : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  CircleQtyBtn(
                    icon: Icons.remove_rounded,
                    enabled: qty > 0,
                    onTap: onMinus,
                  ),
                  SizedBox(
                    width: 32,
                    child: Center(
                      child: Text(
                        '$qty',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                  CircleQtyBtn(
                    icon: Icons.add_rounded,
                    enabled: qty < item.quantityOnHand,
                    onTap: onPlus,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CircleQtyBtn extends StatelessWidget {
  const CircleQtyBtn({super.key, 
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: enabled ? AppColors.forest : const Color(0xFFDDDDDD),
            width: 1.2,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppColors.forest : AppColors.muted,
        ),
      ),
    );
  }
}
