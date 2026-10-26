import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_icons.dart';

import '../../../../controllers/auth_controller.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../../routing/app_navigation.dart';
import '../../../../routing/app_router.dart';
import '../../../../state/app_state.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/skeleton.dart';
import '../../../../widgets/app_scaffold.dart';
import '../../../../widgets/primary_button.dart';
import '../../data/edge_fuel_repository.dart';
import '../../domain/models/nutrition_enums.dart';
import '../controllers/edge_fuel_setup_controller.dart';
import '../controllers/nutrition_mode_controller.dart';
import '../widgets/nutrition_paused_view.dart';
import 'edge_fuel_plan_screen.dart';
import 'setup_steps/activity_step.dart';
import 'setup_steps/body_step.dart';
import 'setup_steps/food_step.dart';
import 'setup_steps/goal_step.dart';
import 'setup_steps/review_step.dart';
import 'setup_steps/training_step.dart';

/// The resumable, autosaved six-step EdgeFuel setup wizard (master prompt
/// §6). Owns its own [EdgeFuelSetupController] scoped to the signed-in user
/// so the controller's lifecycle matches the screen's, not the app's.
class EdgeFuelSetupScreen extends StatelessWidget {
  const EdgeFuelSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (!context.watch<NutritionModeController>().numbersVisible) {
      return NutritionPausedScreen(title: l.fuelSetupTitle);
    }
    final userId = context.read<AuthController>().user?.id;
    if (userId == null) {
      return ScreenScaffold(
        title: l.fuelSetupTitle,
        showBack: true,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.xl),
            child: Text(l.fuelSetupSignIn),
          ),
        ),
      );
    }
    return ChangeNotifierProvider(
      create: (ctx) => EdgeFuelSetupController(
        repository: ctx.read<EdgeFuelRepository>(),
        userId: userId,
      ),
      child: const _EdgeFuelSetupBody(),
    );
  }
}

class _EdgeFuelSetupBody extends StatefulWidget {
  const _EdgeFuelSetupBody();

  @override
  State<_EdgeFuelSetupBody> createState() => _EdgeFuelSetupBodyState();
}

class _EdgeFuelSetupBodyState extends State<_EdgeFuelSetupBody> {
  static const _stepCount = 6;
  int? _step;
  int _lastPreviewedStep = -1;
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final controller = context.watch<EdgeFuelSetupController>();
    final stepTitles = [
      l.fuelStepGoal,
      l.fuelStepBody,
      l.fuelStepActivity,
      l.fuelStepTraining,
      l.fuelStepFood,
      l.fuelStepReview,
    ];

    if (controller.isLoading) {
      return ScreenScaffold(
        title: l.fuelSetupTitle,
        showBack: true,
        body: const _SetupSkeleton(),
      );
    }

    _step ??= controller.draft.currentStep.clamp(0, _stepCount - 1);
    final step = _step!;

    if (step == _stepCount - 1 && _lastPreviewedStep != step) {
      _lastPreviewedStep = step;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.refreshPreview();
      });
    } else if (step != _stepCount - 1) {
      _lastPreviewedStep = -1;
    }

    final prefillWeight = context.read<AppState>().latestWeight;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(title: l.fuelSetupTitle, showBack: true),
            _StepProgress(step: step, titles: stepTitles),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
                child: IndexedStack(
                  index: step,
                  children: [
                    GoalStep(controller: controller),
                    BodyStep(
                      controller: controller,
                      prefillWeightKg: prefillWeight > 0 ? prefillWeight : null,
                    ),
                    ActivityStep(controller: controller),
                    TrainingStep(controller: controller),
                    FoodStep(controller: controller),
                    ReviewStep(controller: controller, onConfirmed: _confirm),
                  ],
                ),
              ),
            ),
            if (step < _stepCount - 1)
              _NavBar(
                step: step,
                canAdvance: _canAdvance(controller, step),
                onBack: step == 0 ? null : () => _goTo(step - 1, controller),
                onNext: () => _goTo(step + 1, controller),
              ),
          ],
        ),
      ),
    );
  }

  bool _canAdvance(EdgeFuelSetupController controller, int step) {
    final draft = controller.draft;
    switch (step) {
      case 0:
        return draft.goal != null;
      case 1:
        final needsTarget =
            draft.goal != null && draft.goal != NutritionGoal.maintain;
        return draft.ageYears != null &&
            draft.heightCm != null &&
            draft.currentWeightKg != null &&
            draft.equationProfile != null &&
            draft.screeningStatus != NutritionScreeningStatus.unanswered &&
            (!needsTarget || draft.targetWeightKg != null);
      case 2:
        return draft.normalActivityLevel != null;
      case 3:
        final needsPace =
            draft.goal != null && draft.goal != NutritionGoal.maintain;
        return draft.weeklyTrainingDays != null &&
            (!needsPace || draft.goalPace != null);
      case 4:
        return true;
      default:
        return true;
    }
  }

  void _goTo(int step, EdgeFuelSetupController controller) {
    setState(() => _step = step);
    controller.goToStep(step);
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    _confirming = true;
    final controller = context.read<EdgeFuelSetupController>();
    try {
      final ok = await controller.confirm();
      if (!mounted || !ok) return;
      AppNavigation.replace(
        context,
        AppRoutes.fuelPlan,
        fallbackBuilder: (_) => const EdgeFuelPlanScreen(),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.of(context).fuelSetupSaveError),
        ));
      }
    } finally {
      _confirming = false;
    }
  }
}

class _StepProgress extends StatelessWidget {
  final int step;
  final List<String> titles;
  const _StepProgress({required this.step, required this.titles});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.lg, Insets.none, Insets.lg, Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < titles.length; i++) ...[
                if (i > 0) const SizedBox(width: Insets.xs),
                Expanded(
                  child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : MotionTokens.standard,
                    curve: MotionTokens.settle,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= step ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(Radii.chip),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            L
                .of(context)
                .fuelStepProgress(step + 1, titles.length, titles[step]),
            style: AppType.subhead(
                weight: FontWeight.w700, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int step;
  final bool canAdvance;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  const _NavBar({
    required this.step,
    required this.canAdvance,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.lg, Insets.none, Insets.lg, Insets.lg),
      child: Row(
        children: [
          if (onBack != null) ...[
            GhostButton(L.of(context).onboardingBack,
                icon: AppIcons.caretLeft, onPressed: onBack),
            const SizedBox(width: Insets.md),
          ],
          Expanded(
            child: PrimaryButton(
              L.of(context).fuelSetupNext,
              icon: AppIcons.caretRight,
              expand: true,
              onPressed: canAdvance ? onNext : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stands in for a setup step while the saved draft loads: progress, a
/// question, and a column of choices.
class _SetupSkeleton extends StatelessWidget {
  const _SetupSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Skeleton(
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.lg, Insets.none),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox.line(width: 120),
            SizedBox(height: Insets.sm),
            SkeletonBox(height: Insets.xs + Insets.xxs, radius: Radii.chip),
            SizedBox(height: Insets.xxl),
            SkeletonBox(width: 240, height: Insets.xxl),
            SizedBox(height: Insets.md),
            SkeletonBox.line(),
            SizedBox(height: Insets.xl),
            SkeletonBox(height: 72, radius: Radii.card),
            SizedBox(height: Insets.sm),
            SkeletonBox(height: 72, radius: Radii.card),
            SizedBox(height: Insets.sm),
            SkeletonBox(height: 72, radius: Radii.card),
          ],
        ),
      ),
    );
  }
}
