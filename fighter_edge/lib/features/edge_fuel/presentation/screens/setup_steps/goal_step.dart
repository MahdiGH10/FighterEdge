import 'package:flutter/material.dart';
import '../../../../../l10n/gen/app_localizations.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../theme/app_typography.dart';
import '../../../domain/models/nutrition_enums.dart';
import '../../controllers/edge_fuel_setup_controller.dart';
import '../../nutrition_copy.dart';
import '../../widgets/choice_card.dart';

/// Step 1 of 6 — goal (master prompt §6.1).
class GoalStep extends StatelessWidget {
  final EdgeFuelSetupController controller;
  const GoalStep({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final draft = controller.draft;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Insets.lg),
      children: [
        Text(l.fuelGoalQuestion, style: AppType.title1()),
        const SizedBox(height: Insets.sm),
        Text(
          l.fuelGoalHint,
          style: AppType.subhead(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Insets.xl),
        for (final goal in NutritionGoal.values)
          ChoiceCard(
            title: NutritionCopy.goalLabelL(l, goal),
            description: NutritionCopy.goalDescriptionL(l, goal),
            selected: draft.goal == goal,
            onTap: () => controller.setGoal(goal),
          ),
      ],
    );
  }
}
