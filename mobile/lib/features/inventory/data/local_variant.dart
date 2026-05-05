class LocalVariant {
  const LocalVariant({
    required this.id,
    required this.itemId,
    required this.label,
    this.priceOverride,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String itemId;
  final String label;

  /// Stored as text (e.g. "12.50") matching defaultPrice convention. Null means
  /// use the parent item's default_price.
  final String? priceOverride;
  final int sortOrder;
  final bool isActive;

  factory LocalVariant.fromRow(Map<String, Object?> row) {
    return LocalVariant(
      id: (row['id'] ?? '') as String,
      itemId: (row['item_id'] ?? '') as String,
      label: (row['label'] ?? '') as String,
      priceOverride: row['price_override'] as String?,
      sortOrder: (row['sort_order'] as int? ?? 0),
      isActive: (row['is_active'] as int? ?? 1) == 1,
    );
  }

  Map<String, Object?> toRow(String itemId) => {
        'id': id,
        'item_id': itemId,
        'label': label,
        'price_override': priceOverride,
        'sort_order': sortOrder,
        'is_active': isActive ? 1 : 0,
      };

  Map<String, Object?> toSyncJson() => {
        'variant_id': id,
        'label': label,
        if (priceOverride != null) 'price_override': priceOverride,
        'sort_order': sortOrder,
        'is_active': isActive,
      };
}
