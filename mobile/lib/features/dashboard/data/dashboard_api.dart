import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/services/api_client.dart';
import '../../../data/local/kv_cache_repository.dart';

class MerchantContext {
  const MerchantContext({
    required this.businessName,
    required this.businessType,
    required this.storeName,
    required this.storeLocation,
    required this.timezone,
  });

  final String businessName;
  final String? businessType;
  final String storeName;
  final String? storeLocation;
  final String timezone;

  factory MerchantContext.fromJson(Map<String, dynamic> json) {
    final merchant = (json['merchant'] as Map<String, dynamic>? ?? const {});
    final store = (json['default_store'] as Map<String, dynamic>? ?? const {});
    return MerchantContext(
      businessName: (merchant['business_name'] ?? 'BizTrack Store') as String,
      businessType: merchant['business_type'] as String?,
      storeName: (store['name'] ?? 'Main Store') as String,
      storeLocation: store['location'] as String?,
      timezone: (store['timezone'] ?? 'Africa/Accra') as String,
    );
  }
}

class DashboardApi {
  DashboardApi(this._apiClient, {KvCacheRepository? cache})
      : _cache = cache;

  final ApiClient _apiClient;
  final KvCacheRepository? _cache;

  static const _cacheContextKey = 'dashboard.context';
  static const _cacheSummaryKey = 'dashboard.summary';
  static const _cacheInsightsKey = 'dashboard.insights';
  static const _cacheRecentActivityKey = 'dashboard.recent_activity';

  Future<MerchantContext> fetchContext() async {
    try {
      final response =
          await _apiClient.dio.get<dynamic>('/merchants/me/context');
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Unexpected dashboard context payload.');
      }
      await _cache?.put(_cacheContextKey, jsonEncode(body));
      return MerchantContext.fromJson(body);
    } on DioException catch (e) {
      if (_isOfflineish(e)) {
        final cached = await _cache?.get(_cacheContextKey);
        if (cached != null) {
          final body = jsonDecode(cached);
          if (body is Map<String, dynamic>) {
            return MerchantContext.fromJson(body);
          }
        }
      }
      rethrow;
    }
  }

  Future<DashboardSummary> fetchSummary() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/reports/summary');
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Unexpected dashboard summary payload.');
      }
      await _cache?.put(_cacheSummaryKey, jsonEncode(body));
      return DashboardSummary.fromJson(body);
    } on DioException catch (e) {
      if (_isOfflineish(e)) {
        final cached = await _cache?.get(_cacheSummaryKey);
        if (cached != null) {
          final body = jsonDecode(cached);
          if (body is Map<String, dynamic>) {
            return DashboardSummary.fromJson(body);
          }
        }
      }
      rethrow;
    }
  }

  Future<List<DashboardActivity>> fetchRecentActivity({int limit = 8}) async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/reports/recent-activity',
        queryParameters: {'limit': limit},
      );
      final body = response.data;
      if (body is! List) {
        throw const FormatException('Unexpected recent activity payload.');
      }
      await _cache?.put(_cacheRecentActivityKey, jsonEncode(body));
      return body
          .whereType<Map<String, dynamic>>()
          .map(DashboardActivity.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      if (_isOfflineish(e)) {
        final cached = await _cache?.get(_cacheRecentActivityKey);
        if (cached != null) {
          final body = jsonDecode(cached);
          if (body is List) {
            return body
                .whereType<Map<String, dynamic>>()
                .map(DashboardActivity.fromJson)
                .toList(growable: false);
          }
        }
      }
      rethrow;
    }
  }

  Future<DashboardInsights> fetchInsights({int topN = 5}) async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/reports/insights',
        queryParameters: {'top_n': topN},
      );
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Unexpected dashboard insights payload.');
      }
      await _cache?.put(_cacheInsightsKey, jsonEncode(body));
      return DashboardInsights.fromJson(body);
    } on DioException catch (e) {
      if (_isOfflineish(e)) {
        final cached = await _cache?.get(_cacheInsightsKey);
        if (cached != null) {
          final body = jsonDecode(cached);
          if (body is Map<String, dynamic>) {
            return DashboardInsights.fromJson(body);
          }
        }
      }
      rethrow;
    }
  }

  bool _isOfflineish(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.unknown;
  }

  Future<void> updateMerchantProfile({
    required String businessName,
    String? businessType,
  }) async {
    final response = await _apiClient.dio.patch<dynamic>(
      '/merchants/me',
      data: {
        'business_name': businessName.trim(),
        'business_type': businessType?.trim(),
      },
    );
    if (response.data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected merchant update payload.');
    }
  }

  Future<void> updateDefaultStore({
    required String name,
    String? location,
    required String timezone,
  }) async {
    final response = await _apiClient.dio.patch<dynamic>(
      '/stores/default',
      data: {
        'name': name.trim(),
        'location': location?.trim(),
        'timezone': timezone.trim(),
      },
    );
    if (response.data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected store update payload.');
    }
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.todaySalesTotal,
    required this.todayExpensesTotal,
    required this.todayEstimatedProfit,
    required this.todayGrossProfit,
    required this.debtOutstandingTotal,
    required this.lowStockCount,
    required this.timezone,
  });

  final String todaySalesTotal;
  final String todayExpensesTotal;
  final String todayEstimatedProfit;
  final String todayGrossProfit;
  final String debtOutstandingTotal;
  final int lowStockCount;
  final String timezone;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      todaySalesTotal: '${json['today_sales_total'] ?? '0.00'}',
      todayExpensesTotal: '${json['today_expenses_total'] ?? '0.00'}',
      todayEstimatedProfit: '${json['today_estimated_profit'] ?? '0.00'}',
      todayGrossProfit: '${json['today_gross_profit'] ?? '0.00'}',
      debtOutstandingTotal: '${json['debt_outstanding_total'] ?? '0.00'}',
      lowStockCount: (json['low_stock_count'] ?? 0) as int,
      timezone: (json['timezone'] ?? 'Africa/Accra') as String,
    );
  }
}

