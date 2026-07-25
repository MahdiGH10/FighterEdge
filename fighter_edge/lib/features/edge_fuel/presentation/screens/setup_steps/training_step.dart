import 'package:flutter/material.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_theme.dart';
import '../../../domain/models/nutrition_enums.dart';
import '../../controllers/edge_fuel_setup_controller.dart';
import '../../nutrition_copy.dart';
import '../../widgets/choice_card.dart';

/// Step 4 of 6 — weekly training load and goal pace (master prompt §6.4).
/// Maintenance has no pace: the adjustment is always 0%.
class TrainingStep extends StatefulWidget {
  final EdgeFuelSetupController controller;
  const TrainingStep({super.key, required this.controller});

  @override
  State<TrainingStep> createState() => _TrainingStepState();
}

class _TrainingStepState extends State<TrainingStep> {
  @override
  void initState() {
    super.initState();
    // The stepper shows a default of 4 days even before the user touches
    // it — commit that default immediately so it isn't just a visual value
    // that blocks advancing until tapped. Deferred a frame since this runs
    // during the parent's build and the controller must not notify
    // listeners mid-build.
    if (widget.controller.draft.weeklyTrainingDays == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller.draft.weeklyTrainingDays == null) {
          widget.controller.setTraining(weeklyTrainingDays: 4);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final draft = controller.draft;
    final days = draft.weeklyTrainingDays ?? 4;
    final paces = draft.goal == null
        ? const <GoalPace>[]
        : NutritionCopy.pacesFor(draft.goal!);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Insets.lg),
      children: [
        Text('Your training week', style: AppTheme.display(22)),
        const SizedBox(height: Insets.sm),
        Text(
          'Fighter Edge sessions per week — used so we never double-count '
          'training inside your activity level.',
          style: AppTheme.body(13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: Insets.xl),
        Row(
          children: [
            _StepButton(
              icon: Icons.remove,
              onTap: days <= 0
                  ? null
                  : () => controller.setTraining(weeklyTrainingDays: days - 1),
            ),
            Expanded(
              child: Column(
                children: [
                  Text('$days', style: AppTheme.display(30)),
                  Text(days == 1 ? 'day / week' : 'days / week',
                      style: AppTheme.body(11, color: AppColors.textMuted)),
                ],
              ),
            ),
            _StepButton(
              icon: Icons.add,
              onTap: days >= 7
                  ? null
                  : () => controller.setTraining(weeklyTrainingDays: days + 1),
            ),
          ],
        ),
        if (paces.isNotEmpty) ...[
          const SizedBox(height: Insets.xl),
          Text('How fast?', style: AppTheme.display(16)),
          const SizedBox(height: Insets.md),
          for (final pace in paces)
            ChoiceCard(
              title: NutritionCopy.paceLabel(pace),
              description: NutritionCopy.paceDescription(pace),
              selected: draft.goalPace == pace,
              onTap: () => controller.setTraining(goalPace: pace),
            ),
        ],
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Icon(
            icon,
            color: onTap == null ? AppColors.textMuted : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
