import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Phase A stub — replaced with Supabase catalog browser in Phase B.
/// Accepts a Supabase public URL as [selected] and calls [onChanged] with
/// a new URL when the user picks a product.
class ProductImagePicker extends StatelessWidget {
  const ProductImagePicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;

  static const _kForest = Color(0xFF0A6B5B);

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
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: selected != null
                  ? CachedNetworkImage(
                      imageUrl: selected!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Color(0xFF94A3B8),
                      ),
                    )
                  : const Icon(
                      Icons.image_outlined,
                      color: Color(0xFFB0B7C3),
                      size: 28,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Product catalog coming in the next update.'),
                    duration: Duration(seconds: 2),
                  ),
                ),
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: const Text('Choose from catalog'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kForest,
                  side: const BorderSide(color: _kForest),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (selected != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => onChanged(null),
                icon: const Icon(Icons.close_rounded, size: 18),
                color: const Color(0xFF94A3B8),
                tooltip: 'Remove image',
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Displays an item's product image from a Supabase URL, or a fallback icon.
class ItemImage extends StatelessWidget {
  const ItemImage({
    required this.imageUrl,
    required this.size,
    this.bgColor,
    this.iconColor,
    this.fallbackIcon,
    this.borderRadius,
    super.key,
  });

  final String? imageUrl;
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
      child: imageUrl != null
          ? ClipRRect(
              borderRadius: radius,
              child: Padding(
                padding: EdgeInsets.all(size * 0.08),
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => Center(
                    child: SizedBox(
                      width: size * 0.35,
                      height: size * 0.35,
                      child: const CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Icon(
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
