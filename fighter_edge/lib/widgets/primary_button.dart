import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_haptics.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'press_scale.dart';

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
        Flexible(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.subhead(
                weight: FontWeight.w700, color: Colors.white, spacing: 0.8),
          ),
        ),
      ],
    );

    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      child: PressScale(
        onTap: onPressed,
        // The primary button is the screen's commitment: it starts the session,
        // saves the plan, takes the payment. It earns a heavier confirmation
        // than an ordinary card tap.
        haptic: AppHaptics.commit,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, AppColors.primaryDark],
                  )
                : null,
            color: enabled ? null : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(Radii.button),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: AppColors.primaryGlow,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
              child: Center(widthFactor: expand ? null : 1, child: child),
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
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: PressScale(
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(Radii.button),
          ),
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
                  Flexible(
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.subhead(
                          weight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          spacing: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
