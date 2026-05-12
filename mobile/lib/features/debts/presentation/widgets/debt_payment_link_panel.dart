import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/utils/user_friendly_error.dart';
import '../../data/models/local_receivable_record.dart';
import '../../providers/debts_providers.dart';
import '../utils/debts_ui_utils.dart';
import 'debt_payment_link_share.dart';
import 'debt_paystack_momo_sheet/debt_paystack_momo_sheet.dart';
import 'debt_paystack_qr_sheet.dart';

/// Card on the debt detail screen for generating / showing the Paystack
/// hosted payment link. Two visual states:
///   - **No link yet:** primary "Generate payment link" CTA.
///   - **Link active:** "Active link" card with Show QR + Share buttons.
class DebtPaymentLinkPanel extends ConsumerStatefulWidget {
  const DebtPaymentLinkPanel({super.key, required this.record});

  final LocalReceivableRecord record;

  @override
  ConsumerState<DebtPaymentLinkPanel> createState() =>
      _DebtPaymentLinkPanelState();
}

class _DebtPaymentLinkPanelState extends ConsumerState<DebtPaymentLinkPanel> {
  bool _generating = false;

  bool get _hasLink {
    final link = widget.record.paymentLink;
    return link != null && link.trim().isNotEmpty;
  }

  Future<void> _generate({required bool openQrAfter}) async {
    setState(() => _generating = true);
    try {
      final initiation = await ref
          .read(debtsControllerProvider.notifier)
          .initiatePaymentLink(receivableId: widget.record.receivableId);
      if (!mounted) return;
      if (openQrAfter) {
        await showDebtPaystackQrSheet(
          context,
          receivableId: widget.record.receivableId,
          checkoutUrl: initiation.checkoutUrl,
          amountDisplay: DebtsUiUtils.formatAmount(
            widget.record.outstandingAmount,
          ),
          customerName: widget.record.customerName ?? 'Customer',
          onPaymentConfirmed: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment received. Debt settled.')),
            );
          },
        );
      } else {
        await showDebtPaymentLinkShare(
          context,
          checkoutUrl: initiation.checkoutUrl,
          amountDisplay: DebtsUiUtils.formatAmount(
            widget.record.outstandingAmount,
          ),
          customerName: widget.record.customerName ?? 'Customer',
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyError(error)),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _openExistingQr() async {
    final link = widget.record.paymentLink;
    if (link == null || link.isEmpty) return;
    await showDebtPaystackQrSheet(
      context,
      receivableId: widget.record.receivableId,
      checkoutUrl: link,
      amountDisplay: DebtsUiUtils.formatAmount(
        widget.record.outstandingAmount,
      ),
      customerName: widget.record.customerName ?? 'Customer',
      onPaymentConfirmed: () {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment received. Debt settled.')),
        );
      },
    );
  }

  Future<void> _openExistingShare() async {
    final link = widget.record.paymentLink;
    if (link == null || link.isEmpty) return;
    await showDebtPaymentLinkShare(
      context,
      checkoutUrl: link,
      amountDisplay:
          DebtsUiUtils.formatAmount(widget.record.outstandingAmount),
      customerName: widget.record.customerName ?? 'Customer',
    );
  }

  Future<void> _openMomoPush() async {
    await showDebtPaystackMomoSheet(
      context,
      receivableId: widget.record.receivableId,
      amountDisplay:
          DebtsUiUtils.formatAmount(widget.record.outstandingAmount),
      customerName: widget.record.customerName ?? 'Customer',
      onPaymentConfirmed: () {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment received. Debt settled.')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: _hasLink ? _activeLinkBody() : _generateBody(),
    );
  }

  Widget _generateBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppGradients.primaryCta,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.qr_code_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Collect online',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Generate a QR / link the customer can pay from any '
                    'mobile money or card.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.forest.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            DebtsUiUtils.formatAmount(widget.record.outstandingAmount),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.forestDark,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _generating ? null : () => _generate(openQrAfter: false),
                icon: const Icon(Icons.ios_share_rounded, size: 16),
                label: const Text('Share link'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed:
                    _generating ? null : () => _generate(openQrAfter: true),
                icon: _generating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.qr_code_2_rounded, size: 18),
                label: Text(_generating ? 'Generating…' : 'Show QR'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forestDark,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _MomoPushButton(onTap: _openMomoPush),
      ],
    );
  }

  Widget _activeLinkBody() {
    final link = widget.record.paymentLink!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.link_rounded,
                color: AppColors.success,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment link active',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Share the link or show the QR. The debt settles '
                    'automatically when the customer pays.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            link,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.inkSoft,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openExistingShare,
                icon: const Icon(Icons.ios_share_rounded, size: 16),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _openExistingQr,
                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: const Text('Show QR'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forestDark,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed:
                _generating ? null : () => _generate(openQrAfter: true),
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: _generating
                ? const Text('Regenerating…')
                : const Text('Regenerate link'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.inkSoft,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MomoPushButton extends StatelessWidget {
  const _MomoPushButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.phone_android_rounded, size: 16),
      label: const Text('Push MoMo prompt'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
    );
  }
}
