import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class SalesBottomBar extends StatelessWidget {
  const SalesBottomBar({super.key, 
    required this.itemCount,
    required this.totalAmount,
    required this.paymentMethod,
    required this.hasItems,
    required this.isBusy,
    required this.onConfirm,
  });

  final int itemCount;
  final String totalAmount;
  final String paymentMethod;
  final bool hasItems;
  final bool isBusy;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: hasItems ? AppColors.forestNight : const Color(0xFFF8F9FC),
        boxShadow: AppShadows.elevated,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: hasItems
                      ? Colors.white.withValues(alpha: 0.15)
                      : AppColors.forest.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Icon(
                        Icons.shopping_cart_outlined,
                        color: hasItems ? Colors.white : AppColors.forest,
                        size: 20,
                      ),
                    ),
                    if (itemCount > 0)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$itemCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    itemCount == 0 ? 'Cart is empty' : 'Ready to checkout',
                    style: TextStyle(
                      color: hasItems ? Colors.white : AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '₵$totalAmount',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: hasItems ? Colors.white : AppColors.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    hasItems ? 'Payment at checkout' : paymentMethod,
                    style: TextStyle(
                      color: hasItems
                          ? Colors.white.withValues(alpha: 0.65)
                          : AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: (hasItems && !isBusy) ? onConfirm : null,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                  iconAlignment: IconAlignment.end,
                  label: Text(isBusy ? 'Saving...' : 'Checkout'),
                  style: FilledButton.styleFrom(
                    backgroundColor: hasItems ? Colors.white : AppColors.forest,
                    foregroundColor: hasItems ? AppColors.forest : Colors.white,
                    disabledBackgroundColor: const Color(0xFFCCCCCC),
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
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
            ],
          ),
        ),
      ),
    );
  }
}
