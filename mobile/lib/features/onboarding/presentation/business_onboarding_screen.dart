import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/providers/auth_providers.dart';

class BusinessOnboardingScreen extends ConsumerStatefulWidget {
  const BusinessOnboardingScreen({super.key});

  @override
  ConsumerState<BusinessOnboardingScreen> createState() => _BusinessOnboardingScreenState();
}

class _BusinessOnboardingScreenState extends ConsumerState<BusinessOnboardingScreen> {
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
      context.go(AppRoute.home.path);
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
      appBar: AppBar(title: const Text('Set up your business')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Let us capture your business profile so inventory and sales can be linked correctly.',
          ),
          const SizedBox(height: 16),
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
              labelText: 'Business type (optional)',
              hintText: 'Provision Shop',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _storeNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Store name (optional)',
              hintText: 'Main Branch',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: const Text('Complete setup'),
          ),
        ],
      ),
    );
  }
}
