import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../features/edge_fuel/data/edge_fuel_repository.dart';
import '../features/edge_fuel/domain/calculators/nutrition_target_calculator.dart';
import '../features/edge_fuel/domain/models/nutrition_enums.dart';
import '../features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import '../features/edge_fuel/domain/models/nutrition_target.dart';
import '../features/edge_fuel/presentation/screens/edge_fuel_plan_screen.dart';
import '../features/edge_fuel/presentation/nutrition_copy.dart';
import '../routing/app_navigation.dart';
import '../routing/app_router.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_text_field.dart';
import '../widgets/brand_logo.dart';
import '../widgets/premium_effects.dart';
import '../widgets/press_scale.dart';
import '../widgets/primary_button.dart';
import '../widgets/stat_card.dart';

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

  int _step = 0;
  String _campGoal = 'Build fight-camp structure';
  NutritionGoal _nutritionGoal = NutritionGoal.maintain;
  String _level = 'Beginner';
  int _days = 4;
  ActivityLevel _activity = ActivityLevel.moderate;
  EquationProfile _equationProfile = EquationProfile.neutral;
  String? _error;
  _CompletedOnboardingPlan? _completedPlan;

  static const _campGoals = [
    'Build fight-camp structure',
    'Lose weight safely',
    'Gain muscle',
    'Improve technique',
    'Get competition ready',
  ];

  static const _levels = ['Beginner', 'Intermediate', 'Advanced', 'Fighter'];
  static const _stepCount = 6;

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
    final completedPlan = _completedPlan;
    if (completedPlan != null) {
      return _PlanReadyView(
        plan: completedPlan,
        isBusy: auth.isBusy,
        onOpenDashboard: _finishOnboarding,
        onViewFuelPlan: () => _finishOnboarding(openFuelPlan: true),
      );
    }
    final step = _OnboardingStep.fromIndex(
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
              _ProgressHeader(step: _step, stepCount: _stepCount),
              const SizedBox(height: Insets.xxl),
              AnimatedSwitcher(
                duration: MotionTokens.standard,
                switchInCurve: MotionTokens.settle,
                switchOutCurve: MotionTokens.snap,
                child: _QuestionStep(
                  key: ValueKey(_step),
                  eyebrow: step.eyebrow,
                  title: step.title,
                  subtitle: step.subtitle,
                  child: step.child,
                ),
              ),
              const SizedBox(height: Insets.xl),
              _PreviewCard(
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
  }

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
          _completedPlan = _CompletedOnboardingPlan(
            target: nutritionTarget,
            nutritionGoal: _nutritionGoal,
            campGoal: _campGoal,
            level: _level,
            days: _days,
          );
        });
        return;
      }

      await auth.completeOnboarding(
        goal: _campGoal,
        experienceLevel: _level,
        weeklyTrainingDays: _days,
        startingWeightKg: currentWeight,
      );
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
    final currentWeight = _parseDouble(_currentWeight.text);

    try {
      await auth.completeOnboarding(
        goal: plan.campGoal,
        experienceLevel: plan.level,
        weeklyTrainingDays: plan.days,
        startingWeightKg: currentWeight,
      );
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

class _CompletedOnboardingPlan {
  final NutritionTarget? target;
  final NutritionGoal nutritionGoal;
  final String campGoal;
  final String level;
  final int days;

  const _CompletedOnboardingPlan({
    required this.target,
    required this.nutritionGoal,
    required this.campGoal,
    required this.level,
    required this.days,
  });
}

class _PlanReadyView extends StatelessWidget {
  final _CompletedOnboardingPlan plan;
  final bool isBusy;
  final VoidCallback onOpenDashboard;
  final VoidCallback onViewFuelPlan;

  const _PlanReadyView({
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
                        value: '${target!.targetCalories} kcal',
                        icon: Icons.bolt,
                      ),
                      const SizedBox(height: Insets.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _PlanMetric(
                              label: 'Protein',
                              value: '${target.proteinGrams}g',
                              icon: Icons.fitness_center,
                            ),
                          ),
                          const SizedBox(width: Insets.sm),
                          Expanded(
                            child: _PlanMetric(
                              label: 'Carbs',
                              value: '${target.carbGrams}g',
                              icon: Icons.flash_on,
                            ),
                          ),
                          const SizedBox(width: Insets.sm),
                          Expanded(
                            child: _PlanMetric(
                              label: 'Fats',
                              value: '${target.fatGrams}g',
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
  final String value;
  final IconData icon;

  const _PlanMetric({
    required this.label,
    required this.value,
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
          Text(value,
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

class _OnboardingStep {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;

  const _OnboardingStep({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  factory _OnboardingStep.fromIndex({
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
      0 => _OnboardingStep(
          eyebrow: 'Fresh account',
          title: 'What should Fighter Edge build first?',
          subtitle:
              'Pick the outcome that should shape your first training camp.',
          child: _ChoiceWrap(
            values: campGoals,
            selected: campGoal,
            onSelected: onCampGoal,
          ),
        ),
      1 => _OnboardingStep(
          eyebrow: 'Nutrition goal',
          title: 'What should EdgeFuel optimize for?',
          subtitle:
              'This creates your first calorie and macro target. You can edit it later.',
          child: Column(
            children: [
              for (final goal in NutritionGoal.values)
                _SelectCard<NutritionGoal>(
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
      2 => _OnboardingStep(
          eyebrow: 'Body basics',
          title: 'Tell us your starting point.',
          subtitle:
              'No weight class needed. Use normal body details so your target is personal.',
          child: _BodyInputs(
            age: age,
            height: height,
            currentWeight: currentWeight,
            targetWeight: targetWeight,
            nutritionGoal: nutritionGoal,
            equationProfile: equationProfile,
            onEquationProfile: onEquationProfile,
            error: error,
          ),
        ),
      3 => _OnboardingStep(
          eyebrow: 'Daily activity',
          title: 'Outside the gym, how active are you?',
          subtitle:
              'This is separate from training days so calories are not double-counted.',
          child: Column(
            children: [
              for (final level in ActivityLevel.values)
                _SelectCard<ActivityLevel>(
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
      4 => _OnboardingStep(
          eyebrow: 'Training rhythm',
          title: 'How many days can you train?',
          subtitle:
              'Choose a realistic week. Consistency beats an impossible plan.',
          child: Column(
            children: [
              _ChoiceWrap(
                values: levels,
                selected: level,
                onSelected: onLevel,
              ),
              const SizedBox(height: Insets.xl),
              _DayStepper(value: days, onChanged: onDays),
            ],
          ),
        ),
      _ => _OnboardingStep(
          eyebrow: 'Review',
          title: 'Your first plan is ready.',
          subtitle:
              'Fighter Edge will start you fresh: clean dashboard, training week, and an EdgeFuel target.',
          child: _ReviewSummary(
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

class _ProgressHeader extends StatelessWidget {
  final int step;
  final int stepCount;
  const _ProgressHeader({required this.step, required this.stepCount});

  @override
  Widget build(BuildContext context) {
    final current = step + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step $current of $stepCount',
          style: AppType.micro(color: AppColors.textMuted),
        ),
        const SizedBox(height: Insets.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.chip),
          child: LinearProgressIndicator(
            value: current / stepCount,
            minHeight: 6,
            backgroundColor: AppColors.surfaceElevated,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _QuestionStep extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;

  const _QuestionStep({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: AppType.micro(
              weight: FontWeight.w800,
              color: AppColors.primary,
              spacing: 1,
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(title, style: AppType.title1()),
          const SizedBox(height: Insets.sm),
          Text(subtitle,
              style: AppType.callout(color: AppColors.textSecondary)),
          const SizedBox(height: Insets.xl),
          child,
        ],
      ),
    );
  }
}

class _BodyInputs extends StatelessWidget {
  final TextEditingController age;
  final TextEditingController height;
  final TextEditingController currentWeight;
  final TextEditingController targetWeight;
  final NutritionGoal nutritionGoal;
  final EquationProfile equationProfile;
  final ValueChanged<EquationProfile> onEquationProfile;
  final String? error;

  const _BodyInputs({
    required this.age,
    required this.height,
    required this.currentWeight,
    required this.targetWeight,
    required this.nutritionGoal,
    required this.equationProfile,
    required this.onEquationProfile,
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
        const SizedBox(height: Insets.xl),
        Text('Calorie equation',
            style: AppType.callout(weight: FontWeight.w800)),
        const SizedBox(height: Insets.sm),
        for (final profile in EquationProfile.values)
          _SelectCard<EquationProfile>(
            value: profile,
            selected: equationProfile,
            title: NutritionCopy.equationLabel(profile),
            description: NutritionCopy.equationDescription(profile),
            icon: Icons.calculate_outlined,
            onSelected: onEquationProfile,
          ),
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

class _ChoiceWrap extends StatelessWidget {
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  const _ChoiceWrap({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(value),
            selected: value == selected,
            onSelected: (_) => onSelected(value),
            selectedColor: AppColors.primarySoft,
            backgroundColor: AppColors.backgroundRaised,
            side: BorderSide(
              color: value == selected ? AppColors.primary : AppColors.border,
            ),
            labelStyle: AppType.subhead(
              weight: FontWeight.w800,
              color: value == selected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
            showCheckmark: false,
          ),
      ],
    );
  }
}

class _SelectCard<T> extends StatelessWidget {
  final T value;
  final T selected;
  final String title;
  final String description;
  final IconData icon;
  final ValueChanged<T> onSelected;

  const _SelectCard({
    required this.value,
    required this.selected,
    required this.title,
    required this.description,
    required this.icon,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: AppCard(
        onTap: () => onSelected(value),
        padding: const EdgeInsets.all(Insets.md),
        accent: active ? AppColors.primary : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: active ? AppColors.primarySoft : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Icon(
                icon,
                color: active ? AppColors.primary : AppColors.textMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.callout(weight: FontWeight.w800)),
                  const SizedBox(height: Insets.xxs),
                  Text(
                    description,
                    style: AppType.subhead(
                      weight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            Icon(
              active ? Icons.check_circle : Icons.circle_outlined,
              color: active ? AppColors.primary : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _DayStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepButton(
          icon: Icons.remove,
          semanticLabel: 'Fewer days',
          onTap: value <= 2 ? null : () => onChanged(value - 1),
        ),
        Expanded(
          child: Column(
            children: [
              Text('$value', style: AppType.largeTitle()),
              Text(
                value == 1 ? 'day per week' : 'days per week',
                style: AppType.micro(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        _StepButton(
          icon: Icons.add,
          semanticLabel: 'More days',
          onTap: value >= 6 ? null : () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String semanticLabel;
  const _StepButton({
    required this.icon,
    this.onTap,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: PressScale(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox.square(
            dimension: 44,
            child: Icon(
              icon,
              color: enabled ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String campGoal;
  final NutritionGoal nutritionGoal;
  final String level;
  final int days;

  const _PreviewCard({
    required this.campGoal,
    required this.nutritionGoal,
    required this.level,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_graph, color: AppColors.primary),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              '$days-day $level camp - ${NutritionCopy.goalLabel(nutritionGoal)} - $campGoal',
              style: AppType.subhead(weight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  final String campGoal;
  final NutritionGoal nutritionGoal;
  final String level;
  final int days;
  final ActivityLevel activity;

  const _ReviewSummary({
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
