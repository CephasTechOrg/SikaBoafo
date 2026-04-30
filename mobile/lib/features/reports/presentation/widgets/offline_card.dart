import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/app_components.dart';

class OfflineCard extends StatelessWidget {
  const OfflineCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.warning,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Weekly/monthly data unavailable offline.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
