import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// AppCard — canonical surface. Replaces ad-hoc Container+BoxDecoration.
// ---------------------------------------------------------------------------

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.elevated = false,
    this.borderColor,
    this.backgroundColor,
    this.radius,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool elevated;
  final Color? borderColor;
  final Color? backgroundColor;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? AppRadii.md;
    final br = BorderRadius.circular(r);
    final decorated = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: br,
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: elevated ? AppShadows.elevated : AppShadows.card,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return decorated;
    return Material(
      color: Colors.transparent,
      borderRadius: br,
      child: InkWell(
        onTap: onTap,
        borderRadius: br,
        child: decorated,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppButton — semantic variants + sizes + icon + loading.
// ---------------------------------------------------------------------------

enum AppButtonVariant { primary, secondary, tertiary, danger }

enum AppButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.fullWidth = false,
    super.key,
  });

  const AppButton.primary({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    IconData? trailingIcon,
    AppButtonSize size = AppButtonSize.md,
    bool loading = false,
    bool fullWidth = false,
    Key? key,
  }) : this(
          label: label,
          onPressed: onPressed,
          variant: AppButtonVariant.primary,
          size: size,
          icon: icon,
          trailingIcon: trailingIcon,
          loading: loading,
          fullWidth: fullWidth,
          key: key,
        );

  const AppButton.secondary({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    IconData? trailingIcon,
    AppButtonSize size = AppButtonSize.md,
    bool loading = false,
    bool fullWidth = false,
    Key? key,
  }) : this(
          label: label,
          onPressed: onPressed,
          variant: AppButtonVariant.secondary,
          size: size,
          icon: icon,
          trailingIcon: trailingIcon,
          loading: loading,
          fullWidth: fullWidth,
          key: key,
        );

  const AppButton.tertiary({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    AppButtonSize size = AppButtonSize.md,
    bool loading = false,
    Key? key,
  }) : this(
          label: label,
          onPressed: onPressed,
          variant: AppButtonVariant.tertiary,
          size: size,
          icon: icon,
          loading: loading,
          key: key,
        );

  const AppButton.danger({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    AppButtonSize size = AppButtonSize.md,
    bool loading = false,
    bool fullWidth = false,
    Key? key,
  }) : this(
          label: label,
          onPressed: onPressed,
          variant: AppButtonVariant.danger,
          size: size,
          icon: icon,
          loading: loading,
          fullWidth: fullWidth,
          key: key,
        );

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final bool fullWidth;

  double get _height => switch (size) {
        AppButtonSize.sm => 36,
        AppButtonSize.md => 44,
        AppButtonSize.lg => 52,
      };

  EdgeInsets get _padding => switch (size) {
        AppButtonSize.sm => const EdgeInsets.symmetric(horizontal: 12),
        AppButtonSize.md => const EdgeInsets.symmetric(horizontal: 16),
        AppButtonSize.lg => const EdgeInsets.symmetric(horizontal: 20),
      };

  double get _iconSize => switch (size) {
        AppButtonSize.sm => 14,
        AppButtonSize.md => 16,
        AppButtonSize.lg => 18,
      };

  TextStyle get _textStyle => switch (size) {
        AppButtonSize.sm =>
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        AppButtonSize.md =>
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        AppButtonSize.lg =>
          const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      };

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final colors = _colorsFor(variant, disabled);

    final content = loading
        ? SizedBox(
            width: _iconSize + 2,
            height: _iconSize + 2,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(colors.foreground),
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: _iconSize, color: colors.foreground),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  style: _textStyle.copyWith(color: colors.foreground),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, size: _iconSize, color: colors.foreground),
              ],
            ],
          );

    final btn = Material(
      color: colors.background,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          height: _height,
          padding: _padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: colors.border != null
                ? Border.all(color: colors.border!)
                : null,
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );

    if (fullWidth) return SizedBox(width: double.infinity, child: btn);
    return btn;
  }

  _ButtonColors _colorsFor(AppButtonVariant v, bool disabled) {
    if (disabled) {
      return _ButtonColors(
        background: AppColors.surfaceAlt,
        foreground: AppColors.mutedSoft,
        border: v == AppButtonVariant.secondary ? AppColors.border : null,
      );
    }
    switch (v) {
      case AppButtonVariant.primary:
        return const _ButtonColors(
          background: AppColors.forest,
          foreground: Colors.white,
        );
      case AppButtonVariant.secondary:
        return const _ButtonColors(
          background: AppColors.surface,
          foreground: AppColors.ink,
          border: AppColors.border,
        );
      case AppButtonVariant.tertiary:
        return const _ButtonColors(
          background: Colors.transparent,
          foreground: AppColors.forest,
        );
      case AppButtonVariant.danger:
        return const _ButtonColors(
          background: AppColors.danger,
          foreground: Colors.white,
        );
    }
  }
}

