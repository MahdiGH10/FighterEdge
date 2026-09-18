import 'package:flutter/material.dart';

import '../auth/password_policy.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Three-segment strength bar with a one-line verdict under a password field.
///
/// Colour and label always change together, so the meter never relies on
/// colour alone. Announced as a live region so screen-reader users hear the
/// verdict update as they type.
class PasswordStrengthMeter extends StatelessWidget {
  final String password;
  const PasswordStrengthMeter({super.key, required this.password});

  static const _segments = 3;

  @override
  Widget build(BuildContext context) {
    final strength = PasswordPolicy.strengthOf(password);
    if (strength == PasswordStrength.empty) return const SizedBox.shrink();

    final (filled, color, label) = switch (strength) {
      PasswordStrength.empty => (0, AppColors.track, ''),
      PasswordStrength.tooShort => (
          0,
          AppColors.track,
          'At least ${PasswordPolicy.minLength} characters',
        ),
      PasswordStrength.weak => (
          1,
          AppColors.negative,
          'Weak — try a longer phrase'
        ),
      PasswordStrength.fair => (
          2,
          AppColors.warning,
          'Fair — longer is better'
        ),
      PasswordStrength.strong => (3, AppColors.positive, 'Strong'),
    };
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : MotionTokens.fast;

    return Semantics(
      liveRegion: true,
      label: 'Password strength: $label',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: Insets.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < _segments; i++) ...[
                  if (i > 0) const SizedBox(width: Insets.xs),
                  Expanded(
                    child: AnimatedContainer(
                      duration: duration,
                      height: Insets.xs,
                      decoration: BoxDecoration(
                        color: i < filled ? color : AppColors.track,
                        borderRadius: BorderRadius.circular(Radii.chip),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(
              label,
              style: AppType.subhead(
                color:
                    filled == 0 ? AppAccessibility.textMuted(context) : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
