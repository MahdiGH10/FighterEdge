import 'package:flutter/material.dart';
import '../../../../../l10n/gen/app_localizations.dart';
import '../../../../../theme/app_icons.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_accessibility.dart';
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
    final l = L.of(context);
    if (!controller.canReview) {
      return _Message(
        icon: AppIcons.clipboardText,
        title: l.fuelReviewMoreSteps,
        message: l.fuelReviewMoreStepsHint,
      );
    }

    final target = controller.previewTarget;
    if (target == null) {
      return const _ReviewSkeleton();
    }

    switch (target.status) {
      case NutritionTargetStatus.unsupported:
        return _Message(
          icon: AppIcons.prohibit,
          title: l.fuelReviewUnsupported,
          message: target.reasons
              .map((code) => NutritionCopy.reasonL(l, code))
              .join('\n'),
          tone: AppColors.negative,
        );
      case NutritionTargetStatus.needsProfessionalReview:
        return _Message(
          icon: AppIcons.firstAid,
          title: l.fuelReviewProfessional,
          message: '${l.fuelReviewProfessionalIntro}\n'
              '${target.reasons.map((code) => NutritionCopy.reasonL(l, code)).join('\n')}\n\n'
              '${l.fuelReviewProfessionalOutro}',
          tone: AppColors.warning,
        );
      case NutritionTargetStatus.needsMoreData:
        return _Message(
          icon: AppIcons.clipboardText,
          title: l.fuelReviewMoreSteps,
          message: l.fuelReviewMoreStepsHint,
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
    final l = L.of(context);
    final draft = controller.draft;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Insets.lg),
      children: [
        Text(l.fuelReviewTitle, style: AppType.title1()),
        const SizedBox(height: Insets.sm),
        Text(
          l.fuelReviewHint,
          style: AppType.subhead(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Insets.xl),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.fuelReviewDailyTarget,
                  style: AppType.micro(
                      weight: FontWeight.w700,
                      color: AppColors.textMuted,
                      spacing: 0.8)),
              const SizedBox(height: Insets.xs),
              Text('${target.targetCalories} kcal',
                  style: AppType.largeTitle()),
              const SizedBox(height: Insets.xxs),
              Text(
                l.fuelReviewMaintenanceRange(
                    target.maintenanceRangeLowKcal?.toString() ?? '—',
                    target.maintenanceRangeHighKcal?.toString() ?? '—'),
                style: AppType.subhead(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        _MacroRow(
          protein: target.proteinGrams,
          carbs: target.carbGrams,
          fats: target.fatGrams,
        ),
        const SizedBox(height: Insets.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.fuelReviewAssumptions,
                  style: AppType.micro(
                      weight: FontWeight.w700,
                      color: AppColors.textMuted,
                      spacing: 0.8)),
              const SizedBox(height: Insets.sm),
              if (draft.goal != null)
                _Assumption(
                    l.fuelReviewGoal, NutritionCopy.goalLabelL(l, draft.goal!)),
              if (target.equationProfileUsed != null)
                _Assumption(
                    l.fuelReviewEquation,
                    NutritionCopy.equationLabelL(
                        l, target.equationProfileUsed!)),
              if (draft.normalActivityLevel != null)
                _Assumption(
                    l.fuelReviewActivity,
                    NutritionCopy.activityLabelL(
                        l, draft.normalActivityLevel!)),
              if (draft.goalPace != null)
                _Assumption(l.fuelReviewPace,
                    NutritionCopy.paceLabelL(l, draft.goalPace!)),
              if (target.proteinReferenceWeightKg != null)
                _Assumption(l.fuelReviewProteinBasedOn,
                    '${target.proteinReferenceWeightKg!.toStringAsFixed(1)} kg'),
              if (target.confidence != null)
                _Assumption(l.fuelReviewConfidence,
                    NutritionCopy.confidenceLabelL(l, target.confidence!)),
              _Assumption(l.fuelReviewFiber,
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
                    const Icon(AppIcons.info,
                        color: AppColors.warning, size: 18),
                    const SizedBox(width: Insets.sm),
                    Text(l.fuelReviewWorthKnowing,
                        style: AppType.subhead(weight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                for (final code in target.warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.xs),
                    child: Text('• ${NutritionCopy.warningL(l, code)}',
                        style: AppType.subhead(color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Insets.xl),
        PrimaryButton(
          l.fuelReviewConfirm,
          icon: AppIcons.checkCircle,
          expand: true,
          onPressed: () => onConfirmed(),
        ),
        const SizedBox(height: Insets.md),
        Text(
          l.fuelReviewFooter,
          textAlign: TextAlign.center,
          style: AppType.micro(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// Protein, carbs and fats side by side, or one per row at large text, where
/// three narrow cards split their labels mid-word ("Protei" / "n").
class _MacroRow extends StatelessWidget {
  final int? protein;
  final int? carbs;
  final int? fats;
  const _MacroRow({
    required this.protein,
    required this.carbs,
    required this.fats,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final chips = [
      _MacroChip(l.nutritionProtein, protein, AppColors.protein),
      _MacroChip(l.nutritionCarbs, carbs, AppColors.carbs),
      _MacroChip(l.nutritionFats, fats, AppColors.fats),
    ];
    if (AppAccessibility.isLargeText(context)) {
      return Column(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(height: Insets.sm),
            SizedBox(width: double.infinity, child: chips[i]),
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: Insets.sm),
          Expanded(child: chips[i]),
        ],
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
    return AppCard(
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
          Text(label,
              style: AppType.micro(
                  weight: FontWeight.w700, color: AppColors.textMuted)),
        ],
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
    final labelText = Text(label,
        style: AppType.subhead(
            weight: FontWeight.w500, color: AppColors.textSecondary));
    final valueText =
        Text(value, style: AppType.subhead(weight: FontWeight.w700));
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: AppAccessibility.isLargeText(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, valueText])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: labelText),
              const SizedBox(width: Insets.sm),
              Flexible(child: valueText),
            ]),
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
                borderRadius: BorderRadius.circular(Radii.card),
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
