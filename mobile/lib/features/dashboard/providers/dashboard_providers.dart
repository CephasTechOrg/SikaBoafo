import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/core_providers.dart';
import '../data/dashboard_api.dart';

final dashboardApiProvider = Provider<DashboardApi>((ref) {
  return DashboardApi(ref.watch(apiClientProvider));
});

final merchantContextProvider =
    FutureProvider.autoDispose<MerchantContext>((ref) async {
  return ref.watch(dashboardApiProvider).fetchContext();
});

final dashboardSummaryProvider =
    FutureProvider.autoDispose<DashboardSummary>((ref) async {
  return ref.watch(dashboardApiProvider).fetchSummary();
});

final dashboardRecentActivityProvider =
    FutureProvider.autoDispose<List<DashboardActivity>>((ref) async {
  return ref.watch(dashboardApiProvider).fetchRecentActivity();
});

final dashboardInsightsProvider =
    FutureProvider.autoDispose<DashboardInsights>((ref) async {
  return ref.watch(dashboardApiProvider).fetchInsights();
});
