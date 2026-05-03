import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/product_image_catalog.dart';
import '../../data/inventory_repository.dart';

class InventoryItemCard extends StatelessWidget {
  const InventoryItemCard({
    required this.item,
    required this.onTap,
    super.key,
  });

  final LocalInventoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasThreshold = item.lowStockThreshold != null;
    final bool isLow = hasThreshold && item.quantityOnHand <= item.lowStockThreshold!;
    final bool isOut = item.quantityOnHand <= 0;
    final bool hasIssue = isLow || isOut;
    final Color statusColor = isOut ? AppColors.danger : AppColors.warning;

    final double progress = hasThreshold && item.lowStockThreshold! > 0
        ? (item.quantityOnHand / (item.lowStockThreshold! * 2.0))
            .clamp(0.0, 1.0)
        : item.quantityOnHand > 0
            ? 1.0
            : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ItemImage(
                      imageUrl: item.imageUrl,
                      size: 48,
                      fallbackIcon: Icons.inventory_2_outlined,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!item.isActive) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.dangerSoft,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ARCHIVED',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.danger,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
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
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                '₵${item.defaultPrice}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                  color: AppColors.forestDark,
                                ),
                              ),
                              if (item.category != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: const BoxDecoration(
                                    color: AppColors.border,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    item.category!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (item.sku != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'SKU ${item.sku}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.mutedSoft,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.quantityOnHand}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: hasIssue ? statusColor : AppColors.ink,
                            height: 1,
                          ),
                        ),
                        const Text(
                          'units',
                          style: TextStyle(fontSize: 10, color: AppColors.muted),
                        ),
                        if (hasIssue) ...[
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isOut ? 'Out' : 'Low',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (hasThreshold)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOut
                            ? AppColors.danger
                            : isLow
                                ? AppColors.warning
                                : AppColors.forest,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
