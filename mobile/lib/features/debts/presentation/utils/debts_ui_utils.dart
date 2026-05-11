import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Money + status helpers reused across debt screens and sheets.
abstract final class DebtsUiUtils {
  /// Parse a "0.00" decimal string to minor units (cents). Returns 0 if
  /// the input is malformed — never throws.
  static int amountToMinor(String value) {
    final raw = value.trim();
    final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
    if (match == null) return 0;
    final parts = raw.split('.');
    final major = int.parse(parts[0]);
    final dec = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
    return (major * 100) + int.parse(dec);
  }

  /// Format minor units as "₵1,234.56".
  static String formatMinor(int minor) {
    final negative = minor < 0;
    final abs = minor.abs();
    final major = abs ~/ 100;
    final cents = (abs % 100).toString().padLeft(2, '0');
    final withCommas = _groupThousands(major);
    return '${negative ? '-' : ''}₵$withCommas.$cents';
  }

  /// Format a decimal-string amount ("125.50") as "₵125.50".
  static String formatAmount(String amount) {
    return formatMinor(amountToMinor(amount));
  }

  /// Returns true if the given ISO date is strictly before today (local).
  /// Treats null / malformed input as "not overdue".
  static bool isOverdue(String? dueDateIso) {
    if (dueDateIso == null || dueDateIso.isEmpty) return false;
    final parsed = DateTime.tryParse(dueDateIso);
    if (parsed == null) return false;
    final today = DateTime.now();
    final dueLocal = parsed.toLocal();
    final dueDay = DateTime(dueLocal.year, dueLocal.month, dueLocal.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return dueDay.isBefore(todayDay);
  }

  /// Days until / past due. Negative = overdue, 0 = today, positive = upcoming.
  /// Returns null if no due date.
  static int? daysUntilDue(String? dueDateIso) {
    if (dueDateIso == null || dueDateIso.isEmpty) return null;
    final parsed = DateTime.tryParse(dueDateIso);
    if (parsed == null) return null;
    final today = DateTime.now();
    final dueLocal = parsed.toLocal();
    final dueDay = DateTime(dueLocal.year, dueLocal.month, dueLocal.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return dueDay.difference(todayDay).inDays;
  }

  /// Human label + colours for a receivable status. Overdue is derived
  /// from the due date when status is `open` / `partially_paid`.
  static DebtStatusVisual statusVisualFor({
    required String status,
    required String? dueDateIso,
  }) {
    if (status == 'settled') {
      return const DebtStatusVisual(
        label: 'Settled',
        foreground: AppColors.success,
        background: AppColors.successSoft,
      );
    }
    if (status == 'cancelled') {
      return const DebtStatusVisual(
        label: 'Cancelled',
        foreground: AppColors.muted,
        background: AppColors.surfaceAlt,
      );
    }
    if (status == 'partially_paid') {
      if (isOverdue(dueDateIso)) {
        return const DebtStatusVisual(
          label: 'Partial · Overdue',
          foreground: AppColors.danger,
          background: AppColors.dangerSoft,
        );
      }
      return const DebtStatusVisual(
        label: 'Partial',
        foreground: AppColors.warning,
        background: AppColors.warningSoft,
      );
    }
    if (isOverdue(dueDateIso)) {
      return const DebtStatusVisual(
        label: 'Overdue',
        foreground: AppColors.danger,
        background: AppColors.dangerSoft,
      );
    }
    return const DebtStatusVisual(
      label: 'Open',
      foreground: AppColors.warning,
      background: AppColors.warningSoft,
    );
  }

  /// Human-readable label for an ISO due date. Shows "Today", "Tomorrow",
  /// "Yesterday", or "23 May 2026" otherwise.
  static String formatDueLabel(String dueDateIso) {
    final parsed = DateTime.tryParse(dueDateIso);
    if (parsed == null) return dueDateIso;
    final local = parsed.toLocal();
    final diff = daysUntilDue(dueDateIso);
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return '${local.day} ${_monthShort(local.month)} ${local.year}';
  }

  /// Title-case the payment method label coming back from the API.
  static String paymentMethodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'mobile_money':
        return 'Mobile money';
      case 'bank_transfer':
        return 'Bank transfer';
      default:
        return method.replaceAll('_', ' ');
    }
  }

  static String _monthShort(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > 12) return '';
    return names[month - 1];
  }

  static String _groupThousands(int value) {
    final s = value.toString();
    if (s.length <= 3) return s;
    final buffer = StringBuffer();
    var count = 0;
    for (var i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buffer.write(',');
        count = 0;
      }
    }
    return buffer.toString().split('').reversed.join();
  }
}

class DebtStatusVisual {
  const DebtStatusVisual({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;
}
