import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_icons.dart';

import '../../features/edge_fuel/domain/models/nutrition_enums.dart';
import '../../features/edge_fuel/domain/models/nutrition_profile.dart';
import '../../features/edge_fuel/presentation/widgets/safety_screening_fields.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/app_accessibility.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_text_field.dart';

import 'onboarding_widgets.dart';

class OnboardingStepContent {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;

  const OnboardingStepContent({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  factory OnboardingStepContent.fromIndex({
    required L l,
    required int index,
    required String campGoal,
    required NutritionGoal nutritionGoal,
    required String level,
    required int days,
    required ActivityLevel activity,
    required EquationProfile equationProfile,
    required TextEditingController age,
    required TextEditingController height,
    required TextEditingController currentWeight,
    required TextEditingController targetWeight,
    required NutritionSafetyFlags safetyFlags,
    required NutritionScreeningStatus screeningStatus,
    required String? error,
    required List<String> campGoals,
    required List<String> levels,
    required ValueChanged<String> onCampGoal,
    required ValueChanged<NutritionGoal> onNutritionGoal,
    required ValueChanged<String> onLevel,
    required ValueChanged<int> onDays,
    required ValueChanged<ActivityLevel> onActivity,
    required ValueChanged<EquationProfile> onEquationProfile,
    required ValueChanged<NutritionSafetyFlags> onSafetyFlags,
    required ValueChanged<bool> onScreeningReviewed,
  }) {
    return switch (index) {
      0 => OnboardingStepContent(
          eyebrow: l.setupCampEyebrow,
          title: l.setupCampQuestion,
          subtitle: l.setupCampHint,
          child: ChoiceWrap(
            values: campGoals,
            selected: campGoal,
            labelFor: (value) => setupCampGoal(l, value),
            onSelected: onCampGoal,
          ),
        ),
      1 => OnboardingStepContent(
          eyebrow: l.setupNutritionEyebrow,
          title: l.setupNutritionQuestion,
          subtitle: l.setupNutritionHint,
          child: Column(
            children: [
              for (final goal in NutritionGoal.values)
                SelectCard<NutritionGoal>(
                  value: goal,
                  selected: nutritionGoal,
                  title: setupGoalLabel(l, goal),
                  description: setupGoalDescription(l, goal),
                  icon: switch (goal) {
                    NutritionGoal.loseFat => AppIcons.trendDown,
                    NutritionGoal.maintain => AppIcons.scales,
                    NutritionGoal.gainMuscle => AppIcons.trendUp,
                  },
                  onSelected: onNutritionGoal,
                ),
            ],
          ),
        ),
      2 => OnboardingStepContent(
          eyebrow: l.setupBodyEyebrow,
          title: l.setupBodyQuestion,
          subtitle: l.setupBodyHint,
          child: BodyInputs(
            age: age,
            height: height,
            currentWeight: currentWeight,
            targetWeight: targetWeight,
            nutritionGoal: nutritionGoal,
            error: error,
            safetyFlags: safetyFlags,
            screeningStatus: screeningStatus,
            onSafetyFlags: onSafetyFlags,
            onScreeningReviewed: onScreeningReviewed,
          ),
        ),
      // Its own step, not a footnote under the body fields: one decision per
      // screen, and this one needs a sentence of explanation to be fair.
      3 => OnboardingStepContent(
          eyebrow: l.setupEquationEyebrow,
          title: l.setupEquationQuestion,
          subtitle: l.setupEquationHint,
          child: Column(
            children: [
              for (final profile in EquationProfile.values)
                SelectCard<EquationProfile>(
                  value: profile,
                  selected: equationProfile,
                  title: setupEquationLabel(l, profile),
                  description: setupEquationDescription(l, profile),
                  icon: AppIcons.calculator,
                  onSelected: onEquationProfile,
                ),
            ],
          ),
        ),
      4 => OnboardingStepContent(
          eyebrow: l.setupActivityEyebrow,
          title: l.setupActivityQuestion,
          subtitle: l.setupActivityHint,
          child: Column(
            children: [
              for (final level in ActivityLevel.values)
                SelectCard<ActivityLevel>(
                  value: level,
                  selected: activity,
                  title: setupActivityLabel(l, level),
                  description: setupActivityDescription(l, level),
                  icon: AppIcons.personSimpleWalk,
                  onSelected: onActivity,
                ),
            ],
          ),
        ),
      5 => OnboardingStepContent(
          eyebrow: l.setupRhythmEyebrow,
          title: l.setupRhythmQuestion,
          subtitle: l.setupRhythmHint,
          child: Column(
            children: [
              ChoiceWrap(
                values: levels,
                selected: level,
                labelFor: (value) => onboardingLevel(l, value),
                onSelected: onLevel,
              ),
              const SizedBox(height: Insets.xl),
              DayStepper(value: days, onChanged: onDays),
            ],
          ),
        ),
      _ => OnboardingStepContent(
          eyebrow: l.setupReviewEyebrow,
          title: l.setupReviewQuestion,
          subtitle: l.setupReviewHint,
          child: ReviewSummary(
            campGoal: campGoal,
            nutritionGoal: nutritionGoal,
            level: level,
            days: days,
            activity: activity,
          ),
        ),
    };
  }
}

/// Labels are translated at display time; saved setup values remain stable.
String setupCampGoal(L l, String value) => switch (value) {
      'Lose weight safely' => l.setupCampLoseWeight,
      'Gain muscle' => l.setupCampGainMuscle,
      'Improve technique' => l.setupCampTechnique,
      'Get competition ready' => l.setupCampCompetition,
      _ => l.setupCampStructure,
    };

String setupGoalLabel(L l, NutritionGoal goal) => switch (goal) {
      NutritionGoal.loseFat => l.onboardingLoseFat,
      NutritionGoal.maintain => l.setupGoalMaintainLabel,
      NutritionGoal.gainMuscle => l.onboardingGainMuscle,
    };

String setupGoalDescription(L l, NutritionGoal goal) => switch (goal) {
      NutritionGoal.loseFat => l.setupGoalLoseDescription,
      NutritionGoal.maintain => l.setupGoalMaintainDescription,
      NutritionGoal.gainMuscle => l.setupGoalGainDescription,
    };

String setupEquationLabel(L l, EquationProfile profile) => switch (profile) {
      EquationProfile.higherOffset => l.setupEquationHigher,
      EquationProfile.lowerOffset => l.setupEquationLower,
      EquationProfile.neutral => l.setupEquationNeutral,
    };

String setupEquationDescription(L l, EquationProfile profile) =>
    switch (profile) {
      EquationProfile.higherOffset => l.setupEquationHigherHint,
      EquationProfile.lowerOffset => l.setupEquationLowerHint,
      EquationProfile.neutral => l.setupEquationNeutralHint,
    };

String setupActivityLabel(L l, ActivityLevel level) => switch (level) {
      ActivityLevel.veryLow => l.setupActivityVeryLow,
      ActivityLevel.light => l.setupActivityLight,
      ActivityLevel.moderate => l.setupActivityModerate,
      ActivityLevel.high => l.setupActivityHigh,
      ActivityLevel.veryHigh => l.setupActivityVeryHigh,
    };

String setupActivityDescription(L l, ActivityLevel level) => switch (level) {
      ActivityLevel.veryLow => l.setupActivityVeryLowHint,
      ActivityLevel.light => l.setupActivityLightHint,
      ActivityLevel.moderate => l.setupActivityModerateHint,
      ActivityLevel.high => l.setupActivityHighHint,
      ActivityLevel.veryHigh => l.setupActivityVeryHighHint,
    };

class BodyInputs extends StatelessWidget {
  final TextEditingController age;
  final TextEditingController height;
  final TextEditingController currentWeight;
  final TextEditingController targetWeight;
  final NutritionGoal nutritionGoal;
  final String? error;
  final NutritionSafetyFlags safetyFlags;
  final NutritionScreeningStatus screeningStatus;
  final ValueChanged<NutritionSafetyFlags> onSafetyFlags;
  final ValueChanged<bool> onScreeningReviewed;

  const BodyInputs({
    super.key,
    required this.age,
    required this.height,
    required this.currentWeight,
    required this.targetWeight,
    required this.nutritionGoal,
    required this.error,
    required this.safetyFlags,
    required this.screeningStatus,
    required this.onSafetyFlags,
    required this.onScreeningReviewed,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final showTarget = nutritionGoal != NutritionGoal.maintain;
    final targetLabel = nutritionGoal == NutritionGoal.loseFat
        ? l.setupTargetMilestone
        : l.setupGainMilestone;

    final ageField = AppTextField(
      controller: age,
      label: l.setupAge,
      icon: AppIcons.cake,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );
    final heightField = AppTextField(
      controller: height,
      label: l.setupHeight,
      icon: AppIcons.ruler,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [_decimalInput],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Half a narrow screen each at large text cut "Height cm" to "He...";
        // one field per row gives every label the full width.
        if (AppAccessibility.isLargeText(context)) ...[
          ageField,
          const SizedBox(height: Insets.md),
          heightField,
        ] else
          Row(
            children: [
              Expanded(child: ageField),
              const SizedBox(width: Insets.md),
              Expanded(child: heightField),
            ],
          ),
        const SizedBox(height: Insets.md),
        AppTextField(
          controller: currentWeight,
          label: l.setupCurrentWeight,
          icon: AppIcons.scales,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_decimalInput],
        ),
        if (showTarget) ...[
          const SizedBox(height: Insets.md),
          AppTextField(
            controller: targetWeight,
            label: targetLabel,
            icon: nutritionGoal == NutritionGoal.loseFat
                ? AppIcons.arrowDownRight
                : AppIcons.arrowUpRight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimalInput],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            l.setupOptionalMilestone,
            style: AppType.subhead(
              weight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: Insets.md),
          Text(
            error!,
            style: AppType.subhead(
              weight: FontWeight.w700,
              color: AppColors.negative,
            ),
          ),
        ],
        const SizedBox(height: Insets.xl),
        SafetyScreeningFields(
          flags: safetyFlags,
          status: screeningStatus,
          onFlagsChanged: onSafetyFlags,
          onReviewedChanged: onScreeningReviewed,
        ),
      ],
    );
  }
}

class ReviewSummary extends StatelessWidget {
  final String campGoal;
  final NutritionGoal nutritionGoal;
  final String level;
  final int days;
  final ActivityLevel activity;

  const ReviewSummary({
    super.key,
    required this.campGoal,
    required this.nutritionGoal,
    required this.level,
    required this.days,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      children: [
        _SummaryRow(
            l.setupSummaryCamp, setupCampGoal(l, campGoal), AppIcons.flag),
        _SummaryRow(l.setupSummaryNutrition, setupGoalLabel(l, nutritionGoal),
            AppIcons.forkKnife),
        _SummaryRow(l.setupSummaryExperience, onboardingLevel(l, level),
            AppIcons.medal),
        _SummaryRow(l.setupSummaryTraining, l.setupDaysPerWeek(days),
            AppIcons.boxingGlove),
        _SummaryRow(
          l.setupSummaryActivity,
          setupActivityLabel(l, activity),
          AppIcons.personSimpleWalk,
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryRow(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppType.micro(
                    color: AppColors.textMuted,
                    weight: FontWeight.w800,
                    spacing: .8,
                  ),
                ),
                const SizedBox(height: Insets.xxs),
                Text(value, style: AppType.callout(weight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final _decimalInput = FilteringTextInputFormatter.allow(
  RegExp(r'^\d*[\.,]?\d{0,1}'),
);
