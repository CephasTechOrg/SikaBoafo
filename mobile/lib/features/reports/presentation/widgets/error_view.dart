import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/app_components.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});
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
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                size: 26,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            AppButton.primary(
              label: 'Retry',
              onPressed: onRetry,
              icon: Icons.refresh_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
