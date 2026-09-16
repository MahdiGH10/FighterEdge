import 'package:flutter/material.dart';

import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_haptics.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'press_scale.dart';

/// Horizontal pill selector (filter chips / segmented tabs).
class FilterChips extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool scrollable;

  const FilterChips({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final largeText = textScaler.scale(14) / 14 >= 1.4;
    final chips = <Widget>[
      for (int i = 0; i < options.length; i++)
        Padding(
          padding:
              EdgeInsets.only(right: i == options.length - 1 ? 0 : Insets.sm),
          child: _Chip(
            label: options[i],
            selected: i == selectedIndex,
            onTap: () => onSelected(i),
          ),
        ),
    ];

    if (scrollable || largeText) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: chips),
      );
    }
    return Row(
      children: [for (final c in chips) Expanded(child: c)],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: PressScale(
        onTap: onTap,
        // Moving between filters commits nothing — it deserves the lightest
        // tick, not the impact a button gets.
        haptic: AppHaptics.selection,
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : MotionTokens.fast,
          curve: MotionTokens.snap,
          // The app's most-used segmented control had no floor at all — text
          // plus padding alone landed around 37px, well under the 44pt target.
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(Radii.chip),
            border: Border.all(
              color: selected
                  ? AppColors.primaryBright.withValues(alpha: .48)
                  : AppAccessibility.border(context),
            ),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg, vertical: Insets.sm + 2),
          child: Center(
            child: ExcludeSemantics(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: AppAccessibility.adjustStyle(
                  context,
                  AppType.subhead(
                    weight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : AppAccessibility.textSecondary(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
