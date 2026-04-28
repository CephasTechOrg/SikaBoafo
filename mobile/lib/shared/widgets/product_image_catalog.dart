import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/core_providers.dart';
import '../providers/storage_providers.dart';
import 'product_catalog_sheet.dart';

/// Displays a preview of the selected product image URL and lets the user
/// pick from the official catalog or upload their own photo.
class ProductImagePicker extends ConsumerStatefulWidget {
  const ProductImagePicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  ConsumerState<ProductImagePicker> createState() => _ProductImagePickerState();
}

class _ProductImagePickerState extends ConsumerState<ProductImagePicker> {
  static const _kForest = Color(0xFF0A6B5B);
  bool _uploading = false;

  Future<void> _pickAndUpload(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    final ext = file.name.split('.').last.toLowerCase();
    final filename = '${DateTime.now().millisecondsSinceEpoch}.$ext';

    setState(() => _uploading = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final userId = await db.getActiveUserId() ?? 'unknown';
      final url = await ref.read(supabaseStorageServiceProvider).uploadUserImage(
            userId: userId,
            bytes: bytes,
            filename: filename,
          );
      if (mounted) widget.onChanged(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _showSourcePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 20),
            _SourceTile(
              icon: Icons.photo_library_rounded,
              label: 'Choose from gallery',
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
            _SourceTile(
              icon: Icons.camera_alt_rounded,
              label: 'Take a photo',
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

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
            // Preview thumbnail
            Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _uploading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : widget.selected != null
                      ? CachedNetworkImage(
                          imageUrl: widget.selected!,
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
            // Action buttons
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _uploading
                        ? null
                        : () async {
                            final url =
                                await showProductCatalogSheet(context);
                            if (url != null) widget.onChanged(url);
                          },
                    icon: const Icon(Icons.grid_view_rounded, size: 16),
                    label: const Text('Catalog'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kForest,
                      side: const BorderSide(color: _kForest),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _showSourcePicker,
                    icon: const Icon(Icons.upload_rounded, size: 16),
                    label: const Text('Upload photo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.selected != null) ...[
              const SizedBox(width: 4),
              IconButton(
                onPressed: _uploading ? null : () => widget.onChanged(null),
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

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF0A6B5B), size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
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
