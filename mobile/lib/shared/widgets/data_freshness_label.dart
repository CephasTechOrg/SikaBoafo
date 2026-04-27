import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/freshness_providers.dart';

class DataFreshnessLabel extends ConsumerWidget {
  const DataFreshnessLabel({
    super.key,
    required this.kvKey,
    this.color,
  });

  final String kvKey;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tsAsync = ref.watch(freshnessTsProvider(kvKey));
    return tsAsync.maybeWhen(
      data: (ts) {
        if (ts == null) return const SizedBox.shrink();
        return Text(
          _format(ts),
          style: TextStyle(
            fontSize: 11,
            color: color ?? Colors.grey,
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  String _format(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
    final days = diff.inDays;
    return days == 1 ? 'Updated yesterday' : 'Updated ${days}d ago';
  }
}
