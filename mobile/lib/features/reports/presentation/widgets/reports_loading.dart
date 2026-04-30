import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_components.dart';

class ReportsLoading extends StatelessWidget {
  const ReportsLoading({super.key});

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
