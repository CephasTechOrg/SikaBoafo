import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../providers/debts_providers.dart';

class ReceiveRepaymentScreen extends ConsumerStatefulWidget {
  const ReceiveRepaymentScreen({required this.receivableId, super.key});

  final String receivableId;

  @override
  ConsumerState<ReceiveRepaymentScreen> createState() =>
      _ReceiveRepaymentScreenState();
}

class _ReceiveRepaymentScreenState
    extends ConsumerState<ReceiveRepaymentScreen> {
  final _amountCtrl = TextEditingController();
  String _method = 'cash';
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(receivableDetailProvider(widget.receivableId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.shell),
        child: Column(
          children: [
            PremiumPageHeader(
              title: 'Receive Payment',
              subtitle: 'Apply a repayment and keep the outstanding balance accurate.',
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              badge: const PremiumBadge(
                label: 'Debt collection',
                icon: Icons.payments_rounded,
              ),
            ),
            Expanded(
              child: PremiumSurface(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    detailAsync.when(
                      loading: () => const PremiumPanel(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                      error: (_, __) => PremiumPanel(
                        backgroundColor: const Color(0xFFFFF0ED),
                        borderColor: const Color(0xFFF4C6BE),
                        child: Text(
                          'Could not load debt details.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.danger),
                        ),
                      ),
                      data: (detail) {
                        if (detail == null) {
                          return const PremiumEmptyState(
                            title: 'Debt record not found.',
                            message:
                                'This receivable is no longer available in the active debt list.',
                            icon: Icons.search_off_rounded,
                          );
                        }
                        final row = detail.record;
                        return Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            gradient: const LinearGradient(
                              colors: [AppColors.forestDark, AppColors.forest],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: kCardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.customerName,
                                style: const TextStyle(
                                  color: Color(0xFFD7F3EA),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'GHS ${row.outstandingAmount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Outstanding',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.74),
                                  fontSize: 13,
                                ),
                              ),
                              if (row.dueDateIso != null) ...[
                                const SizedBox(height: 12),
                                PremiumBadge(
                                  label: 'Due ${row.dueDateIso}',
                                  icon: Icons.event_note_rounded,
                                  background: Colors.white.withValues(alpha: 0.1),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    PremiumPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PremiumSectionHeading(
                            title: 'Record Repayment',
                            caption: 'Enter the amount and payment method used.',
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _amountCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              hintText: 'e.g. 25.00',
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _method,
                            decoration:
                                const InputDecoration(labelText: 'Payment method'),
                            items: const [
                              DropdownMenuItem(value: 'cash', child: Text('Cash')),
                              DropdownMenuItem(
                                value: 'mobile_money',
                                child: Text('Mobile Money'),
                              ),
                              DropdownMenuItem(
                                value: 'bank_transfer',
                                child: Text('Bank Transfer'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _method = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Save Payment'),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(debtsControllerProvider.notifier).recordRepayment(
            receivableId: widget.receivableId,
            amount: _amountCtrl.text,
            paymentMethodLabel: _method,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_humanizeError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _humanizeError(Object error) {
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Invalid input.';
    }
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }
}
