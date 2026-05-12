import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/theme/app_theme.dart';

/// Six-slot OTP input. Visually shows six rounded slots while an invisible
/// underlying TextField captures keypresses, paste, and autofill.
class DebtMomoOtpField extends StatelessWidget {
  const DebtMomoOtpField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final text = controller.text;
    final focused = focusNode.hasFocus;
    final activeIndex = focused
        ? (text.length >= length ? -1 : text.length.clamp(0, length - 1))
        : -1;

    return AutofillGroup(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(length, (i) {
                final ch = i < text.length ? text[i] : '';
                final isActive = activeIndex >= 0 && i == activeIndex;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 5,
                      right: i == length - 1 ? 0 : 5,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          width: isActive ? 1.5 : 1,
                          color: isActive
                              ? AppColors.forest
                              : AppColors.border,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: AppColors.forest
                                      .withValues(alpha: 0.18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        ch,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            Positioned.fill(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: length,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  color: Colors.transparent,
                  height: 0.01,
                  fontSize: 1,
                ),
                cursorColor: Colors.transparent,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => onChanged(),
                onSubmitted: (_) => onSubmitted(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
