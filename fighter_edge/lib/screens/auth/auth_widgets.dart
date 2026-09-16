import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/press_scale.dart';

/// Shows a branded error snackbar for an auth failure.
void showAuthError(BuildContext context, Object error) {
  final message = error is AuthException
      ? error.message
      : 'Something went wrong. Try again.';
  showAuthMessage(context, message);
}

/// Shows a branded snackbar with an explicit message.
void showAuthMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: AppColors.surfaceElevated,
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: Insets.md),
          Expanded(
            child:
                Text(message, style: AppType.subhead(weight: FontWeight.w500)),
          ),
        ],
      ),
    ));
}

/// "or" divider between primary and social auth.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Text('OR',
              style: AppType.micro(
                  weight: FontWeight.w600, color: AppColors.textMuted)),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

/// Outlined provider button (Google / Apple / email code).
class SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const SocialButton(
      {super.key, required this.icon, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: PressScale(
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(Radii.button),
          ),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.button),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: AppColors.textPrimary),
                const SizedBox(width: Insets.md),
                Text(label, style: AppType.callout(weight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
