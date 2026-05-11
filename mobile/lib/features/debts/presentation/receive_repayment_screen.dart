import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/utils/user_friendly_error.dart';
import '../../../shared/widgets/mockup_ui.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../providers/debts_providers.dart';
import 'utils/debts_ui_tokens.dart';
import 'utils/debts_ui_utils.dart';

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
    final detailAsync =
        ref.watch(receivableDetailProvider(widget.receivableId));

    return MockupScreenScaffold(
      title: 'Receive Payment',
      subtitle: 'Record a repayment to keep the outstanding balance accurate',
      onBack: () => context.pop(),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
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
                      '₵${DebtsUiUtils.fmtAmount(row.outstandingAmount)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Outstanding',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (row.dueDateIso != null &&
                        row.dueDateIso!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      PremiumBadge(
                        label:
                            'Due ${DebtsUiUtils.fmtDueDate(row.dueDateIso)}',
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
                  decoration: InputDecoration(
                    labelText: 'Amount received',
                    hintText: '0.00',
                    prefixText: '₵ ',
                    prefixIcon: const Icon(
                      Icons.attach_money_rounded,
                      color: AppColors.muted,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: AppColors.canvas,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(DebtTokens.buttonRadius),
                      borderSide:
                          const BorderSide(color: AppColors.borderStrong),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(DebtTokens.buttonRadius),
                      borderSide:
                          const BorderSide(color: AppColors.borderStrong),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(DebtTokens.buttonRadius),
                      borderSide: const BorderSide(
                          color: AppColors.forest, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Payment method',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _MethodChip(
                      label: 'Cash',
                      icon: Icons.money_rounded,
                      selected: _method == 'cash',
                      onTap: () => setState(() => _method = 'cash'),
                    ),
                    const SizedBox(width: 8),
                    _MethodChip(
                      label: 'MoMo',
                      icon: Icons.smartphone_rounded,
                      selected: _method == 'mobile_money',
                      onTap: () => setState(() => _method = 'mobile_money'),
                    ),
                    const SizedBox(width: 8),
                    _MethodChip(
                      label: 'Bank',
                      icon: Icons.account_balance_rounded,
                      selected: _method == 'bank_transfer',
                      onTap: () =>
                          setState(() => _method = 'bank_transfer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomBar: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: 54,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text(
              'Save Payment',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
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
        SnackBar(content: Text(userFriendlyError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.forest.withValues(alpha: 0.10)
                : AppColors.canvas,
            borderRadius: BorderRadius.circular(DebtTokens.buttonRadius),
            border: Border.all(
              color: selected ? AppColors.forest : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 20,
                  color: selected ? AppColors.forest : AppColors.muted),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.forest : AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

