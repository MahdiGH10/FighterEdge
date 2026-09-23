import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../features/edge_fuel/data/edge_fuel_repository.dart';
import '../../features/edge_fuel/domain/calculators/nutrition_target_calculator.dart';
import '../../features/edge_fuel/domain/models/nutrition_enums.dart';
import '../../features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import '../../features/edge_fuel/domain/models/nutrition_target.dart';
import '../../features/edge_fuel/presentation/screens/edge_fuel_plan_screen.dart';
import '../../features/edge_fuel/presentation/nutrition_copy.dart';
import '../../observability/telemetry.dart';
import '../../routing/app_navigation.dart';
import '../../routing/app_router.dart';
import '../../state/app_state.dart';
import '../../state/first_run_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/premium_effects.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/primary_button.dart';
import '../paywall_screen.dart';

import 'onboarding_steps.dart';
import 'onboarding_widgets.dart';
import 'plan_ready_view.dart';
import 'welcome_pages.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _currentWeight = TextEditingController();
  final _targetWeight = TextEditingController();

  /// The value pages come first, once per visit to setup.
  bool _showWelcome = true;
  int _step = 0;
  String _campGoal = 'Build fight-camp structure';
  NutritionGoal _nutritionGoal = NutritionGoal.maintain;
  String _level = 'Beginner';
  int _days = 4;
  ActivityLevel _activity = ActivityLevel.moderate;
  EquationProfile _equationProfile = EquationProfile.neutral;
  String? _error;
  CompletedOnboardingPlan? _completedPlan;

  static const _campGoals = [
    'Build fight-camp structure',
    'Lose weight safely',
    'Gain muscle',
    'Improve technique',
    'Get competition ready',
  ];

  static const _levels = ['Beginner', 'Intermediate', 'Advanced', 'Fighter'];
  static const _stepCount = 7;

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _currentWeight.dispose();
    _targetWeight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (_showWelcome) {
      return WelcomePages(
        onDone: () {
          setState(() => _showWelcome = false);
          _trackStepViewed();
        },
      );
    }
    final completedPlan = _completedPlan;
    if (completedPlan != null) {
      return PlanReadyView(
        plan: completedPlan,
        isBusy: auth.isBusy,
        onOpenDashboard: _finishOnboarding,
        onViewFuelPlan: () => _finishOnboarding(openFuelPlan: true),
        onViewPro: () => AppNavigation.push(
          context,
          AppRoutes.paywall,
          extra: const PaywallRouteArgs(trigger: PaywallTrigger.planReady),
          fallbackBuilder: (_) => const PaywallScreen(
            trigger: PaywallTrigger.planReady,
          ),
        ),
      );
    }
    final step = OnboardingStepContent.fromIndex(
      index: _step,
      campGoal: _campGoal,
      nutritionGoal: _nutritionGoal,
      level: _level,
      days: _days,
      activity: _activity,
      equationProfile: _equationProfile,
      age: _age,
      height: _height,
      currentWeight: _currentWeight,
      targetWeight: _targetWeight,
      error: _error,
      campGoals: _campGoals,
      levels: _levels,
      onCampGoal: (value) => setState(() {
        _campGoal = value;
        _syncNutritionGoalFromCampGoal(value);
      }),
      onNutritionGoal: (value) => setState(() {
        _nutritionGoal = value;
        _error = null;
      }),
      onLevel: (value) => setState(() => _level = value),
      onDays: (value) => setState(() => _days = value),
      onActivity: (value) => setState(() => _activity = value),
      onEquationProfile: (value) => setState(() => _equationProfile = value),
    );
    final isLastStep = _step == _stepCount - 1;

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
              const SizedBox(height: Insets.xl),
              OnboardingProgressHeader(step: _step, stepCount: _stepCount),
              const SizedBox(height: Insets.xxl),
              AnimatedSwitcher(
                duration: MotionTokens.standard,
                switchInCurve: MotionTokens.settle,
                switchOutCurve: MotionTokens.snap,
                child: QuestionStep(
                  key: ValueKey(_step),
                  eyebrow: step.eyebrow,
                  title: step.title,
                  subtitle: step.subtitle,
                  child: step.child,
                ),
              ),
              const SizedBox(height: Insets.xl),
              PlanPreviewCard(
                campGoal: _campGoal,
                nutritionGoal: _nutritionGoal,
                level: _level,
                days: _days,
              ),
              const SizedBox(height: Insets.xl),
              PrimaryButton(
                auth.isBusy
                    ? 'Creating your plan...'
                    : isLastStep
                        ? 'Start my plan'
                        : 'Continue',
                icon: isLastStep ? Icons.flag : Icons.arrow_forward,
                expand: true,
                onPressed: auth.isBusy ? null : _continue,
              ),
              if (_step > 0) ...[
                const SizedBox(height: Insets.sm),
                GhostButton(
                  'Back',
                  expand: true,
                  onPressed: auth.isBusy ? null : _back,
                ),
              ],
              const SizedBox(height: Insets.md),
              PressScale(
                onTap: auth.isBusy ? null : _skipDetailedNutrition,
                child: Padding(
                  padding: const EdgeInsets.all(Insets.sm),
                  child: Text(
                    'Skip detailed target for now',
                    textAlign: TextAlign.center,
                    style: AppType.subhead(
                      weight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _continue() {
    if (!_validateCurrentStep()) return;
    if (_step < _stepCount - 1) {
      setState(() {
        _step += 1;
        _error = null;
      });
      _trackStepViewed();
      return;
    }
    _submit(createNutritionTarget: true);
  }

  void _back() {
    if (_step == 0) return;
    setState(() {
      _step -= 1;
      _error = null;
    });
    _trackStepViewed();
  }

  Telemetry get _telemetry => Telemetry.fromContext(context);

  /// Steps are reported 1-based, as the athlete sees them ("Step 3 of 7").
  void _trackStepViewed() => _telemetry.track(
        TelemetryEvent.onboardingStepViewed,
        parameters: {'step': _step + 1},
      );

  /// Takes the [Telemetry] captured before `completeOnboarding`: completing
  /// replaces this screen with the app, so its context is gone by then.
  static void _trackCompleted(Telemetry telemetry,
          {required String goal, required int days, required bool detailed}) =>
      telemetry.track(
        TelemetryEvent.onboardingCompleted,
        parameters: {
          'goal': _goalCode(goal),
          'days_per_week': days,
          'detailed': detailed ? 1 : 0,
        },
      );

  /// A fixed short code per camp goal, so analytics never carries the label
  /// text (and would not break if the label is reworded or translated).
  static String _goalCode(String goal) => switch (goal) {
        'Build fight-camp structure' => 'camp_structure',
        'Lose weight safely' => 'lose_weight',
        'Gain muscle' => 'gain_muscle',
        'Improve technique' => 'technique',
        'Get competition ready' => 'competition',
        _ => 'other',
      };

  void _syncNutritionGoalFromCampGoal(String value) {
    if (value == 'Lose weight safely') {
      _nutritionGoal = NutritionGoal.loseFat;
    } else if (value == 'Gain muscle') {
      _nutritionGoal = NutritionGoal.gainMuscle;
    }
    _error = null;
  }

  Future<void> _skipDetailedNutrition() async {
    await _submit(createNutritionTarget: false);
  }

  Future<void> _submit({required bool createNutritionTarget}) async {
    if (createNutritionTarget && !_validateAll()) return;

    setState(() => _error = null);
    final auth = context.read<AuthController>();
    final state = context.read<AppState>();
    final firstRun = context.read<FirstRunController>();
    final telemetry = _telemetry;
    final userId = auth.user?.id;
    final currentWeight = createNutritionTarget
        ? _parseDouble(_currentWeight.text)
        : _optionalStartingWeight();

    try {
      NutritionTarget? nutritionTarget;
      if (createNutritionTarget && userId != null) {
        nutritionTarget = await _saveInitialEdgeFuelPlan(userId);
        if (nutritionTarget == null) return;
      }

      await state.startFreshCamp(
        startingWeightKg: currentWeight,
        weeklyTrainingDays: _days,
      );

      if (createNutritionTarget) {
        if (!mounted) return;
        setState(() {
          _completedPlan = CompletedOnboardingPlan(
            target: nutritionTarget,
            nutritionGoal: _nutritionGoal,
            campGoal: _campGoal,
            level: _level,
            days: _days,
          );
        });
        telemetry.track(TelemetryEvent.planRevealed);
        return;
      }

      await firstRun.begin();
      await auth.completeOnboarding(
        goal: _campGoal,
        experienceLevel: _level,
        weeklyTrainingDays: _days,
        startingWeightKg: currentWeight,
      );
      _trackCompleted(telemetry, goal: _campGoal, days: _days, detailed: false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not save setup. Try again.');
    }
  }

  Future<NutritionTarget?> _saveInitialEdgeFuelPlan(String userId) async {
    final profileDraft = _buildConfirmedNutritionDraft();
    final profile = profileDraft.toProfile();
    if (profile == null) {
      setState(() => _error = 'Complete your body details first.');
      return null;
    }

    final target = NutritionTargetCalculator.calculate(
      profile,
      now: DateTime.now(),
    );
    if (!target.isSuccess) {
      final reason = target.reasons.isEmpty
          ? 'These details need review before we create a target.'
          : NutritionCopy.reason(target.reasons.first);
      setState(() => _error = reason);
      return null;
    }

    final repo = context.read<EdgeFuelRepository>();
    await repo.saveProfileDraft(userId, profileDraft);
    await repo.saveTarget(userId, target);
    return target;
  }

  Future<void> _finishOnboarding({bool openFuelPlan = false}) async {
    final plan = _completedPlan;
    if (plan == null) return;

    final auth = context.read<AuthController>();
    final firstRun = context.read<FirstRunController>();
    final telemetry = _telemetry;
    final currentWeight = _parseDouble(_currentWeight.text);

    try {
      // Before completing: completing swaps this screen for the app, and the
      // first-week layer must already be on when the dashboard first builds.
      await firstRun.begin();
      await auth.completeOnboarding(
        goal: plan.campGoal,
        experienceLevel: plan.level,
        weeklyTrainingDays: plan.days,
        startingWeightKg: currentWeight,
      );
      _trackCompleted(telemetry,
          goal: plan.campGoal, days: plan.days, detailed: true);
      if (!openFuelPlan || !mounted) return;
      AppNavigation.replace(
        context,
        AppRoutes.fuelPlan,
        fallbackBuilder: (_) => const EdgeFuelPlanScreen(),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not open your plan. Try again.');
    }
  }

  NutritionSetupDraft _buildConfirmedNutritionDraft() {
    final currentWeight = _parseDouble(_currentWeight.text)!;
    final explicitTarget = _parseDouble(_targetWeight.text);
    final targetWeight = _nutritionGoal == NutritionGoal.maintain
        ? null
        : explicitTarget ?? _defaultTargetWeight(currentWeight);
    final goalPace = switch (_nutritionGoal) {
      NutritionGoal.loseFat => GoalPace.standard,
      NutritionGoal.gainMuscle => GoalPace.gainStandard,
      NutritionGoal.maintain => null,
    };

    return NutritionSetupDraft(
      currentStep: 5,
      confirmed: true,
      goal: _nutritionGoal,
      ageYears: int.parse(_age.text.trim()),
      heightCm: _parseDouble(_height.text)!,
      currentWeightKg: currentWeight,
      targetWeightKg: targetWeight,
      equationProfile: _equationProfile,
      normalActivityLevel: _activity,
      weeklyTrainingDays: _days,
      goalPace: goalPace,
      mealsPerDay: 3,
    );
  }

  bool _validateCurrentStep() {
    final error = switch (_step) {
      2 => _bodyError(),
      _ => null,
    };
    if (error == null) return true;
    setState(() => _error = error);
    return false;
  }

  bool _validateAll() {
    final bodyError = _bodyError();
    if (bodyError == null) return true;
    setState(() {
      _step = 2;
      _error = bodyError;
    });
    _trackStepViewed();
    return false;
  }

  String? _bodyError() {
    final age = int.tryParse(_age.text.trim());
    final height = _parseDouble(_height.text);
    final currentWeight = _parseDouble(_currentWeight.text);
    final targetWeight = _parseDouble(_targetWeight.text);

    if (age == null || age < 18 || age > 90) {
      return 'Enter an age from 18 to 90 for automated targets.';
    }
    if (height == null || height < 120 || height > 230) {
      return 'Enter height in cm, for example 178.';
    }
    if (currentWeight == null || currentWeight < 35 || currentWeight > 220) {
      return 'Enter current weight in kg, for example 78.';
    }
    if (_targetWeight.text.trim().isEmpty) return null;
    if (targetWeight == null || targetWeight < 35 || targetWeight > 220) {
      return 'Target weight should be a realistic kg value.';
    }
    if (_nutritionGoal == NutritionGoal.loseFat &&
        targetWeight >= currentWeight) {
      return 'For weight loss, target weight should be below current weight.';
    }
    if (_nutritionGoal == NutritionGoal.gainMuscle &&
        targetWeight <= currentWeight) {
      return 'For weight gain, target weight should be above current weight.';
    }
    return null;
  }

  double? _parseDouble(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  double? _optionalStartingWeight() {
    final weight = _parseDouble(_currentWeight.text);
    if (weight == null || weight < 35 || weight > 220) return null;
    return weight;
  }

  double _defaultTargetWeight(double currentWeight) {
    final multiplier = _nutritionGoal == NutritionGoal.loseFat ? 0.95 : 1.05;
    return double.parse((currentWeight * multiplier).toStringAsFixed(1));
  }
}
