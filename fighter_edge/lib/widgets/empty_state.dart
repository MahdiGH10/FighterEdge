import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'primary_button.dart';

/// Honest "not built yet / no data" placeholder so a selectable tab never
/// looks silently broken.
///
/// Give it an action whenever there is one: an empty state should teach the
/// next step, not just describe the absence.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 28, color: AppColors.textMuted),
            ),
            const SizedBox(height: Insets.lg),
            Text(title, textAlign: TextAlign.center, style: AppType.title2()),
            const SizedBox(height: Insets.sm),
            Text(message,
                textAlign: TextAlign.center,
                style: AppType.subhead(
                    weight: FontWeight.w500, color: AppColors.textMuted)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Insets.lg),
              GhostButton(actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
