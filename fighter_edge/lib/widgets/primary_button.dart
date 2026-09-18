import 'package:flutter/material.dart';

import '../theme/app_accessibility.dart';
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
            child: _ButtonContent(
              label: label,
              icon: icon,
              color: Colors.white,
              expand: expand,
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
            border: Border.all(color: AppAccessibility.border(context)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: _ButtonContent(
              label: label,
              icon: icon,
              color: AppColors.textPrimary,
              expand: expand,
            ),
          ),
        ),
      ),
    );
  }
}

/// Label and icon shared by both buttons, sized to the room they get.
///
/// Two buttons side by side on a 390pt phone leave each about 150pt; with
/// full padding and an icon, a label like "START CAMP" was cut to "START CA…".
/// Below [_compactWidth] the button drops its icon and tightens its padding,
/// because the words are the part the user has to read.
class _ButtonContent extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool expand;

  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.color,
    required this.expand,
  });

  static const double _compactWidth = 168;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactWidth;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? Insets.sm : Insets.xl,
          ),
          child: Center(
            widthFactor: expand ? null : 1,
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null && !compact) ...[
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: Insets.sm),
                ],
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppAccessibility.adjustStyle(
                      context,
                      AppType.subhead(
                        weight: FontWeight.w700,
                        color: color,
                        spacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
