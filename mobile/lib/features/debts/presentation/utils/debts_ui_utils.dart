import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/debts_repository.dart';
import '../../../../app/theme/app_theme.dart';

abstract final class DebtsUiUtils {
  /// Derives display status from the record's backend status + due date.
  static String receivableStatus(LocalReceivableRecord r) {
    if (r.status == 'settled') return 'settled';
    if (r.status == 'cancelled') return 'cancelled';
    final d = r.dueDateIso;
    if (d != null && d.isNotEmpty) {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final soon = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().add(const Duration(days: 7)));
      if (d.compareTo(today) < 0) return 'overdue';
      if (d.compareTo(soon) <= 0) return 'due_soon';
    }
    return r.status == 'partially_paid' ? 'partially_paid' : 'open';
  }

  /// Converts a decimal money string to minor units (pesewas).
  static int moneyToMinor(String value) {
    final raw = value.trim();
    final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
    if (match == null) return 0;
    final parts = raw.split('.');
    final major = int.parse(parts[0]);
    final dec = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
    return (major * 100) + int.parse(dec);
  }

  /// Formats a decimal string to 2dp (e.g. "100.5" → "100.50").
  static String fmtAmount(String v) {
    final d = double.tryParse(v) ?? 0;
    return d.toStringAsFixed(2);
  }

  /// Formats an ISO date string for display (e.g. "2025-01-15" → "15 Jan 2025").
  static String fmtDueDate(String? iso, {String fallback = 'No due date'}) {
    if (iso == null || iso.isEmpty) return fallback;
    try {
      return DateFormat('d MMM yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  /// Formats a DateTime to a user-friendly string (e.g. "15 Jan 2025, 2:30 PM").
  static String fmtDateTime(DateTime value) =>
      DateFormat('d MMM yyyy, h:mm a').format(value);

  /// Human-readable label for a debt status.
  static String statusLabel(String status) => switch (status) {
        'settled' => 'Settled',
        'cancelled' => 'Cancelled',
        'partially_paid' => 'Partial',
        _ => 'Open',
      };

  /// Color for a debt status badge.
  static Color statusColor(String status) => switch (status) {
        'settled' => AppColors.success,
        'cancelled' => AppColors.muted,
        'partially_paid' => AppColors.warning,
        _ => AppColors.gold,
      };

  /// Color for a sync status indicator.
  static Color syncColor(String status) => switch (status) {
        'applied' || 'duplicate' => AppColors.success,
        'failed' => AppColors.danger,
        'conflict' => AppColors.warning,
        'sending' => AppColors.sky,
        _ => AppColors.warning,
      };

  /// User-facing label for a sync status.
  static String syncLabel(String status) => switch (status) {
        'applied' || 'duplicate' => 'Synced',
        'sending' => 'Syncing…',
        'failed' => 'Failed',
        'conflict' => 'Conflict',
        _ => 'Pending',
      };

  /// Human-readable label for a payment method key.
  static String paymentMethodLabel(String value) => switch (value) {
        'mobile_money' => 'Mobile Money',
        'bank_transfer' => 'Bank Transfer',
        _ => 'Cash',
      };
}
