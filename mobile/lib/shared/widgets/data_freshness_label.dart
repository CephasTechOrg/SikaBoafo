import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/freshness_providers.dart';

/// Displays a human-readable "Updated X ago" label for a KV cache timestamp.
///
/// Uses a 60-second periodic ticker so the relative time text stays accurate
/// without requiring a full parent rebuild.
class DataFreshnessLabel extends ConsumerStatefulWidget {
  const DataFreshnessLabel({
    super.key,
    required this.kvKey,
    this.color,
  });

  final String kvKey;
  final Color? color;

  @override
  ConsumerState<DataFreshnessLabel> createState() => _DataFreshnessLabelState();
}

class _DataFreshnessLabelState extends ConsumerState<DataFreshnessLabel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Refresh the relative label every 60 seconds so "Updated just now" ages
    // correctly to "Updated 1m ago", "Updated 2m ago", etc.
    _ticker = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tsAsync = ref.watch(freshnessTsProvider(widget.kvKey));
    return tsAsync.maybeWhen(
      data: (ts) {
        if (ts == null) return const SizedBox.shrink();
        return Text(
          _format(ts),
          style: TextStyle(
            fontSize: 11,
            color: widget.color ?? Colors.grey,
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  String _format(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inSeconds < 30) return 'Updated just now';
    if (diff.inMinutes < 1) return 'Updated moments ago';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
    final days = diff.inDays;
    return days == 1 ? 'Updated yesterday' : 'Updated ${days}d ago';
  }
}
