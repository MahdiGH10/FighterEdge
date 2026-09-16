import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

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

    if (scrollable) {
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
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(Radii.chip),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.chip),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg, vertical: Insets.sm + 2),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AppType.subhead(
                  weight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
