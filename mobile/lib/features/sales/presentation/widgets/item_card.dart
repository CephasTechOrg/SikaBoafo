import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../inventory/data/inventory_repository.dart';

class ItemGrid extends StatelessWidget {
  const ItemGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSingleColumn = constraints.maxWidth < 240;
        const cardExtent = 216.0;
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
    required this.onTap,
  });

  final LocalInventoryItem item;
  final int qty;
  final String? priceOverride;
  final bool isSelected;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onPriceTap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayPrice = priceOverride ?? item.defaultPrice;
    final hasOverride = priceOverride != null;
    final isOutOfStock = item.quantityOnHand == 0;
    final isLowStock =
        !isOutOfStock && item.quantityOnHand <= (item.lowStockThreshold ?? 5);
    final canAdd = !isOutOfStock;

    return GestureDetector(
      onTap: canAdd ? onTap : null,
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? AppColors.forest.withValues(alpha: 0.38)
              : AppColors.border,
          width: isSelected ? 1.4 : 1,
        ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            child: Stack(
              children: [
                Container(
                  height: 96,
                  width: double.infinity,
                  color: isSelected
                      ? const Color(0xFFEAF7EF)
                      : const Color(0xFFF8FAFC),
                  child: item.imageUrl != null
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              _FallbackImageBox(isSelected: isSelected),
                        )
                      : _FallbackImageBox(isSelected: isSelected),
                ),
                if (item.category != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.forest
                            : Colors.white.withValues(alpha: 0.93),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        item.category!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.forest,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                if (isOutOfStock || isLowStock)
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? AppColors.danger
                            : const Color(0xFFBE8A2C),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isOutOfStock
                            ? 'Out'
                            : '${item.quantityOnHand} left',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onPriceTap,
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: AppColors.ink,
                        height: 1.25,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onPriceTap,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₵$displayPrice',
                                style: TextStyle(
                                  color: hasOverride
                                      ? AppColors.warning
                                      : const Color(0xFF0F7A4A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (!isLowStock && !isOutOfStock)
                                Text(
                                  '${item.quantityOnHand} in stock',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF9AA3AF),
                                    height: 1.3,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (qty > 0)
                        _MockupStepper(
                          qty: qty,
                          onMinus: onMinus,
                          onPlus: canAdd && qty < item.quantityOnHand
                              ? onPlus
                              : null,
                        )
                      else
                        _MockupAddButton(
                          enabled: canAdd,
                          onTap: onPlus,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}

class _FallbackImageBox extends StatelessWidget {
  const _FallbackImageBox({required this.isSelected});
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isSelected ? const Color(0xFFEAF7EF) : const Color(0xFFF8FAFC),
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 48,
          color: isSelected
              ? AppColors.forest.withValues(alpha: 0.4)
              : AppColors.muted.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// ── Mockup-style add button (green-tint square) ───────────────────────────────

class _MockupAddButton extends StatelessWidget {
  const _MockupAddButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFFEAF6EF)
              : const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.add_rounded,
          size: 21,
          color: enabled ? const Color(0xFF0F7A4A) : const Color(0xFF9AA3AF),
        ),
      ),
    );
  }
}

// ── Mockup-style stepper (dark-green-900 pill) ────────────────────────────────

class _MockupStepper extends StatelessWidget {
  const _MockupStepper({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF073B2A),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onMinus,
            child: const SizedBox(
              width: 34,
              height: 36,
              child: Center(
                child: Text(
                  '−',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 22,
            child: Center(
              child: Text(
                '$qty',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPlus,
            child: SizedBox(
              width: 34,
              height: 36,
              child: Center(
                child: Icon(
                  Icons.add_rounded,
                  size: 17,
                  color: onPlus != null
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        ],
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

