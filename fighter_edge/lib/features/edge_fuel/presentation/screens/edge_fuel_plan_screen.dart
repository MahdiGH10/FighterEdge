import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_icons.dart';

import '../../../../controllers/auth_controller.dart';
import '../../../../routing/app_navigation.dart';
import '../../../../routing/app_router.dart';
import '../../../../theme/app_accessibility.dart';
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
import '../controllers/nutrition_mode_controller.dart';
import '../widgets/nutrition_paused_view.dart';
import '../nutrition_copy.dart';
import '../widgets/fuel_what_is_left.dart';
import 'edge_fuel_setup_screen.dart';

/// Read-only view of the confirmed deterministic EdgeFuel target.
///
/// The plan stays the source of truth for targets.
class EdgeFuelPlanScreen extends StatelessWidget {
  const EdgeFuelPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!context.watch<NutritionModeController>().numbersVisible) {
      return const NutritionPausedScreen(title: 'Your plan');
    }
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
    final chips = [
      _MacroChip('Protein', protein, AppColors.protein),
      _MacroChip('Carbs', carbs, AppColors.carbs),
      _MacroChip('Fats', fats, AppColors.fats),
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
    );
  }
}
