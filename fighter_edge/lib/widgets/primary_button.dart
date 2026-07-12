import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Solid red call-to-action button used across the app.
class PrimaryButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: Insets.sm),
        ],
        Text(
          label.toUpperCase(),
          style: AppTheme.body(13,
              weight: FontWeight.w700, color: Colors.white, spacing: 0.8),
        ),
      ],
    );

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(Radii.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.button),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.xl, vertical: Insets.md + 2),
          child: child,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.xl, vertical: Insets.md + 2),
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
    );
  }
}
