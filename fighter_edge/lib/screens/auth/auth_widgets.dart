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
  final IconData? icon;
  final bool google;
  final String label;
  final VoidCallback? onPressed;
  const SocialButton(
      {super.key,
      this.icon,
      this.google = false,
      required this.label,
      this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: PressScale(
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: google ? AppColors.googleSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(Radii.button),
          ),
          child: Container(
            constraints:
                const BoxConstraints(minHeight: LayoutTokens.authButton),
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.lg, vertical: Insets.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.button),
              border: Border.all(
                  color: google ? AppColors.googleBorder : AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (google)
                  Image.asset('assets/images/google_g.png',
                      width: LayoutTokens.googleMark,
                      height: LayoutTokens.googleMark,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true)
                else
                  Icon(icon, size: IconSizes.row, color: AppColors.textPrimary),
                const SizedBox(width: Insets.md),
                Flexible(
                    child: Text(label,
                        style: google
                            ? AppType.googleSignIn()
                            : AppType.callout(weight: FontWeight.w600))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
