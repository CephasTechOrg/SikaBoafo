import 'package:flutter/material.dart';

/// Compact hero metrics that fit in one row (no horizontal swipe).
class HeroStatItem {
  const HeroStatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.accentColor,
  });

  final IconData icon;
  final String value;
  final String label;

  /// Optional icon tint (e.g. overdue warning).
  final Color? accentColor;
}

class HeroStatRow extends StatelessWidget {
  const HeroStatRow({super.key, required this.items});

  final List<HeroStatItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _StatCell(item: items[i])),
        ],
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.item});

  final HeroStatItem item;

  @override
  Widget build(BuildContext context) {
    final iconColor = item.accentColor ?? Colors.white.withValues(alpha: 0.72);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 14, color: iconColor),
          const SizedBox(height: 4),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
