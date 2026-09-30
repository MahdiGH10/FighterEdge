import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_icons.dart';

import '../../../../billing/subscription.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../observability/telemetry.dart';
import '../../../../routing/app_navigation.dart';
import '../../../../routing/app_router.dart';
import '../../../../screens/paywall_screen.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_scaffold.dart';
import '../../../../widgets/empty_state.dart';
import '../../../../widgets/primary_button.dart';
import '../../../../widgets/stat_card.dart';
import '../../domain/models/nutrition_enums.dart';
import '../../domain/models/nutrition_target.dart';
import '../controllers/edge_fuel_controller.dart';
import '../nutrition_copy.dart';
import '../widgets/fuel_what_is_left.dart';
import 'edge_fuel_coach_screen.dart';
import 'edge_fuel_setup_screen.dart';

/// Read-only view of the confirmed deterministic EdgeFuel target.
///
/// The plan stays the source of truth for targets. The daily brief lives on
/// Home (the Corner Brief); from here Pro opens the EdgeFuel Coach to ask
/// about the plan.
class EdgeFuelPlanScreen extends StatelessWidget {
  const EdgeFuelPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final edgeFuel = context.watch<EdgeFuelController>();
    final target = edgeFuel.target;

    return ScreenScaffold(
      title: 'Your plan',
      showBack: true,
      body: target == null || !target.isSuccess
          ? _EmptyPlan(target: target)
          : _PlanBody(target: target, edgeFuel: edgeFuel),
    );
  }
}

class _EmptyPlan extends StatelessWidget {
  final NutritionTarget? target;
  const _EmptyPlan({required this.target});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthController>().user?.id;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.lg,
        Insets.lg,
        Insets.xxl,
      ),
      children: [
        const EmptyState(
          icon: AppIcons.forkKnife,
          title: 'No plan yet',
          message: 'Run the EdgeFuel setup to get a personalized daily target.',
        ),
        const SizedBox(height: Insets.lg),
        PrimaryButton(
          'Start setup',
          icon: AppIcons.arrowRight,
          expand: true,
          onPressed: userId == null
              ? null
              : () => AppNavigation.push(
                    context,
                    AppRoutes.fuelSetup,
                    fallbackBuilder: (_) => const EdgeFuelSetupScreen(),
                  ),
        ),
      ],
    );
  }
}

class _PlanBody extends StatelessWidget {
  final NutritionTarget target;
  final EdgeFuelController edgeFuel;
  const _PlanBody({required this.target, required this.edgeFuel});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.lg,
        Insets.lg,
        Insets.xxl,
      ),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily target',
                style: AppType.micro(
                  weight: FontWeight.w700,
                  color: AppColors.textMuted,
                  spacing: 0.8,
                ),
              ),
              const SizedBox(height: Insets.xs),
              Text('${target.targetCalories} kcal',
                  style: AppType.largeTitle()),
              const SizedBox(height: Insets.xxs),
              Text(
                'Maintenance range ${target.maintenanceRangeLowKcal}'
                '–${target.maintenanceRangeHighKcal} kcal',
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
              Text(
                'How this was calculated',
                style: AppType.micro(
                  weight: FontWeight.w700,
                  color: AppColors.textMuted,
                  spacing: 0.8,
                ),
              ),
              const SizedBox(height: Insets.sm),
              Text(
                'Estimated resting energy: ${target.estimatedRmrKcal} kcal '
                '(Mifflin–St Jeor, ${target.equationProfileUsed != null ? NutritionCopy.equationLabel(target.equationProfileUsed!) : 'midpoint'}). '
                'Multiplied by your activity factor, then adjusted for your '
                'goal pace. This is an estimate, not a diagnosis — '
                'recalculate any time by revisiting setup.',
                style: AppType.subhead(
                  weight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              if (target.confidence != null) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  NutritionCopy.confidenceLabel(target.confidence!),
                  // Red reads as a warning; confidence is good news unless
                  // it is low.
                  style: AppType.micro(
                    weight: FontWeight.w700,
                    color: switch (target.confidence!) {
                      ConfidenceLabel.high => AppColors.positive,
                      ConfidenceLabel.medium => AppColors.textSecondary,
                      ConfidenceLabel.low => AppColors.warning,
                    },
                  ),
                ),
              ],
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
                    const Icon(
                      AppIcons.info,
                      color: AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: Insets.sm),
                    Text(
                      'Worth knowing',
                      style: AppType.subhead(weight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                for (final code in target.warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.xs),
                    child: Text(
                      '• ${NutritionCopy.warning(code)}',
                      style: AppType.subhead(color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Insets.lg),
        const _CoachSection(),
        if (FuelWhatIsLeft.appliesTo(edgeFuel)) ...[
          const SizedBox(height: Insets.md),
          FuelWhatIsLeft(edgeFuel: edgeFuel),
        ],
        const SizedBox(height: Insets.lg),
        GhostButton(
          'Redo setup',
          icon: AppIcons.slidersHorizontal,
          expand: true,
          onPressed: () => AppNavigation.push(
            context,
            AppRoutes.fuelSetup,
            fallbackBuilder: (_) => const EdgeFuelSetupScreen(),
          ),
        ),
      ],
    );
  }
}

/// The way into the EdgeFuel Coach from the plan: open it with Pro, see Pro
/// without.
class _CoachSection extends StatelessWidget {
  const _CoachSection();

  @override
  Widget build(BuildContext context) {
    final isPro =
        context.watch<AuthController>().allows(Feature.edgeFuelAiCoach);

    return AppCard(
      accent: AppColors.premium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                AppIcons.clipboardText,
                color: AppColors.premium,
                size: IconSizes.inline,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  'EdgeFuel Coach',
                  style: AppType.micro(
                    weight: FontWeight.w800,
                    color: AppColors.textMuted,
                    spacing: .8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Ask about your plan, your day or your fight week.',
            style: AppType.callout(weight: FontWeight.w800),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            isPro
                ? 'The coach can explain your plan, but it cannot change the '
                    'calculated target. Your daily Corner Brief is on Home.'
                : 'Pro adds the coach and a daily Corner Brief on Home, '
                    'grounded in your own numbers.',
            style: AppType.subhead(color: AppColors.textSecondary),
          ),
          const SizedBox(height: Insets.md),
          if (isPro)
            PrimaryButton(
              'Ask your coach',
              icon: AppIcons.clipboardText,
              expand: true,
              onPressed: () => AppNavigation.push(
                context,
                AppRoutes.fuelCoach,
                fallbackBuilder: (_) => const EdgeFuelCoachScreen(),
              ),
            )
          else
            PrimaryButton(
              'See Pro',
              icon: AppIcons.lockSimpleOpen,
              expand: true,
              onPressed: () {
                Telemetry.fromContext(context).track(
                  TelemetryEvent.premiumCtaTapped,
                  parameters: {'surface': 'fuel_plan'},
                );
                AppNavigation.push(
                  context,
                  AppRoutes.paywall,
                  extra: const PaywallRouteArgs(
                    highlight: Feature.edgeFuelAiCoach,
                    trigger: PaywallTrigger.coach,
                  ),
                  fallbackBuilder: (_) => const PaywallScreen(
                    highlight: Feature.edgeFuelAiCoach,
                    trigger: PaywallTrigger.coach,
                  ),
                );
              },
            ),
        ],
      ),
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
          horizontal: Insets.sm,
          vertical: Insets.md,
        ),
        child: Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: Insets.xs),
            Text('${grams ?? 0} g', style: AppType.title2()),
            Text(
              label,
              style: AppType.micro(
                weight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
