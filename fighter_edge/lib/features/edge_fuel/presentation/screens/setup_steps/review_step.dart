import 'package:flutter/material.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../theme/app_typography.dart';
import '../../../../../widgets/primary_button.dart';
import '../../../../../widgets/stat_card.dart';
import '../../../domain/models/nutrition_enums.dart';
import '../../../domain/models/nutrition_target.dart';
import '../../controllers/edge_fuel_setup_controller.dart';
import '../../nutrition_copy.dart';

/// Step 6 of 6 — review and explicit confirmation (master prompt §6.6).
/// Shows the maintenance range, proposed targets, the pace explanation, and
/// every assumption used, then requires an explicit tap to save.
class ReviewStep extends StatelessWidget {
  final EdgeFuelSetupController controller;
  final Future<void> Function() onConfirmed;
  const ReviewStep({
    super.key,
    required this.controller,
    required this.onConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.canReview) {
      return const _Message(
        icon: Icons.assignment_late_outlined,
        title: 'A few steps left',
        message: 'Finish the earlier steps to see your personalized plan.',
      );
    }

    final target = controller.previewTarget;
    if (target == null) {
      return const _ReviewSkeleton();
    }

    switch (target.status) {
      case NutritionTargetStatus.unsupported:
        return _Message(
          icon: Icons.block,
          title: "We can't automate this yet",
          message: target.reasons.map(NutritionCopy.reason).join('\n'),
          tone: AppColors.negative,
        );
      case NutritionTargetStatus.needsProfessionalReview:
        return _Message(
          icon: Icons.health_and_safety_outlined,
          title: 'Please check with a professional first',
          message:
              'Based on what you shared, an automated plan isn\'t appropriate here:\n'
              '${target.reasons.map(NutritionCopy.reason).join('\n')}\n\n'
              'Speak with a qualified professional before starting an automated plan. '
              'You can still track meals and habits without calorie targets.',
          tone: AppColors.warning,
        );
      case NutritionTargetStatus.needsMoreData:
        return const _Message(
          icon: Icons.assignment_late_outlined,
          title: 'A few steps left',
          message: 'Finish the earlier steps to see your personalized plan.',
        );
      case NutritionTargetStatus.success:
        return _ReviewSuccess(
          controller: controller,
          target: target,
          onConfirmed: onConfirmed,
        );
    }
  }
}

class _ReviewSuccess extends StatelessWidget {
  final EdgeFuelSetupController controller;
  final NutritionTarget target;
  final Future<void> Function() onConfirmed;
  const _ReviewSuccess({
    required this.controller,
    required this.target,
    required this.onConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    final draft = controller.draft;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Insets.lg),
      children: [
        Text('Your plan', style: AppType.title1()),
        const SizedBox(height: Insets.sm),
        Text(
          'An estimate, not a diagnosis. You can revisit this any time.',
          style: AppType.subhead(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Insets.xl),
        AppCard(
          accent: AppColors.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DAILY TARGET',
                  style: AppType.micro(
                      weight: FontWeight.w700,
                      color: AppColors.textMuted,
                      spacing: 0.8)),
              const SizedBox(height: Insets.xs),
              Text('${target.targetCalories} kcal',
                  style: AppType.largeTitle()),
              const SizedBox(height: Insets.xxs),
              Text(
                'Maintenance range ${target.maintenanceRangeLowKcal}–${target.maintenanceRangeHighKcal} kcal',
                style: AppType.subhead(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        Row(
          children: [
            _MacroChip('Protein', target.proteinGrams, AppColors.protein),
            const SizedBox(width: Insets.sm),
            _MacroChip('Carbs', target.carbGrams, AppColors.carbs),
            const SizedBox(width: Insets.sm),
            _MacroChip('Fats', target.fatGrams, AppColors.fats),
          ],
        ),
        const SizedBox(height: Insets.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ASSUMPTIONS',
                  style: AppType.micro(
                      weight: FontWeight.w700,
                      color: AppColors.textMuted,
                      spacing: 0.8)),
              const SizedBox(height: Insets.sm),
              if (draft.goal != null)
                _Assumption('Goal', NutritionCopy.goalLabel(draft.goal!)),
              if (target.equationProfileUsed != null)
                _Assumption('Equation',
                    NutritionCopy.equationLabel(target.equationProfileUsed!)),
              if (draft.normalActivityLevel != null)
                _Assumption('Daily activity',
                    NutritionCopy.activityLabel(draft.normalActivityLevel!)),
              if (draft.goalPace != null)
                _Assumption('Pace', NutritionCopy.paceLabel(draft.goalPace!)),
              if (target.proteinReferenceWeightKg != null)
                _Assumption('Protein based on',
                    '${target.proteinReferenceWeightKg!.toStringAsFixed(1)} kg'),
              if (target.confidence != null)
                _Assumption('Confidence',
                    NutritionCopy.confidenceLabel(target.confidence!)),
              _Assumption('Fiber range',
                  '${target.fiberGramsLow}–${target.fiberGramsHigh} g'),
            ],
          ),
        ),
        if (target.warnings.isNotEmpty) ...[
          const SizedBox(height: Insets.lg),
          AppCard(
            accent: AppColors.warning,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.warning, size: 18),
                    const SizedBox(width: Insets.sm),
                    Text('Worth knowing',
                        style: AppType.subhead(weight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                for (final code in target.warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${NutritionCopy.warning(code)}',
                        style: AppType.subhead(color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Insets.xl),
        PrimaryButton(
          'Confirm my plan',
          icon: Icons.check_circle_outline,
          expand: true,
          onPressed: () => onConfirmed(),
        ),
        const SizedBox(height: Insets.md),
        Text(
          'You can hide calorie numbers and use meal tracking only, or adjust '
          'these targets later in Fuel settings.',
          textAlign: TextAlign.center,
          style: AppType.micro(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final int? grams;
  final Color color;
  const _MacroChip(this.label, this.grams, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(
            horizontal: Insets.sm, vertical: Insets.md),
        child: Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: Insets.xs),
            Text('${grams ?? 0} g', style: AppType.title2()),
            Text(label.toUpperCase(),
                style: AppType.micro(
                    weight: FontWeight.w700, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _Assumption extends StatelessWidget {
  final String label;
  final String value;
  const _Assumption(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppType.subhead(
                  weight: FontWeight.w500, color: AppColors.textSecondary)),
          Text(value, style: AppType.subhead(weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ReviewSkeleton extends StatelessWidget {
  const _ReviewSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double height) => Container(
          height: height,
          margin: const EdgeInsets.only(bottom: Insets.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(Radii.card),
          ),
        );
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Insets.lg),
      children: [block(120), block(72), block(160)],
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color tone;
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.tone = AppColors.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 28, color: tone),
            ),
            const SizedBox(height: Insets.lg),
            Text(title, textAlign: TextAlign.center, style: AppType.title2()),
            const SizedBox(height: Insets.sm),
            Text(message,
                textAlign: TextAlign.center,
                style: AppType.subhead(
                    weight: FontWeight.w500, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
