import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/edge_fuel/domain/models/nutrition_enums.dart';
import '../../features/edge_fuel/presentation/nutrition_copy.dart';
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
    required String? error,
    required List<String> campGoals,
    required List<String> levels,
    required ValueChanged<String> onCampGoal,
    required ValueChanged<NutritionGoal> onNutritionGoal,
    required ValueChanged<String> onLevel,
    required ValueChanged<int> onDays,
    required ValueChanged<ActivityLevel> onActivity,
    required ValueChanged<EquationProfile> onEquationProfile,
  }) {
    return switch (index) {
      0 => OnboardingStepContent(
          eyebrow: 'Fresh account',
          title: 'What should Fighter Edge build first?',
          subtitle:
              'Pick the outcome that should shape your first training camp.',
          child: ChoiceWrap(
            values: campGoals,
            selected: campGoal,
            onSelected: onCampGoal,
          ),
        ),
      1 => OnboardingStepContent(
          eyebrow: 'Nutrition goal',
          title: 'What should EdgeFuel optimize for?',
          subtitle:
              'This creates your first calorie and macro target. You can edit it later.',
          child: Column(
            children: [
              for (final goal in NutritionGoal.values)
                SelectCard<NutritionGoal>(
                  value: goal,
                  selected: nutritionGoal,
                  title: NutritionCopy.goalLabel(goal),
                  description: NutritionCopy.goalDescription(goal),
                  icon: switch (goal) {
                    NutritionGoal.loseFat => Icons.trending_down,
                    NutritionGoal.maintain => Icons.balance,
                    NutritionGoal.gainMuscle => Icons.trending_up,
                  },
                  onSelected: onNutritionGoal,
                ),
            ],
          ),
        ),
      2 => OnboardingStepContent(
          eyebrow: 'Body basics',
          title: 'Tell us your starting point.',
          subtitle:
              'No weight class needed. Use normal body details so your target is personal.',
          child: BodyInputs(
            age: age,
            height: height,
            currentWeight: currentWeight,
            targetWeight: targetWeight,
            nutritionGoal: nutritionGoal,
            error: error,
          ),
        ),
      // Its own step, not a footnote under the body fields: one decision per
      // screen, and this one needs a sentence of explanation to be fair.
      3 => OnboardingStepContent(
          eyebrow: 'Calorie formula',
          title: 'Which formula fits your body?',
          subtitle: NutritionCopy.equationExplainer,
          child: Column(
            children: [
              for (final profile in EquationProfile.values)
                SelectCard<EquationProfile>(
                  value: profile,
                  selected: equationProfile,
                  title: NutritionCopy.equationLabel(profile),
                  description: NutritionCopy.equationDescription(profile),
                  icon: Icons.calculate_outlined,
                  onSelected: onEquationProfile,
                ),
            ],
          ),
        ),
      4 => OnboardingStepContent(
          eyebrow: 'Daily activity',
          title: 'Outside the gym, how active are you?',
          subtitle:
              'This is separate from training days so calories are not double-counted.',
          child: Column(
            children: [
              for (final level in ActivityLevel.values)
                SelectCard<ActivityLevel>(
                  value: level,
                  selected: activity,
                  title: NutritionCopy.activityLabel(level),
                  description: NutritionCopy.activityDescription(level),
                  icon: Icons.directions_walk,
                  onSelected: onActivity,
                ),
            ],
          ),
        ),
      5 => OnboardingStepContent(
          eyebrow: 'Training rhythm',
          title: 'How many days can you train?',
          subtitle:
              'Choose a realistic week. Consistency beats an impossible plan.',
          child: Column(
            children: [
              ChoiceWrap(
                values: levels,
                selected: level,
                onSelected: onLevel,
              ),
              const SizedBox(height: Insets.xl),
              DayStepper(value: days, onChanged: onDays),
            ],
          ),
        ),
      _ => OnboardingStepContent(
          eyebrow: 'Review',
          title: 'Your first plan is ready.',
          subtitle:
              'Fighter Edge will start you fresh: clean dashboard, training week, and an EdgeFuel target.',
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

class BodyInputs extends StatelessWidget {
  final TextEditingController age;
  final TextEditingController height;
  final TextEditingController currentWeight;
  final TextEditingController targetWeight;
  final NutritionGoal nutritionGoal;
  final String? error;

  const BodyInputs({
    super.key,
    required this.age,
    required this.height,
    required this.currentWeight,
    required this.targetWeight,
    required this.nutritionGoal,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final showTarget = nutritionGoal != NutritionGoal.maintain;
    final targetLabel = nutritionGoal == NutritionGoal.loseFat
        ? 'Target milestone in kg'
        : 'Gain milestone in kg';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: age,
                label: 'Age',
                icon: Icons.cake_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: AppTextField(
                controller: height,
                label: 'Height cm',
                icon: Icons.straighten,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_decimalInput],
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        AppTextField(
          controller: currentWeight,
          label: 'Current weight kg',
          icon: Icons.monitor_weight_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_decimalInput],
        ),
        if (showTarget) ...[
          const SizedBox(height: Insets.md),
          AppTextField(
            controller: targetWeight,
            label: targetLabel,
            icon: nutritionGoal == NutritionGoal.loseFat
                ? Icons.south_east
                : Icons.north_east,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimalInput],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Optional: leave blank and Fighter Edge starts with a safe 5% milestone.',
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
    return Column(
      children: [
        _SummaryRow('Camp', campGoal, Icons.flag_outlined),
        _SummaryRow('Nutrition', NutritionCopy.goalLabel(nutritionGoal),
            Icons.restaurant),
        _SummaryRow('Experience', level, Icons.workspace_premium_outlined),
        _SummaryRow('Training', '$days days per week', Icons.sports_mma),
        _SummaryRow(
          'Daily activity',
          NutritionCopy.activityLabel(activity),
          Icons.directions_walk,
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
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
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
