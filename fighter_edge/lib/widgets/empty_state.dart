import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Honest "not built yet / no data" placeholder so a selectable tab never
/// looks silently broken.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
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
            Text(title,
                textAlign: TextAlign.center, style: AppTheme.display(18)),
            const SizedBox(height: Insets.sm),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTheme.body(13,
                    weight: FontWeight.w500, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
