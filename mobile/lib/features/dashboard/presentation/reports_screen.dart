import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../data/dashboard_api.dart';
import '../providers/dashboard_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F4E43), Color(0xFF1A6B5B), AppColors.canvas],
            stops: [0.0, 0.22, 0.22],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: summaryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ReportErrorView(
              message: humanizeDashboardError(error),
              onRetry: () => ref.invalidate(dashboardSummaryProvider),
            ),
            data: (summary) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(dashboardSummaryProvider);
                await ref.read(dashboardSummaryProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _ReportHero(summary: summary),
                  const SizedBox(height: 16),
                  _ReportMetricTile(
                    icon: Icons.shopping_basket_rounded,
                    iconColor: AppColors.amber,
                    label: 'Sales',
                    value: 'GHS ${summary.todaySalesTotal}',
                  ),
                  const SizedBox(height: 10),
                  _ReportMetricTile(
                    icon: Icons.work_outline_rounded,
                    iconColor: AppColors.coral,
                    label: 'Expenses',
                    value: 'GHS ${summary.todayExpensesTotal}',
                  ),
                  const SizedBox(height: 10),
                  _ReportMetricTile(
                    icon: Icons.trending_up_rounded,
                    iconColor: AppColors.success,
                    label: 'Profit',
                    value: 'GHS ${summary.todayEstimatedProfit}',
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Sales vs Expenses',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  _ReportChartCard(summary: summary),
                  const SizedBox(height: 18),
                  Text(
                    'Operational Snapshot',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 420;
                      final tileWidth = isCompact
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 10) / 2;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: tileWidth,
                            child: _MiniReportCard(
                              label: 'Debt Outstanding',
                              value: 'GHS ${summary.debtOutstandingTotal}',
                              tint: AppColors.coral,
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: _MiniReportCard(
                              label: 'Low Stock',
                              value: '${summary.lowStockCount}',
                              tint: AppColors.forest,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportHero extends StatelessWidget {
  const _ReportHero({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFECE7DA), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F2E28),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Report', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'Today in ${summary.timezone}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.analytics_rounded,
              color: AppColors.forestDark,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportMetricTile extends StatelessWidget {
  const _ReportMetricTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _ReportChartCard extends StatelessWidget {
  const _ReportChartCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final sales = _parseMoney(summary.todaySalesTotal);
    final expenses = _parseMoney(summary.todayExpensesTotal);
    final profit = _parseMoney(summary.todayEstimatedProfit);
    final peak = math.max<double>(1.0, math.max<double>(sales, math.max<double>(expenses, profit)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _ChartBar(
                      label: 'Sales',
                      value: sales,
                      maxValue: peak,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ChartBar(
                      label: 'Expenses',
                      value: expenses,
                      maxValue: peak,
                      color: AppColors.coral,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ChartBar(
                      label: 'Profit',
                      value: profit,
                      maxValue: peak,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: AppColors.forest, label: 'Sales'),
                SizedBox(width: 16),
                _LegendDot(color: AppColors.coral, label: 'Expenses'),
                SizedBox(width: 16),
                _LegendDot(color: AppColors.gold, label: 'Profit'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _parseMoney(String value) => double.tryParse(value) ?? 0;
}

class _ChartBar extends StatelessWidget {
  const _ChartBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final String label;
  final double value;
  final double maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0).toDouble();
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          value.toStringAsFixed(0),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _MiniReportCard extends StatelessWidget {
  const _MiniReportCard({
    required this.label,
    required this.value,
    required this.tint,
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 20),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class _ReportErrorView extends StatelessWidget {
  const _ReportErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
