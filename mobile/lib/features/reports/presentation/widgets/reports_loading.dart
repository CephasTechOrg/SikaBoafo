import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../../shared/widgets/mockup_ui.dart';
import '../../../../shared/widgets/premium_ui.dart';
import '../../../dashboard/data/dashboard_api.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import '../../../debts/data/debts_repository.dart';
import '../../../debts/providers/debts_providers.dart';
import '../../../expenses/data/expenses_repository.dart';
import '../../../expenses/providers/expenses_providers.dart';

class ReportsLoading extends StatelessWidget {
  const ReportsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: const [
        AppSkeleton(height: 42, radius: 14),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: AppSkeletonCard(lines: 2)),
            SizedBox(width: 10),
            Expanded(child: AppSkeletonCard(lines: 2)),
            SizedBox(width: 10),
            Expanded(child: AppSkeletonCard(lines: 2)),
          ],
        ),
        SizedBox(height: 16),
        AppSkeletonCard(lines: 4),
        SizedBox(height: 16),
        AppSkeletonCard(lines: 3),
      ],
    );
  }
}
