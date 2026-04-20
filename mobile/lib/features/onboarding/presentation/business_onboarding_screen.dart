import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/providers/auth_providers.dart';

class BusinessOnboardingScreen extends ConsumerStatefulWidget {
  const BusinessOnboardingScreen({super.key});

  @override
  ConsumerState<BusinessOnboardingScreen> createState() =>
      _BusinessOnboardingScreenState();
}

class _BusinessOnboardingScreenState
    extends ConsumerState<BusinessOnboardingScreen> {
  final _businessNameCtrl = TextEditingController();
  final _businessTypeCtrl = TextEditingController();
  final _storeNameCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _businessTypeCtrl.dispose();
    _storeNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final businessName = _businessNameCtrl.text.trim();
    if (businessName.length < 2) {
      setState(() => _error = 'Business name is required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).completeOnboarding(
            businessName: businessName,
            businessType: _businessTypeCtrl.text.trim(),
            storeName: _storeNameCtrl.text.trim(),
          );
      if (!mounted) return;
      context.go(AppRoute.setPin.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = humanizeDioError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.shell),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PremiumBadge(
                      label: 'Step 2 of 3',
                      icon: Icons.store_mall_directory_rounded,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Set up your business',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add the business profile and store details that tie sales, inventory, reports, and debts together.',
                      style: TextStyle(
                        color: Color(0xFFD8E8E4),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PremiumSurface(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
                    children: [
                      const PremiumSectionHeading(
                        title: 'Business profile',
                        caption:
                            'This creates the merchant context used throughout the app.',
                      ),
                      const SizedBox(height: 14),
                      PremiumPanel(
                        child: Column(
                          children: [
                            TextField(
                              controller: _businessNameCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Business name',
                                hintText: 'Ama Ventures',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _businessTypeCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Business type',
                                hintText: 'Provision shop',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _storeNameCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Store name',
                                hintText: 'Main branch',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const PremiumPanel(
                        backgroundColor: Color(0xFFF7F3EA),
                        child: Row(
                          children: [
                            Icon(
                              Icons.tips_and_updates_rounded,
                              color: AppColors.gold,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Keep naming simple. These details show up in reports, settings, and your day-to-day business context.',
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 13,
                                  height: 1.38,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        PremiumPanel(
                          backgroundColor: const Color(0xFFFFF0ED),
                          borderColor: const Color(0xFFF4C6BE),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.danger,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: AppColors.danger),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                        label: Text(_submitting ? 'Saving profile...' : 'Continue'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
