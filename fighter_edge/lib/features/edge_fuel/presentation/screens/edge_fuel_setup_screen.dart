import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../controllers/auth_controller.dart';
import '../../../../state/app_state.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_scaffold.dart';
import '../../../../widgets/primary_button.dart';
import '../../data/edge_fuel_repository.dart';
import '../../domain/models/nutrition_enums.dart';
import '../controllers/edge_fuel_setup_controller.dart';
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
    final userId = context.read<AuthController>().user?.id;
    if (userId == null) {
      return const ScreenScaffold(
        title: 'Fuel setup',
        showBack: true,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(Insets.xl),
            child: Text('Sign in to set up EdgeFuel.'),
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
  static const _stepTitles = [
    'Goal',
    'Body',
    'Activity',
    'Training',
    'Food',
    'Review',
  ];

  int? _step;
  int _lastPreviewedStep = -1;
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EdgeFuelSetupController>();

    if (controller.isLoading) {
      return const ScreenScaffold(
        title: 'Fuel setup',
        showBack: true,
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
            const AppHeader(title: 'Fuel setup', showBack: true),
            _StepProgress(step: step, titles: _stepTitles),
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
    final ok = await controller.confirm();
    _confirming = false;
    if (!mounted || !ok) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const EdgeFuelPlanScreen()),
    );
  }
}

class _StepProgress extends StatelessWidget {
  final int step;
  final List<String> titles;
  const _StepProgress({required this.step, required this.titles});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < titles.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: AnimatedContainer(
                    duration: MotionTokens.standard,
                    curve: MotionTokens.emphasized,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= step ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Step ${step + 1} of ${titles.length} · ${titles[step]}',
            style: AppTheme.body(12,
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
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.lg),
      child: Row(
        children: [
          if (onBack != null) ...[
            GhostButton('Back', icon: Icons.chevron_left, onPressed: onBack),
            const SizedBox(width: Insets.md),
          ],
          Expanded(
            child: PrimaryButton(
              'Next',
              icon: Icons.chevron_right,
              expand: true,
              onPressed: canAdvance ? onNext : null,
            ),
          ),
        ],
      ),
    );
  }
}