class DashboardActivity {
  const DashboardActivity({
    required this.activityType,
    required this.title,
    required this.detail,
    required this.amount,
    required this.createdAt,
    this.itemId,
    this.itemName,
  });

  final String activityType;
  final String title;
  final String detail;
  final String amount;
  final DateTime createdAt;
  final String? itemId;
  final String? itemName;

  factory DashboardActivity.fromJson(Map<String, dynamic> json) {
    return DashboardActivity(
      activityType: (json['activity_type'] ?? 'sale') as String,
      title: (json['title'] ?? 'Activity') as String,
      detail: (json['detail'] ?? '') as String,
      amount: '${json['amount'] ?? '0.00'}',
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      itemId: json['item_id'] as String?,
      itemName: json['item_name'] as String?,
    );
  }
}

class DashboardPeriodSummary {
  const DashboardPeriodSummary({
    required this.periodStartUtc,
    required this.periodEndUtc,
    required this.salesTotal,
    required this.expensesTotal,
    required this.estimatedProfit,
    this.grossProfit = '0.00',
  });

  final DateTime periodStartUtc;
  final DateTime periodEndUtc;
  final String salesTotal;
  final String expensesTotal;
  final String estimatedProfit;
  final String grossProfit;

  factory DashboardPeriodSummary.fromJson(Map<String, dynamic> json) {
    return DashboardPeriodSummary(
      periodStartUtc:
          DateTime.tryParse('${json['period_start_utc'] ?? ''}')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
      periodEndUtc:
          DateTime.tryParse('${json['period_end_utc'] ?? ''}')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
      salesTotal: '${json['sales_total'] ?? '0.00'}',
      expensesTotal: '${json['expenses_total'] ?? '0.00'}',
      estimatedProfit: '${json['estimated_profit'] ?? '0.00'}',
      grossProfit: '${json['gross_profit'] ?? '0.00'}',
    );
  }
}

class DashboardPaymentBreakdown {
  const DashboardPaymentBreakdown({
    required this.paymentMethodLabel,
    required this.paymentMethodDisplay,
    required this.totalAmount,
    required this.saleCount,
  });

  final String paymentMethodLabel;
  final String paymentMethodDisplay;
  final String totalAmount;
  final int saleCount;

  factory DashboardPaymentBreakdown.fromJson(Map<String, dynamic> json) {
    return DashboardPaymentBreakdown(
      paymentMethodLabel: (json['payment_method_label'] ?? 'cash') as String,
      paymentMethodDisplay:
          (json['payment_method_display'] ?? 'Cash') as String,
      totalAmount: '${json['total_amount'] ?? '0.00'}',
      saleCount: (json['sale_count'] ?? 0) as int,
    );
  }
}

class DashboardTopSellingItem {
  const DashboardTopSellingItem({
    required this.itemId,
    required this.itemName,
    required this.quantitySold,
    required this.salesTotal,
  });

  final String itemId;
  final String itemName;
  final int quantitySold;
  final String salesTotal;

  factory DashboardTopSellingItem.fromJson(Map<String, dynamic> json) {
    return DashboardTopSellingItem(
      itemId: (json['item_id'] ?? '') as String,
      itemName: (json['item_name'] ?? 'Item') as String,
      quantitySold: (json['quantity_sold'] ?? 0) as int,
      salesTotal: '${json['sales_total'] ?? '0.00'}',
    );
  }
}

class DashboardInsights {
  const DashboardInsights({
    required this.timezone,
    required this.week,
    required this.month,
    required this.monthlyPaymentBreakdown,
    required this.monthlyTopSellingItems,
  });

  final String timezone;
  final DashboardPeriodSummary week;
  final DashboardPeriodSummary month;
  final List<DashboardPaymentBreakdown> monthlyPaymentBreakdown;
  final List<DashboardTopSellingItem> monthlyTopSellingItems;

  factory DashboardInsights.fromJson(Map<String, dynamic> json) {
    final week = (json['week'] as Map<String, dynamic>? ?? const {});
    final month = (json['month'] as Map<String, dynamic>? ?? const {});
    final paymentRows = json['monthly_payment_breakdown'];
    final topRows = json['monthly_top_selling_items'];
    return DashboardInsights(
      timezone: (json['timezone'] ?? 'Africa/Accra') as String,
      week: DashboardPeriodSummary.fromJson(week),
      month: DashboardPeriodSummary.fromJson(month),
      monthlyPaymentBreakdown: paymentRows is List
          ? paymentRows
              .whereType<Map<String, dynamic>>()
              .map(DashboardPaymentBreakdown.fromJson)
              .toList(growable: false)
          : const [],
      monthlyTopSellingItems: topRows is List
          ? topRows
              .whereType<Map<String, dynamic>>()
              .map(DashboardTopSellingItem.fromJson)
              .toList(growable: false)
          : const [],
    );
  }
}

String humanizeDashboardError(Object error) {
  if (error is FormatException) {
    return error.message;
  }
  if (error is DioException) {
    final detail = error.response?.data;
    if (detail is Map<String, dynamic> && detail['detail'] is String) {
      return detail['detail'] as String;
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Cannot reach backend. Check API URL and network.';
    }
    return error.message ?? 'Failed to load dashboard.';
  }
  return 'Failed to load dashboard.';
}
