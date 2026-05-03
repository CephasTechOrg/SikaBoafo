import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/premium_ui.dart';
import '../../data/inventory_repository.dart';

class InventoryItemDetailSheet extends StatelessWidget {
  const InventoryItemDetailSheet({
    required this.item,
    required this.onEdit,
    required this.onStockIn,
    required this.onAdjust,
    required this.onArchive,
    required this.onRestore,
    required this.onDelete,
    super.key,
  });

  final LocalInventoryItem item;
  final VoidCallback onEdit;
  final VoidCallback onStockIn;
  final VoidCallback onAdjust;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PremiumSheetFrame(
      title: item.name,
      subtitle: item.isActive ? 'Active Inventory Item' : 'Archived Item',
      badge: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (item.isActive ? AppColors.forest : AppColors.muted).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          item.isActive ? Icons.inventory_2_rounded : Icons.archive_outlined,
          color: item.isActive ? AppColors.forest : AppColors.muted,
          size: 20,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: PremiumPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Stock',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.quantityOnHand}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PremiumPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selling Price',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₵${item.defaultPrice}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forestDark,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const PremiumSectionHeading(title: 'Actions'),
          const SizedBox(height: 12),
          if (item.isActive) ...[
            _ActionTile(
              icon: Icons.add_box_rounded,
              title: 'Stock In',
              subtitle: 'Add new units from supplier',
              color: AppColors.forest,
              onTap: () {
                Navigator.of(context).pop();
                onStockIn();
              },
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.tune_rounded,
              title: 'Adjust Stock',
              subtitle: 'Manually correct inventory counts',
              color: const Color(0xFFD97706),
              onTap: () {
                Navigator.of(context).pop();
                onAdjust();
              },
            ),
            const SizedBox(height: 8),
          ],
          _ActionTile(
            icon: Icons.edit_rounded,
            title: 'Edit Item',
            subtitle: 'Change name, price, or category',
            color: AppColors.forestDark,
            onTap: () {
              Navigator.of(context).pop();
              onEdit();
            },
          ),
          const SizedBox(height: 8),
          if (item.isActive)
            _ActionTile(
              icon: Icons.archive_outlined,
              title: 'Archive Item',
              subtitle: 'Hide from active sales',
              color: const Color(0xFF6B7280),
              onTap: () {
                Navigator.of(context).pop();
                onArchive();
              },
            )
          else ...[
            _ActionTile(
              icon: Icons.unarchive_outlined,
              title: 'Restore Item',
              subtitle: 'Make available for sales again',
              color: AppColors.forestDark,
              onTap: () {
                Navigator.of(context).pop();
                onRestore();
              },
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.delete_forever_rounded,
              title: 'Delete Forever',
              subtitle: 'Permanently remove this item',
              color: AppColors.danger,
              onTap: () {
                Navigator.of(context).pop();
                onDelete();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// Re-using the exact existing forms but wrapped properly.
class InventoryIField extends StatelessWidget {
  const InventoryIField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.keyboardType,
    super.key,
  });
  final TextEditingController controller;
  final String label, hint;
  final IconData prefixIcon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, size: 18),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class InventorySaveBtn extends StatelessWidget {
  const InventorySaveBtn({required this.label, this.onTap, this.color, super.key});
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color ?? AppColors.forest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
