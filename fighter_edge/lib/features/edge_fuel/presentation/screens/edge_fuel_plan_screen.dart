import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../billing/subscription.dart';
import '../../../../controllers/auth_controller.dart';
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
import '../../ai/edge_fuel_ai_gateway.dart';
import '../../ai/edge_fuel_ai_models.dart';
import '../../domain/models/nutrition_target.dart';
import '../controllers/edge_fuel_ai_controller.dart';
import '../controllers/edge_fuel_controller.dart';
import '../nutrition_copy.dart';
import 'edge_fuel_setup_screen.dart';

/// Read-only view of the confirmed EdgeFuel plan (master prompt §5.2, §19
/// EF-1: "Plan screen, calculation explanation"). Reachable from the
/// Nutrition tab once setup is confirmed.
class EdgeFuelPlanScreen extends StatelessWidget {
  const EdgeFuelPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final edgeFuel = context.watch<EdgeFuelController>();
    final target = edgeFuel.target;

    return ChangeNotifierProvider(
      create: (ctx) =>
          EdgeFuelAiController(gateway: ctx.read<EdgeFuelAiGateway>()),
      child: ScreenScaffold(
        title: 'Your plan',
        showBack: true,
        body: target == null || !target.isSuccess
            ? _EmptyPlan(target: target)
            : _PlanBody(target: target, edgeFuel: edgeFuel),
      ),
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
          Insets.lg, Insets.lg, Insets.lg, Insets.xxl),
      children: [
        const EmptyState(
          icon: Icons.restaurant_menu,
          title: 'No plan yet',
          message: 'Run the EdgeFuel setup to get a personalized daily target.',
        ),
        const SizedBox(height: Insets.lg),
        PrimaryButton(
          'Start setup',
          icon: Icons.arrow_forward,
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
          Insets.lg, Insets.lg, Insets.lg, Insets.xxl),
      children: [
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
              Text('HOW THIS WAS CALCULATED',
                  style: AppType.micro(
                      weight: FontWeight.w700,
                      color: AppColors.textMuted,
                      spacing: 0.8)),
              const SizedBox(height: Insets.sm),
              Text(
                'Estimated resting energy: ${target.estimatedRmrKcal} kcal '
                '(Mifflin–St Jeor, ${target.equationProfileUsed != null ? NutritionCopy.equationLabel(target.equationProfileUsed!) : 'midpoint'}). '
                'Multiplied by your activity factor, then adjusted for your goal pace. '
                'This is an estimate, not a diagnosis — recalculate any time by revisiting setup.',
                style: AppType.subhead(
                    weight: FontWeight.w500, color: AppColors.textSecondary),
              ),
              if (target.confidence != null) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  NutritionCopy.confidenceLabel(target.confidence!),
                  style: AppType.micro(
                      weight: FontWeight.w700, color: AppColors.accentText),
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
        const SizedBox(height: Insets.lg),
        _AiCoachSection(target: target, edgeFuel: edgeFuel),
        const SizedBox(height: Insets.lg),
        PrimaryButton(
          'Redo setup',
          icon: Icons.tune,
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

/// "Ask EdgeFuel Coach" — the one AI surface in this release (master prompt
/// §13.1: explain the already-calculated plan in plain language). Never
/// calculates or overrides the target above; only explains it.
class _AiCoachSection extends StatelessWidget {
  final NutritionTarget target;
  final EdgeFuelController edgeFuel;
  const _AiCoachSection({required this.target, required this.edgeFuel});

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<EdgeFuelAiController>();
    final isPro =
        context.watch<AuthController>().allows(Feature.edgeFuelAiCoach);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: AppColors.premium, size: 18),
              const SizedBox(width: Insets.sm),
              Text('EDGEFUEL COACH',
                  style: AppType.micro(
                      weight: FontWeight.w700,
                      color: AppColors.textMuted,
                      spacing: 0.8)),
            ],
          ),
          const SizedBox(height: Insets.sm),
          if (isPro)
            _AiCoachBody(ai: ai, target: target, edgeFuel: edgeFuel)
          else
            const _AiCoachLocked(),
        ],
      ),
    );
  }
}

