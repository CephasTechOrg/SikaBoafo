import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/providers/sync_providers.dart';
import '../../../../shared/utils/user_friendly_error.dart';
import '../../providers/debts_providers.dart';
import '../utils/debts_ui_tokens.dart';
import 'debt_paystack_qr_sheet.dart';

/// Payment collection sheet for a receivable.
///
/// Presents three method tabs — Cash, MoMo (QR / link), Bank (coming soon).
/// Cash records a repayment locally. MoMo generates a Paystack payment link,
/// then hands off to [DebtPaystackQrSheet] for QR display and status polling.
class DebtPaymentSheet extends ConsumerStatefulWidget {
  const DebtPaymentSheet({
    super.key,
    required this.receivableId,
    required this.customerName,
    required this.outstandingAmount,
    required this.syncStatus,
    this.existingPaymentLink,
    required this.onRepaymentSaved,
    required this.onPaymentConfirmed,
  });

  final String receivableId;
  final String customerName;
  final String outstandingAmount;
  final String syncStatus;

  /// If a Paystack link was already generated for this receivable, pass it
  /// here so the sheet reuses it instead of calling the API again.
  final String? existingPaymentLink;

  /// Called after a cash repayment is saved successfully.
  final VoidCallback onRepaymentSaved;

  /// Called after Paystack polling confirms the payment succeeded.
  final VoidCallback onPaymentConfirmed;

  @override
  ConsumerState<DebtPaymentSheet> createState() => _DebtPaymentSheetState();
}

class _DebtPaymentSheetState extends ConsumerState<DebtPaymentSheet> {
  String _method = 'cash';
  final _amountCtrl = TextEditingController();
  bool _saving = false;
  bool _generatingLink = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewBottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + viewBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          // Header row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.forest.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: AppColors.forest,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Receive Payment',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: AppColors.muted,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Dark summary card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: DebtTokens.hero900,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.customerName,
                        style: const TextStyle(
                          color: Color(0xFFB8DECA),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '₵${_fmtAmount(widget.outstandingAmount)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Outstanding',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Method selector
          Row(
            children: [
              Expanded(
                child: _MethodButton(
                  label: 'Cash',
                  icon: Icons.payments_rounded,
                  selected: _method == 'cash',
                  accent: AppColors.forest,
                  onTap: () => setState(() => _method = 'cash'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MethodButton(
                  label: 'MoMo',
                  icon: Icons.qr_code_2_rounded,
                  selected: _method == 'mobile_money',
                  accent: AppColors.gold,
                  onTap: () => setState(() => _method = 'mobile_money'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MethodButton(
                  label: 'Bank',
                  icon: Icons.account_balance_rounded,
                  selected: _method == 'bank_transfer',
                  accent: const Color(0xFF2563A8),
                  comingSoon: true,
                  onTap: () => setState(() => _method = 'bank_transfer'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // --- Cash ---
          if (_method == 'cash') ...[
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
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
                  borderSide:
                      const BorderSide(color: AppColors.forest, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveCash,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text(
                  'Save Payment',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(DebtTokens.buttonRadius),
                  ),
                ),
              ),
            ),
          ]
          // --- MoMo / QR link ---
          else if (_method == 'mobile_money') ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _generatingLink
                    ? null
                    : () => _generateAndShowQr(context),
                icon: _generatingLink
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.qr_code_2_rounded),
                label: Text(
                  _generatingLink ? 'Generating…' : 'Pay by QR / link',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(DebtTokens.buttonRadius),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ]
          // --- Bank (coming soon) ---
          else if (_method == 'bank_transfer') ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.schedule_rounded),
                label: const Text('Bank Transfer — Coming Soon'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(DebtTokens.buttonRadius),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Bank transfer will be available in a future update.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.inkSoft,
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCash() async {
    final raw = _amountCtrl.text.trim();
    final parsed = double.tryParse(raw) ?? 0;
    if (parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than 0.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(debtsControllerProvider.notifier).recordRepayment(
            receivableId: widget.receivableId,
            amount: raw,
            paymentMethodLabel: 'cash',
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onRepaymentSaved();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFriendlyError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _generateAndShowQr(BuildContext context) async {
    // Reuse existing link when available to avoid unnecessary API calls.
    final existing = widget.existingPaymentLink;
    if (existing != null && existing.isNotEmpty) {
      Navigator.of(context).pop();
      if (!context.mounted) return;
      _openQrSheet(context, existing);
      return;
    }

    // If the debt has a sync error, refuse early with a clear explanation.
    if (widget.syncStatus == 'failed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This debt has a sync error. Pull to refresh on the debts page, then try again.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _generatingLink = true);
    try {
      if (widget.syncStatus != 'applied') {
        await ref.read(debtsRepositoryProvider).syncPendingQueue();
      }
      final result = await ref
          .read(debtsApiProvider)
          .initiateReceivablePaymentLink(widget.receivableId);

      unawaited(
        ref
            .read(debtsRepositoryProvider)
            .updateReceivablePaymentLink(
                widget.receivableId, result.checkoutUrl),
      );

      if (!mounted || !context.mounted) return;
      Navigator.of(context).pop();
      if (!context.mounted) return;
      _openQrSheet(context, result.checkoutUrl);
    } catch (error) {
      if (!mounted) return;
      final msg = userFriendlyError(error);
      final hint = widget.syncStatus != 'applied'
          ? '\nSync with server failed — check your connection and try again.'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$msg$hint'),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _generatingLink = false);
    }
  }

  void _openQrSheet(BuildContext context, String url) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DebtPaystackQrSheet(
        checkoutUrl: url,
        receivableId: widget.receivableId,
        onPaymentConfirmed: widget.onPaymentConfirmed,
      ),
    );
  }
}

// ── Local helpers ────────────────────────────────────────────────────────────

String _fmtAmount(String v) {
  final d = double.tryParse(v) ?? 0;
  return d.toStringAsFixed(2);
}

class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.comingSoon = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? accent : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 22,
                color: selected ? Colors.white : accent),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (comingSoon) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (selected ? Colors.white : AppColors.muted)
                      .withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Soon',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color:
                        selected ? Colors.white : AppColors.muted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
