import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../providers/sales_cart_provider.dart';
import '../widgets/checkout_method_button.dart';
import '../../../inventory/data/inventory_repository.dart';

/// The payment-method selection + confirm sheet shown before a sale is finalised.
///
/// Delegates record/Paystack logic back to the parent via callbacks so this
/// widget stays purely presentational/UI.
class CheckoutSheet extends ConsumerStatefulWidget {
  const CheckoutSheet({
    super.key,
    required this.items,
    required this.itemCount,
    required this.totalAmount,
    required this.onRecordCash,
    required this.onRecordMomo,
    required this.onPayWithMomoNumber,
    required this.formatMajor,
  });

  final List<LocalInventoryItem> items;
  final int itemCount;
  final String totalAmount;
  final Future<bool> Function(String method) onRecordCash;
  final Future<void> Function(String method) onRecordMomo;
  final Future<void> Function(String method) onPayWithMomoNumber;
  final String Function(String value, {String symbol}) formatMajor;

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  late String _selectedMethod;

  @override
  void initState() {
    super.initState();
    _selectedMethod = ref.read(salesCartProvider).paymentMethod;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppShadows.elevated,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Confirm payment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.itemCount} ${widget.itemCount == 1 ? 'item' : 'items'} · ${widget.formatMajor(widget.totalAmount, symbol: '₵')}',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: CheckoutMethodButton(
                      label: 'Cash',
                      icon: Icons.payments_rounded,
                      selected: _selectedMethod == 'cash',
                      accent: AppColors.forest,
                      onTap: () => setState(() => _selectedMethod = 'cash'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CheckoutMethodButton(
                      label: 'MoMo',
                      icon: Icons.phone_android_rounded,
                      selected: _selectedMethod == 'mobile_money',
                      accent: AppColors.gold,
                      onTap: () => setState(() => _selectedMethod = 'mobile_money'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CheckoutMethodButton(
                      label: 'Bank',
                      icon: Icons.account_balance_rounded,
                      selected: _selectedMethod == 'bank_transfer',
                      accent: const Color(0xFF2563A8),
                      comingSoon: true,
                      onTap: () => setState(() => _selectedMethod = 'bank_transfer'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Cash — direct confirmation only
              if (_selectedMethod == 'cash') ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      ref.read(salesCartProvider.notifier).setPaymentMethod(_selectedMethod);
                      Navigator.of(context).pop();
                      // Parent (`_recordSale`) is responsible for showing the
                      // success sheet — its context outlives this bottom sheet.
                      await widget.onRecordCash(_selectedMethod);
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                        'Confirm — ${widget.formatMajor(widget.totalAmount, symbol: '₵')}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ]
              // MoMo — Paystack: QR/link OR MoMo number (keypad customer)
              else if (_selectedMethod == 'mobile_money') ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      ref.read(salesCartProvider.notifier).setPaymentMethod(_selectedMethod);
                      await widget.onRecordMomo(_selectedMethod);
                    },
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: Text(
                      'Pay by QR / link — ${widget.formatMajor(widget.totalAmount, symbol: '₵')}',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      ref.read(salesCartProvider.notifier).setPaymentMethod(_selectedMethod);
                      await widget.onPayWithMomoNumber(_selectedMethod);
                    },
                    icon: const Icon(Icons.phone_callback_rounded, size: 18),
                    label: Text(
                      'Pay with MoMo number — ${widget.formatMajor(widget.totalAmount, symbol: '₵')}',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.forest,
                      side: const BorderSide(color: AppColors.forest, width: 1.5),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ]
              // Bank — coming soon
              else if (_selectedMethod == 'bank_transfer') ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: const Text('Bank Transfer — Coming Soon'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.inkSoft,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
