import 'package:flutter/material.dart';
import '../../../../../l10n/gen/app_localizations.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../theme/app_typography.dart';
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
    final l = L.of(context);
    final draft = controller.draft;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Insets.lg),
      children: [
        Text(l.fuelActivityQuestion, style: AppType.title1()),
        const SizedBox(height: Insets.sm),
        Text(
          l.fuelActivityHint,
          style: AppType.subhead(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Insets.xl),
        for (final level in ActivityLevel.values)
          ChoiceCard(
            title: NutritionCopy.activityLabelL(l, level),
            description: NutritionCopy.activityDescriptionL(l, level),
            selected: draft.normalActivityLevel == level,
            onTap: () => controller.setActivityLevel(level),
          ),
      ],
    );
  }
}
