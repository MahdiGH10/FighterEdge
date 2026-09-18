import 'package:flutter/material.dart';

import '../../features/edge_fuel/domain/models/nutrition_enums.dart';
import '../../features/edge_fuel/domain/models/nutrition_target.dart';
import '../../features/edge_fuel/presentation/nutrition_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/premium_effects.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/stat_card.dart';

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

  const PlanReadyView({
    super.key,
    required this.plan,
    required this.isBusy,
    required this.onOpenDashboard,
    required this.onViewFuelPlan,
  });

  @override
  Widget build(BuildContext context) {
    final target = plan.target;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PremiumBackground(
        child: SafeArea(
          child: ListView(
            padding:
                const EdgeInsets.fromLTRB(Insets.lg, Insets.lg, Insets.lg, 36),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: BrandLogo(scale: .7),
              ),
              const SizedBox(height: Insets.xxl),
              AppCard(
                accent: AppColors.positive,
                elevated: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.positive.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: AppColors.positive, size: 26),
                    ),
                    const SizedBox(height: Insets.lg),
                    Text('Your first Fighter Edge plan is ready',
                        style: AppType.largeTitle()),
                    const SizedBox(height: Insets.sm),
                    Text(
                      'A simple starting point for ${NutritionCopy.goalLabel(plan.nutritionGoal).toLowerCase()}. You can adjust it as your training changes.',
                      style: AppType.callout(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: Insets.xl),
                    if (target?.isSuccess == true) ...[
                      _PlanMetric(
                        label: 'Daily fuel',
                        amount: target!.targetCalories,
                        suffix: ' kcal',
                        icon: Icons.bolt,
                      ),
                      const SizedBox(height: Insets.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _PlanMetric(
                              label: 'Protein',
                              amount: target.proteinGrams,
                              suffix: 'g',
                              icon: Icons.fitness_center,
                            ),
                          ),
                          const SizedBox(width: Insets.sm),
                          Expanded(
                            child: _PlanMetric(
                              label: 'Carbs',
                              amount: target.carbGrams,
                              suffix: 'g',
                              icon: Icons.flash_on,
                            ),
                          ),
                          const SizedBox(width: Insets.sm),
                          Expanded(
                            child: _PlanMetric(
                              label: 'Fats',
                              amount: target.fatGrams,
                              suffix: 'g',
                              icon: Icons.opacity,
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Text(
                        'Your training rhythm is ready. Add body details later to unlock a personalized EdgeFuel target.',
                        style: AppType.callout(color: AppColors.textSecondary),
                      ),
                    const SizedBox(height: Insets.lg),
                    _PlanRhythm(days: plan.days, level: plan.level),
                  ],
                ),
              ),
              const SizedBox(height: Insets.xl),
              PrimaryButton(
                isBusy ? 'Opening your dashboard...' : 'Open dashboard',
                icon: Icons.dashboard_outlined,
                expand: true,
                onPressed: isBusy ? null : onOpenDashboard,
              ),
              const SizedBox(height: Insets.sm),
              GhostButton(
                'View fuel plan',
                icon: Icons.restaurant_outlined,
                expand: true,
                onPressed: isBusy ? null : onViewFuelPlan,
              ),
              const SizedBox(height: Insets.md),
              Text(
                'Targets are estimates, not medical advice. Review your inputs anytime in EdgeFuel.',
                textAlign: TextAlign.center,
                style: AppType.micro(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanMetric extends StatelessWidget {
  final String label;

  /// Null when the calculator could not produce this figure. Rendered as a
  /// dash rather than coerced to 0 — a target of "0 kcal" would be a lie.
  final int? amount;
  final String suffix;
  final IconData icon;

  const _PlanMetric({
    required this.label,
    required this.amount,
    required this.suffix,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(height: Insets.sm),
          // This is the moment the plan becomes real to the user — the number
          // arriving *is* the event, so it counts rather than appearing.
          if (amount case final value?)
            AnimatedCount(
              value: value.toDouble(),
              from: 0,
              formatter: (v) => '${v.round()}$suffix',
              style: AppType.title2().copyWith(fontWeight: FontWeight.w800),
            )
          else
            Text('—',
                style: AppType.title2().copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: Insets.xxs),
          Text(label, style: AppType.micro(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _PlanRhythm extends StatelessWidget {
  final int days;
  final String level;

  const _PlanRhythm({required this.days, required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.sports_mma, color: AppColors.primary, size: 20),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Text(
            '$days training days · $level level · fresh camp week',
            style: AppType.subhead(weight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
