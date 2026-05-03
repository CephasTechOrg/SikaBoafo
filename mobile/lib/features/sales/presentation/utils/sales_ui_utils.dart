import 'package:intl/intl.dart';

class SalesUiUtils {
  static String formatMinor(int minor, {String symbol = 'GHS '}) {
    final value = minor / 100;
    return NumberFormat.currency(symbol: symbol, decimalDigits: 2).format(value);
  }

  static int parseTotal(String value) {
    final parts = value.split('.');
    final major = int.tryParse(parts[0]) ?? 0;
    final minor =
        parts.length == 2 ? (int.tryParse(parts[1].padRight(2, '0')) ?? 0) : 0;
    return major * 100 + minor;
  }

  static int moneyToMinor(String value) {
    final raw = value.trim();
    final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
    if (match == null) return 0;
    final parts = raw.split('.');
    final major = int.parse(parts[0]);
    final decimals = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
    return (major * 100) + int.parse(decimals);
  }

  static int moneyToMinorSafe(String value) {
    final raw = value.trim();
    final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
    if (match == null) return 0;
    final parts = raw.split('.');
    final major = int.tryParse(parts[0]) ?? 0;
    final decimals = parts.length == 2 ? (parts[1].padRight(2, '0')) : '00';
    return (major * 100) + (int.tryParse(decimals) ?? 0);
  }

  static bool isSameLocalDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String minorToMoney(int minor) {
    return (minor / 100).toStringAsFixed(2);
  }

  static String greetingFor(DateTime moment) {
    final hour = moment.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String paymentLabel(String raw) {
    return switch (raw) {
      'mobile_money' => 'Mobile Money',
      'bank_transfer' => 'Bank Transfer',
      _ => 'Cash',
    };
  }

  static double fraction(int value, int total) {
    if (total <= 0) return 0;
    return (value / total).clamp(0, 1).toDouble();
  }
}
