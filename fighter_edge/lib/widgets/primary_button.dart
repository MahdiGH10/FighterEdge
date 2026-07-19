import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Solid red call-to-action button used across the app.
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final Color color;

  const PrimaryButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.color = AppColors.primary,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: Colors.white),
          const SizedBox(width: Insets.sm),
        ],
        Text(
          widget.label.toUpperCase(),
          style: AppTheme.body(13,
              weight: FontWeight.w700, color: Colors.white, spacing: 0.8),
        ),
      ],
    );

    final enabled = widget.onPressed != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedScale(
      scale: !reduceMotion && _pressed ? .975 : 1,
      duration: MotionTokens.fast,
      curve: MotionTokens.emphasized,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [widget.color, AppColors.primaryDark],
                )
              : null,
          color: enabled ? null : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(Radii.button),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: AppColors.primaryGlow,
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.button),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.button),
            onTap: widget.onPressed,
            onHighlightChanged:
                enabled ? (value) => setState(() => _pressed = value) : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
                child:
                    Center(widthFactor: widget.expand ? null : 1, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary (outlined) button — used for RESET etc.
class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  const GhostButton(this.label,
      {super.key, this.onPressed, this.icon, this.expand = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(Radii.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.button),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: AppColors.textPrimary),
                  const SizedBox(width: Insets.sm),
                ],
                Text(
                  label.toUpperCase(),
                  style: AppTheme.body(13,
                      weight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      spacing: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
