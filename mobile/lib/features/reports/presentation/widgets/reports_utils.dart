import 'package:intl/intl.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../debts/data/debts_repository.dart';

// ── Chart palette ─────────────────────────────────────────────────────────────

const kPieColors = [
  AppColors.forest,
  AppColors.info,
  AppColors.warning,
  AppColors.gold,
  AppColors.danger,
  AppColors.success,
  AppColors.muted,
];

// ── Helpers ───────────────────────────────────────────────────────────────────

int toMinor(String v) {
  final raw = v.trim();
  final m = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
  if (m == null) return 0;
  final p = raw.split('.');
  final dec = p.length == 2 ? p[1].padRight(2, '0') : '00';
  return int.parse(p[0]) * 100 + int.parse(dec);
}

String fmtMoney(String v) => '\u20B5$v';

// O(n) single-pass debt aging — YYYY-MM-DD lexicographic order is valid.
class DebtAging {
  const DebtAging(
      {required this.overdue,
      required this.dueSoon,
      required this.current,
      required this.noDue});
  final int overdue, dueSoon, current, noDue;
  int get total => overdue + dueSoon + current + noDue;
}

DebtAging computeAging(List<LocalReceivableRecord> receivables) {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final soon = DateFormat('yyyy-MM-dd')
      .format(DateTime.now().add(const Duration(days: 7)));
  int ov = 0, ds = 0, cu = 0, nd = 0;
  for (final r in receivables) {
    if (r.status != 'open') continue;
    final d = r.dueDateIso;
    if (d == null || d.isEmpty) {
      nd++;
    } else if (d.compareTo(today) < 0) {
      ov++;
    } else if (d.compareTo(soon) <= 0) {
      ds++;
    } else {
      cu++;
    }
  }
  return DebtAging(overdue: ov, dueSoon: ds, current: cu, noDue: nd);
}

