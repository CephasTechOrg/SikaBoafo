import 'package:flutter/material.dart';

// All standard product image assets bundled with the app.
const kProductCatalog = <({String asset, String label})>[
  (asset: 'assets/products/Ghacem_cement.png', label: 'Cement'),
  (asset: 'assets/products/bar_soap.png', label: 'Bar Soap'),
  (asset: 'assets/products/darkandlovely_beauty.png', label: 'Beauty'),
  (asset: 'assets/products/exercisebook.png', label: 'Exercise Bk'),
  (asset: 'assets/products/geisha_soap.png', label: 'Geisha'),
  (asset: 'assets/products/ginotomato.png', label: 'Gino Tomato'),
  (asset: 'assets/products/idealmilk.png', label: 'Ideal Milk'),
  (asset: 'assets/products/indomie.png', label: 'Indomie'),
  (asset: 'assets/products/kivo_gari.png', label: 'Kivo Gari'),
  (asset: 'assets/products/magi.png', label: 'Maggi'),
  (asset: 'assets/products/malt.png', label: 'Malt'),
  (asset: 'assets/products/milo.png', label: 'Milo'),
];

/// Horizontal scroll picker for the 12 bundled product images.
/// [selected] is the current asset path, or null for "no image".
class ProductImagePicker extends StatelessWidget {
  const ProductImagePicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PRODUCT IMAGE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 74,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _ImageTile(
                asset: null,
                label: 'None',
                isSelected: selected == null,
                onTap: () => onChanged(null),
              ),
              ...kProductCatalog.map(
                (p) => _ImageTile(
                  asset: p.asset,
                  label: p.label,
                  isSelected: selected == p.asset,
                  onTap: () => onChanged(selected == p.asset ? null : p.asset),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.asset,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String? asset;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  static const _kForest = Color(0xFF0A6B5B);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 58,
        decoration: BoxDecoration(
          color: isSelected
              ? _kForest.withValues(alpha: 0.10)
              : const Color(0xFFF6F7F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _kForest : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (asset == null)
              Icon(
                Icons.hide_image_outlined,
                size: 26,
                color: isSelected ? _kForest : const Color(0xFF94A3B8),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  asset!,
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    size: 26,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isSelected ? _kForest : const Color(0xFF94A3B8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the item's product image inside a container, or a coloured icon fallback.
/// Uses [BoxFit.contain] with inner padding so product art is never cropped.
class ItemImage extends StatelessWidget {
  const ItemImage({
    required this.imageAsset,
    required this.size,
    this.bgColor,
    this.iconColor,
    this.fallbackIcon,
    this.borderRadius,
    super.key,
  });

  final String? imageAsset;
  final double size;
  final Color? bgColor;
  final Color? iconColor;
  final IconData? fallbackIcon;
  final BorderRadius? borderRadius;

  static const _kNeutralBg = Color(0xFFF3F4F6);

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size * 0.26);
    final bg = bgColor ?? _kNeutralBg;
    final fg = iconColor ?? const Color(0xFFB0B7C3);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      child: imageAsset != null
          ? ClipRRect(
              borderRadius: radius,
              child: Padding(
                padding: EdgeInsets.all(size * 0.08),
                child: Image.asset(
                  imageAsset!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    fallbackIcon ?? Icons.inventory_2_outlined,
                    color: fg,
                    size: size * 0.45,
                  ),
                ),
              ),
            )
          : Icon(
              fallbackIcon ?? Icons.inventory_2_outlined,
              color: fg,
              size: size * 0.45,
            ),
    );
  }
}
