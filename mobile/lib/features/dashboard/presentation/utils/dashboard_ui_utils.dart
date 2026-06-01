import '../../../../features/sales/presentation/utils/sales_ui_utils.dart';

class DashboardUiUtils {
  static String addMoneyStrings(String a, String b) {
    final ma = SalesUiUtils.moneyToMinorSafe(a);
    final mb = SalesUiUtils.moneyToMinorSafe(b);
    return SalesUiUtils.minorToMoney(ma + mb);
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  static String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String? trendBadge(String today, String yesterday) {
    final todayMinor = SalesUiUtils.moneyToMinorSafe(today);
    final yesterdayMinor = SalesUiUtils.moneyToMinorSafe(yesterday);
    if (yesterdayMinor == 0) return null;
    final diff = todayMinor - yesterdayMinor;
    final pct = (diff / yesterdayMinor * 100).round();
    final sign = pct >= 0 ? '+' : '';
    return '$sign$pct% vs yesterday';
  }
}