/// Shown to free users in place of the coach — never the explanation itself.
/// The Ask/Ask-again request must not fire for a free account (master prompt
/// §13.1 pairs with the server quota — this is the client half of "gate the
/// AI behind Pro").
class _AiCoachLocked extends StatelessWidget {
  const _AiCoachLocked();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Get a plain-language explanation of your plan, and why it is set '
          'the way it is.',
          style: AppType.subhead(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Insets.md),
        GhostButton(
          'See Pro',
          icon: Icons.lock_outline,
          expand: true,
          onPressed: () => AppNavigation.push(
            context,
            AppRoutes.paywall,
            extra: Feature.edgeFuelAiCoach,
            fallbackBuilder: (_) =>
                const PaywallScreen(highlight: Feature.edgeFuelAiCoach),
          ),
        ),
      ],
    );
  }
}

class _AiCoachBody extends StatelessWidget {
  final EdgeFuelAiController ai;
  final NutritionTarget target;
  final EdgeFuelController edgeFuel;
  const _AiCoachBody({
    required this.ai,
    required this.target,
    required this.edgeFuel,
  });

  @override
  Widget build(BuildContext context) {
    if (ai.isLoading) {
      return const _AiCoachSkeleton();
    }

    final result = ai.lastResult;
    if (result == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ask for a plain-language explanation of your plan. This sends your '
            'target and food log to our server — never medical details beyond '
            'what you already entered in setup.',
            style: AppType.subhead(color: AppColors.textSecondary),
          ),
          const SizedBox(height: Insets.md),
          GhostButton(
            'Ask EdgeFuel Coach',
            icon: Icons.chat_bubble_outline,
            expand: true,
            onPressed: () => ai.explainPlan(
              target: target,
              day: edgeFuel.day,
              preferences: edgeFuel.draft,
            ),
          ),
        ],
      );
    }

    switch (result.status) {
      case EdgeFuelAiStatus.quotaReached:
        return Text(
          "You've reached today's AI limit. Try again tomorrow.",
          style: AppType.subhead(color: AppColors.textSecondary),
        );
      case EdgeFuelAiStatus.unavailable:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EdgeFuel Coach is unavailable right now. Your plan above is still '
              'accurate — this only affects the AI explanation.',
              style: AppType.subhead(color: AppColors.textSecondary),
            ),
            const SizedBox(height: Insets.md),
            GhostButton(
              'Try again',
              icon: Icons.refresh,
              expand: true,
              onPressed: () => ai.explainPlan(
                target: target,
                day: edgeFuel.day,
                preferences: edgeFuel.draft,
              ),
            ),
          ],
        );
      case EdgeFuelAiStatus.success:
        final response = result.response!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (response.requiresProfessionalReview)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: Text(
                  'Please speak with a qualified professional before acting on this.',
                  style: AppType.subhead(
                      weight: FontWeight.w700, color: AppColors.warning),
                ),
              ),
            Text(response.summary,
                style: AppType.subhead(weight: FontWeight.w500)),
            for (final warning in response.warnings)
              Padding(
                padding: const EdgeInsets.only(top: Insets.xs),
                child: Text('• $warning',
                    style: AppType.subhead(color: AppColors.textSecondary)),
              ),
            const SizedBox(height: Insets.md),
            GhostButton(
              'Ask again',
              icon: Icons.refresh,
              expand: true,
              onPressed: () => ai.explainPlan(
                target: target,
                day: edgeFuel.day,
                preferences: edgeFuel.draft,
              ),
            ),
          ],
        );
    }
  }
}

class _AiCoachSkeleton extends StatelessWidget {
  const _AiCoachSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double height, {double widthFactor = 1}) =>
        FractionallySizedBox(
          widthFactor: widthFactor,
          alignment: Alignment.centerLeft,
          child: Container(
            height: height,
            margin: const EdgeInsets.only(bottom: Insets.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        block(14),
        block(14, widthFactor: 0.7),
        block(14, widthFactor: 0.85),
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
