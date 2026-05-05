import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/data/local_variant.dart';

class ItemGrid extends StatelessWidget {
  const ItemGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSingleColumn = constraints.maxWidth < 240;
        final cardExtent = useSingleColumn ? 296.0 : 300.0;
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
    this.selectedVariantId,
    this.onVariantSelected,
  });

  final LocalInventoryItem item;
  final int qty;
  final String? priceOverride;
  final bool isSelected;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onPriceTap;

  /// The variant chip that is currently selected (before or after adding).
  final String? selectedVariantId;

  /// Called when user taps a variant chip. Null when item has no variants.
  final void Function(LocalVariant)? onVariantSelected;

  @override
  Widget build(BuildContext context) {
    // Resolve display price: variant override → cart override → item default
    final selectedVariant = item.hasVariants && selectedVariantId != null
        ? item.variants.where((v) => v.id == selectedVariantId).firstOrNull
        : null;
    final displayPrice = priceOverride ??
        selectedVariant?.priceOverride ??
        item.defaultPrice;
    final hasOverride =
        priceOverride != null || selectedVariant?.priceOverride != null;
    final isOutOfStock = item.quantityOnHand == 0;
    final isLowStock =
        !isOutOfStock && item.quantityOnHand <= (item.lowStockThreshold ?? 5);
    // Add button is gated: items with variants require a chip selection first.
    final canAdd =
        !isOutOfStock && (!item.hasVariants || selectedVariantId != null);

    return AnimatedContainer(
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
          // ── Product image ─────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            child: Stack(
              children: [
                SizedBox(
                  height: 148,
                  width: double.infinity,
                  child: item.imageUrl != null
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
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
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOutOfStock
                            ? AppColors.danger
                            : AppColors.warning,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Info + controls ───────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
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

                  // ── Variant chips ──────────────────────────────
                  if (item.hasVariants) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 28,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: item.variants
                            .where((v) => v.isActive)
                            .length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 6),
                        itemBuilder: (context, idx) {
                          final activeVariants =
                              item.variants.where((v) => v.isActive).toList();
                          final v = activeVariants[idx];
                          return _VariantChip(
                            label: v.label,
                            selected: selectedVariantId == v.id,
                            onTap: () => onVariantSelected?.call(v),
                          );
                        },
                      ),
                    ),
                  ],

                  const Spacer(),
                  // ── Price + quantity controls ──────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: onPriceTap,
                          child: Text(
                            '₵$displayPrice',
                            style: TextStyle(
                              color: hasOverride
                                  ? AppColors.warning
                                  : AppColors.forestDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (qty > 0) ...[
                        _SmallQtyBtn(
                          icon: Icons.remove_rounded,
                          onTap: onMinus,
                        ),
                        SizedBox(
                          width: 26,
                          child: Center(
                            child: Text(
                              '$qty',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                        _SmallQtyBtn(
                          icon: Icons.add_rounded,
                          enabled: canAdd && qty < item.quantityOnHand,
                          onTap: onPlus,
                        ),
                      ] else
                        _AddButton(
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
    );
  }
}

// ── Private helpers ──────────────────────────────────────────────────────────

class _VariantChip extends StatelessWidget {
  const _VariantChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.forest
              : AppColors.forest.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.forest
                : AppColors.forest.withValues(alpha: 0.22),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.forest,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
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

class _AddButton extends StatelessWidget {
  const _AddButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? AppColors.forest
              : AppColors.muted.withValues(alpha: 0.15),
        ),
        child: Icon(
          Icons.add_rounded,
          color: enabled ? Colors.white : AppColors.muted,
          size: 20,
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

class _SmallQtyBtn extends StatelessWidget {
  const _SmallQtyBtn({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(
            color: enabled ? AppColors.forest : AppColors.border,
            width: 1.2,
          ),
        ),
        child: Icon(
          icon,
          size: 15,
          color: enabled ? AppColors.forest : AppColors.muted,
        ),
      ),
    );
  }
}