class _ButtonColors {
  const _ButtonColors({
    required this.background,
    required this.foreground,
    this.border,
  });
  final Color background;
  final Color foreground;
  final Color? border;
}

// ---------------------------------------------------------------------------
// AppTextField — preset decorations.
// ---------------------------------------------------------------------------

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    super.key,
  });

  factory AppTextField.amount({
    required TextEditingController controller,
    String? label,
    String? hint,
    String? helper,
    String? errorText,
    ValueChanged<String>? onChanged,
    bool enabled = true,
    Key? key,
  }) =>
      AppTextField(
        controller: controller,
        label: label,
        hint: hint ?? '0.00',
        helper: helper,
        errorText: errorText,
        onChanged: onChanged,
        enabled: enabled,
        prefixIcon: const Icon(Icons.payments_outlined, size: 18),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        key: key,
      );

  factory AppTextField.search({
    required TextEditingController controller,
    String? hint,
    ValueChanged<String>? onChanged,
    Key? key,
  }) =>
      AppTextField(
        controller: controller,
        hint: hint ?? 'Search',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        key: key,
      );

  factory AppTextField.multiline({
    required TextEditingController controller,
    String? label,
    String? hint,
    String? helper,
    int maxLines = 4,
    int? maxLength,
    ValueChanged<String>? onChanged,
    Key? key,
  }) =>
      AppTextField(
        controller: controller,
        label: label,
        hint: hint,
        helper: helper,
        maxLines: maxLines,
        maxLength: maxLength,
        onChanged: onChanged,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        key: key,
      );

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final int? maxLength;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.labelMedium?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          maxLines: obscureText ? 1 : maxLines,
          maxLength: maxLength,
          obscureText: obscureText,
          enabled: enabled,
          autofocus: autofocus,
          textInputAction: textInputAction,
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.ink),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            errorText: errorText,
            helperText: helper,
            counterText: maxLength != null ? null : '',
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// AppStatusPill — variant-based pill.
// ---------------------------------------------------------------------------

enum AppPillVariant { neutral, success, warning, danger, info, brand }

class AppStatusPill extends StatelessWidget {
  const AppStatusPill({
    required this.label,
    this.variant = AppPillVariant.neutral,
    this.icon,
    this.dense = false,
    super.key,
  });

  final String label;
  final AppPillVariant variant;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colorsFor(variant);
    final vPad = dense ? 3.0 : 5.0;
    final hPad = dense ? 8.0 : 10.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _colorsFor(AppPillVariant v) => switch (v) {
        AppPillVariant.neutral => (AppColors.surfaceAlt, AppColors.inkSoft),
        AppPillVariant.success => (AppColors.successSoft, AppColors.success),
        AppPillVariant.warning => (AppColors.warningSoft, AppColors.warning),
        AppPillVariant.danger => (AppColors.dangerSoft, AppColors.danger),
        AppPillVariant.info => (AppColors.infoSoft, AppColors.info),
        AppPillVariant.brand => (AppColors.mint, AppColors.forest),
      };
}

// ---------------------------------------------------------------------------
// AppStatCard — KPI tile (label, value, optional delta/caption).
// ---------------------------------------------------------------------------

class AppStatCard extends StatelessWidget {
  const AppStatCard({
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.trend,
    this.accent,
    super.key,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final AppStatTrend? trend;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = accent ?? AppColors.forest;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: accentColor),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 22,
              color: AppColors.ink,
              letterSpacing: -0.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (caption != null || trend != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (trend != null) ...[
                  Icon(
                    trend!.isPositive
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 12,
                    color: trend!.isPositive
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    trend!.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: trend!.isPositive
                          ? AppColors.success
                          : AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (caption != null) const SizedBox(width: 6),
                ],
                if (caption != null)
                  Flexible(
                    child: Text(
                      caption!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class AppStatTrend {
  const AppStatTrend({required this.label, required this.isPositive});
  final String label;
  final bool isPositive;
}

// ---------------------------------------------------------------------------
// AppSkeleton — shimmer placeholder.
// ---------------------------------------------------------------------------

class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    this.width,
    this.height = 14,
    this.radius = 6,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              AppColors.surfaceAlt,
              AppColors.border,
              _ctrl.value,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({this.lines = 3, this.showHeader = true, super.key});

  final int lines;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            const AppSkeleton(height: 16, width: 140),
            const SizedBox(height: 14),
          ],
          for (int i = 0; i < lines; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            AppSkeleton(
              height: 12,
              width: i == lines - 1 ? 160 : double.infinity,
            ),
          ],
        ],
      ),
    );
  }
}
