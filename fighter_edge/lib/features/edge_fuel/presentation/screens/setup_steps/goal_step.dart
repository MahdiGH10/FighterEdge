import 'package:flutter/material.dart';

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
    final draft = controller.draft;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Insets.lg),
      children: [
        Text('What are you training for?', style: AppType.title1()),
        const SizedBox(height: Insets.sm),
        Text(
          "This sets the direction of your plan. You can adjust the pace later.",
          style: AppType.subhead(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Insets.xl),
        for (final goal in NutritionGoal.values)
          ChoiceCard(
            title: NutritionCopy.goalLabel(goal),
            description: NutritionCopy.goalDescription(goal),
            selected: draft.goal == goal,
            onTap: () => controller.setGoal(goal),
          ),
      ],
    );
  }
}
