import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Reusable dark card container.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? accent;
  final Gradient? gradient;
  final bool elevated;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Insets.lg),
    this.onTap,
    this.color,
    this.accent,
    this.gradient,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = accent?.withValues(alpha: .42) ?? AppColors.border;
    final content = Ink(
      decoration: BoxDecoration(
        color: gradient == null ? color ?? AppColors.surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: borderColor),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: (accent ?? Colors.black).withValues(alpha: .16),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: onTap,
          child: content,
        ),
      ),
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
  final Color? accent;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
    this.delta,
    this.deltaColor = AppColors.positive,
    this.deltaIcon,
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      accent: accent,
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                _AnimatedMetricValue(value: value),
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

class _AnimatedMetricValue extends StatelessWidget {
  final String value;

  const _AnimatedMetricValue({required this.value});

  @override
  Widget build(BuildContext context) {
    final numeric = double.tryParse(value);
    if (numeric == null || MediaQuery.disableAnimationsOf(context)) {
      return Text(value, style: AppTheme.display(24));
    }

    final decimals = value.contains('.') ? value.split('.').last.length : 0;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: numeric),
      duration: MotionTokens.standard,
      curve: MotionTokens.emphasized,
      builder: (context, animated, _) {
        return Text(animated.toStringAsFixed(decimals),
            style: AppTheme.display(24));
      },
    );
  }
}
