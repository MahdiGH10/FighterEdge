import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Reusable dark card container.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Insets.lg),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.card),
      onTap: onTap,
      child: content,
    );
  }
}

/// Compact metric card: label, big value + unit, colored delta.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String? delta;
  final Color deltaColor;
  final IconData? deltaIcon;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
    this.delta,
    this.deltaColor = AppColors.positive,
    this.deltaIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.md, vertical: Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTheme.body(10,
                weight: FontWeight.w600,
                color: AppColors.textMuted,
                spacing: 0.8),
          ),
          const SizedBox(height: Insets.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppTheme.display(24)),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(unit,
                      style: AppTheme.body(11,
                          weight: FontWeight.w600,
                          color: AppColors.textMuted)),
                ),
              ],
            ],
          ),
          if (delta != null) ...[
            const SizedBox(height: Insets.xs),
            Row(
              children: [
                if (deltaIcon != null)
                  Icon(deltaIcon, size: 12, color: deltaColor),
                const SizedBox(width: 2),
                Text(delta!,
                    style: AppTheme.body(11,
                        weight: FontWeight.w600, color: deltaColor)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
