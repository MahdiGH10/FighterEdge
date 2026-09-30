import 'package:flutter/material.dart';

import '../../features/edge_fuel/domain/models/nutrition_enums.dart';
import '../../features/edge_fuel/domain/models/nutrition_target.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../observability/telemetry.dart';
import '../../theme/app_accessibility.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/premium_effects.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/stat_card.dart';
import 'onboarding_widgets.dart';

class CompletedOnboardingPlan {
  final NutritionTarget? target;
  final NutritionGoal nutritionGoal;
  final String campGoal;
  final String level;
  final int days;

  const CompletedOnboardingPlan({
    required this.target,
    required this.nutritionGoal,
    required this.campGoal,
    required this.level,
    required this.days,
  });
}

class PlanReadyView extends StatelessWidget {
  final CompletedOnboardingPlan plan;
  final bool isBusy;
  final VoidCallback onOpenDashboard;
  final VoidCallback onViewFuelPlan;
  final VoidCallback onViewPro;

  const PlanReadyView(
      {super.key,
      required this.plan,
      required this.isBusy,
      required this.onOpenDashboard,
      required this.onViewFuelPlan,
      required this.onViewPro});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final target = plan.target;
    final large = AppAccessibility.isLargeText(context);
    final macros = [
      _PlanMetric(label: 'Protein', amount: target?.proteinGrams, suffix: 'g'),
      _PlanMetric(label: 'Carbs', amount: target?.carbGrams, suffix: 'g'),
      _PlanMetric(label: 'Fats', amount: target?.fatGrams, suffix: 'g'),
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppBackground(
          child: SafeArea(
              child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.lg, Insets.xxl, Insets.lg, Insets.xxxl),
        children: [
          Text('Your first Fighter Edge plan is ready',
              style: AppType.largeTitle()),
          const SizedBox(height: Insets.md),
          Text(l.planReadyExplanation,
              style: AppType.callout(color: AppColors.textSecondary)),
          const SizedBox(height: Insets.lg),
          PlanPreviewCard(
              campGoal: plan.campGoal,
              nutritionGoal: plan.nutritionGoal,
              level: plan.level,
              days: plan.days),
          const SizedBox(height: Insets.xl),
          if (target?.isSuccess == true)
            AppCard(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlanMetric(
                    label: l.planReadyCalories,
                    amount: target!.targetCalories,
                    suffix: ' kcal'),
                const SizedBox(height: Insets.lg),
                if (large)
                  ...macros.map((metric) => Padding(
                      padding: const EdgeInsets.only(bottom: Insets.md),
                      child: metric))
                else
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final metric in macros) Expanded(child: metric),
                  ]),
              ],
            ))
          else
            Text(l.planReadyMissingTarget,
                style: AppType.callout(color: AppColors.textSecondary)),
          const SizedBox(height: Insets.xl),
          PrimaryButton(isBusy ? 'Opening your dashboard...' : 'Open dashboard',
              expand: true, onPressed: isBusy ? null : onOpenDashboard),
          const SizedBox(height: Insets.sm),
          GhostButton('View fuel plan',
              expand: true, onPressed: isBusy ? null : onViewFuelPlan),
          const SizedBox(height: Insets.xl),
          Text(l.planReadyProTitle,
              style: AppType.headline(color: AppColors.premium)),
          const SizedBox(height: Insets.sm),
          Text(l.planReadyProBody,
              style: AppType.callout(color: AppColors.textSecondary)),
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.premium,
                    minimumSize: const Size(AppAccessibility.minTouchTarget,
                        AppAccessibility.minTouchTarget)),
                onPressed: isBusy
                    ? null
                    : () {
                        Telemetry.fromContext(context).track(
                            TelemetryEvent.premiumCtaTapped,
                            parameters: {
                              'surface': 'plan_ready',
                              'access': 'free'
                            });
                        onViewPro();
                      },
                child: const Text('See Pro options'),
              )),
          const SizedBox(height: Insets.md),
          Text(
              'Targets are estimates, not medical advice. Review your inputs anytime in EdgeFuel.',
              style: AppType.micro(color: AppColors.textMuted)),
        ],
      ))),
    );
  }
}

class _PlanMetric extends StatelessWidget {
  final String label;
  final int? amount;
  final String suffix;
  const _PlanMetric(
      {required this.label, required this.amount, required this.suffix});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(amount == null ? '—' : '$amount$suffix',
              style: AppType.title2()),
          const SizedBox(height: Insets.xxs),
          Text(label, style: AppType.subhead(color: AppColors.textSecondary)),
        ],
      );
}
