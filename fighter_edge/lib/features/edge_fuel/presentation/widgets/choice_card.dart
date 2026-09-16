import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/stat_card.dart';

/// Selectable card with a title, an explanatory description, and a
/// radio-style indicator. Used across the EdgeFuel setup wizard wherever a
/// choice needs more context than a chip label can carry (master prompt §6:
/// "provide examples, not only labels").
class ChoiceCard extends StatelessWidget {
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const ChoiceCard({
    super.key,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: AppCard(
        onTap: onTap,
        accent: selected ? AppColors.primary : null,
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.callout(weight: FontWeight.w800)),
                  const SizedBox(height: Insets.xxs),
                  Text(description,
                      style: AppType.subhead(
                          weight: FontWeight.w500,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : AppColors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
