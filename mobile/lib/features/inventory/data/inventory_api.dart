import 'package:dio/dio.dart';

import '../../../core/services/api_client.dart';

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
  });

  final String itemId;
  final String name;
  final String defaultPrice;
  final String? sku;
  final String? category;
  final int? lowStockThreshold;
  final bool isActive;
  final int quantityOnHand;

  factory InventoryItemDto.fromJson(Map<String, dynamic> json) {
    return InventoryItemDto(
      itemId: (json['item_id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      defaultPrice: '${json['default_price'] ?? '0.00'}',
      sku: json['sku'] as String?,
      category: json['category'] as String?,
      lowStockThreshold: json['low_stock_threshold'] as int?,
      isActive: (json['is_active'] ?? true) as bool,
      quantityOnHand: (json['quantity_on_hand'] ?? 0) as int,
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
}

String humanizeInventoryError(Object error) {
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
