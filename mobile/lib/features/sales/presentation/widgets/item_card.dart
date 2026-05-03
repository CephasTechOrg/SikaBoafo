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
        final useSingleColumn = constraints.maxWidth < 320;
        // Keep comfortably above ItemCard intrinsic height (selected border + chips).
        final cardExtent = useSingleColumn
            ? 274.0
            : (constraints.maxWidth < 380 ? 298.0 : 286.0);
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
  const ItemCard({
    super.key,
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
    final isLowStock = item.quantityOnHand <= 5;
    final stockTone = isLowStock ? AppColors.danger : AppColors.forest;
    final stockLabel = isLowStock ? 'Low stock' : 'In stock';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected
              ? AppColors.forest.withValues(alpha: 0.38)
              : AppColors.border,
          width: isSelected ? 1.4 : 1,
        ),
        gradient: isSelected
            ? const LinearGradient(
                colors: [
                  Color(0xFFF7FCF9),
                  AppColors.surface,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        boxShadow: isSelected
            ? [
                ...AppShadows.card,
                BoxShadow(
                  color: AppColors.forest.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : AppShadows.subtle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 102,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected
                          ? [
                              const Color(0xFFEAF7EF),
                              const Color(0xFFF8FCF9),
                            ]
                          : [
                              const Color(0xFFF8FAFC),
                              AppColors.surfaceAlt,
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: ItemImage(
                      imageUrl: item.imageUrl,
                      size: 78,
                      fallbackIcon: Icons.inventory_2_outlined,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      isSelected ? 'In sale' : 'Ready',
                      style: TextStyle(
                        color: isSelected ? AppColors.forest : AppColors.inkSoft,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (isLowStock || item.quantityOnHand == 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item.quantityOnHand == 0
                            ? AppColors.danger
                            : AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.quantityOnHand == 0 ? 'Out of stock' : 'Low stock',
                        style: TextStyle(
                          color: item.quantityOnHand == 0
                              ? Colors.white
                              : AppColors.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.name,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.ink,
                height: 1.25,
                letterSpacing: -0.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: onPriceTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '₵$displayPrice',
                        style: TextStyle(
                          color: hasOverride
                              ? AppColors.warning
                              : AppColors.forestDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: hasOverride
                            ? AppColors.warningSoft
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        hasOverride ? 'Edited' : 'Edit price',
                        style: TextStyle(
                          color: hasOverride
                              ? AppColors.warning
                              : AppColors.inkSoft,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: stockTone.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$stockLabel: ${item.quantityOnHand}',
                    style: TextStyle(
                      color: stockTone,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (qty > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$qty in cart',
                      style: const TextStyle(
                        color: AppColors.forest,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                color: isSelected ? AppColors.successSoft : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Row(
                children: [
                  CircleQtyBtn(
                    icon: Icons.remove_rounded,
                    enabled: qty > 0,
                    onTap: onMinus,
                  ),
                  SizedBox(
                    width: 30,
                    child: Center(
                      child: Text(
                        '$qty',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
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
  const CircleQtyBtn({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 38,
          height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: enabled ? AppColors.forest : const Color(0xFFDDDDDD),
            width: 1.1,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.forest : AppColors.muted,
        ),
      ),
      ),
    );
  }
}
