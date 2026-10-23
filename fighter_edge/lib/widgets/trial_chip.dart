import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'press_scale.dart';

/// "Trial · N days left". Gold is for paid and trial surfaces only.
class TrialChip extends StatelessWidget {
  const TrialChip({super.key, required this.daysLeft, this.onTap});

  final int daysLeft;

  /// Where a tap goes (usually the paywall). Null leaves the chip as a plain
  /// label.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = L.of(context).trialChipDaysLeft(daysLeft);
    return Semantics(
      button: onTap != null,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: AppAccessibility.minTouchTarget),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.premiumSoft,
                borderRadius: BorderRadius.circular(Radii.chip),
                border: Border.all(color: AppColors.premium),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md, vertical: Insets.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(AppIconsFill.sealCheck,
                        color: AppColors.premium, size: IconSizes.inline),
                    const SizedBox(width: Insets.xs),
                    Flexible(
                      child: Text(label,
                          style: AppType.subhead(
                              weight: FontWeight.w800,
                              color: AppColors.premium)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
