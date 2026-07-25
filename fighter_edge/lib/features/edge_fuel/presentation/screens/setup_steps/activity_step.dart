import 'package:flutter/material.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_theme.dart';
import '../../../domain/models/nutrition_enums.dart';
import '../../controllers/edge_fuel_setup_controller.dart';
import '../../nutrition_copy.dart';
import '../../widgets/choice_card.dart';

/// Step 3 of 6 — day-to-day activity, kept distinct from planned training
/// (master prompt §6.3) so the two are never double-counted.
class ActivityStep extends StatelessWidget {
  final EdgeFuelSetupController controller;
  const ActivityStep({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final draft = controller.draft;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Insets.lg),
      children: [
        Text('Your normal activity', style: AppTheme.display(22)),
        const SizedBox(height: Insets.sm),
        Text(
          "Day-to-day movement outside training — Fighter Edge sessions are "
          "counted separately next.",
          style: AppTheme.body(13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: Insets.xl),
        for (final level in ActivityLevel.values)
          ChoiceCard(
            title: NutritionCopy.activityLabel(level),
            description: NutritionCopy.activityDescription(level),
            selected: draft.normalActivityLevel == level,
            onTap: () => controller.setActivityLevel(level),
          ),
      ],
    );
  }
}
