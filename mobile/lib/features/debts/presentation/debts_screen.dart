import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';

/// Stub for Phase 0. Replaced in Phase 1 with the real list, hero header,
/// tab filter, search bar, and new-debt sheet.
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Debts'),
        backgroundColor: const Color(0xFF041C0B),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (ModalRoute.of(context)?.canPop ?? false) {
              context.pop();
            } else {
              context.go(AppRoute.home.path);
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.subtle,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.handshake_rounded,
                  size: 48,
                  color: AppColors.forest,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Debts coming soon',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'The debt list, customer picker, and payment flow ship in '
                  'Phase 1. Customer data is already available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.push(AppRoute.customers.path),
                  icon: const Icon(Icons.people_alt_rounded, size: 18),
                  label: const Text('Go to Customers'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forestDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
