import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/services/api_client.dart';
import 'local_variant.dart';

class InventoryItemDto {
  const InventoryItemDto({
    required this.itemId,
    required this.name,
    required this.defaultPrice,
    required this.quantityOnHand,
    this.sku,
    this.category,
    this.lowStockThreshold,
    this.isActive = true,
    this.version = 1,
    this.imageUrl,
    this.variants = const [],
  });

  final String itemId;
  final String name;
  final String defaultPrice;
  final String? sku;
  final String? category;
  final int? lowStockThreshold;
  final bool isActive;
  final int quantityOnHand;
  final int version;
  final String? imageUrl;
  final List<LocalVariant> variants;

  factory InventoryItemDto.fromJson(Map<String, dynamic> json) {
    final rawVariants = json['variants'] as List<dynamic>? ?? [];
    final itemId = (json['item_id'] ?? '') as String;
    return InventoryItemDto(
      itemId: itemId,
      name: (json['name'] ?? '') as String,
      defaultPrice: '${json['default_price'] ?? '0.00'}',
      sku: json['sku'] as String?,
      category: json['category'] as String?,
      lowStockThreshold: json['low_stock_threshold'] as int?,
      isActive: (json['is_active'] ?? true) as bool,
      quantityOnHand: (json['quantity_on_hand'] ?? 0) as int,
      version: (json['version'] as int?) ?? 1,
      imageUrl: json['image_url'] as String?,
      variants: rawVariants
          .whereType<Map<String, dynamic>>()
          .map((v) => LocalVariant(
                id: (v['variant_id'] ?? '') as String,
                itemId: itemId,
                label: (v['label'] ?? '') as String,
                priceOverride: v['price_override']?.toString(),
                sortOrder: (v['sort_order'] as int?) ?? 0,
                isActive: (v['is_active'] ?? true) as bool,
              ))
          .toList(growable: false),
    );
  }
}

class InventoryApi {
  InventoryApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<InventoryItemDto>> fetchItems() async {
    final response = await _apiClient.dio.get<dynamic>('/items');
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Unexpected inventory list payload.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(InventoryItemDto.fromJson)
        .toList(growable: false);
  }

  Future<void> deleteItem(String itemId) async {
    await _apiClient.dio.delete<void>('/items/$itemId');
  }
}

String humanizeInventoryError(Object error) {
  if (error is TimeoutException) {
    return error.message ??
        'Still syncing with the server. Check your connection and try again.';
  }
  if (error is StateError) {
    return error.message;
  }
  if (error is ArgumentError) {
    return error.message?.toString() ?? 'Invalid inventory input.';
  }
  if (error is FormatException) {
    return error.message;
  }
  if (error is DioException) {
    final detail = error.response?.data;
    if (detail is Map<String, dynamic> && detail['detail'] is String) {
      return detail['detail'] as String;
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Cannot reach backend. Working offline.';
    }
    return error.message ?? 'Inventory request failed.';
  }
  return 'Inventory request failed.';
}
