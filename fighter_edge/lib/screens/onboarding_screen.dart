import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_text_field.dart';
import '../widgets/brand_logo.dart';
import '../widgets/premium_effects.dart';
import '../widgets/primary_button.dart';
import '../widgets/stat_card.dart';
import '../widgets/press_scale.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _weight = TextEditingController();
  int _step = 0;
  String _goal = 'Build fight-camp structure';
  String _level = 'Beginner';
  int _days = 4;
  String? _error;

  static const _goals = [
    'Build fight-camp structure',
    'Cut weight safely',
    'Improve technique',
    'Get competition ready',
  ];

  static const _levels = ['Beginner', 'Intermediate', 'Advanced', 'Fighter'];
  static const _stepCount = 4;

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final step = _OnboardingStep.fromIndex(
      index: _step,
      goal: _goal,
      level: _level,
      days: _days,
      weight: _weight,
      error: _error,
      goals: _goals,
      levels: _levels,
      onGoal: (value) => setState(() => _goal = value),
      onLevel: (value) => setState(() => _level = value),
      onDays: (value) => setState(() => _days = value),
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
              _PreviewCard(goal: _goal, level: _level, days: _days),
              const SizedBox(height: Insets.xl),
              PrimaryButton(
                auth.isBusy
                    ? 'Creating your camp...'
                    : isLastStep
                        ? 'Start fresh'
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
                onTap: auth.isBusy ? null : () => _submit(skipWeight: true),
                child: Padding(
                  padding: const EdgeInsets.all(Insets.sm),
                  child: Text(
                    isLastStep ? 'Skip weight for now' : 'Skip setup for now',
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
    if (_step < _stepCount - 1) {
      setState(() => _step += 1);
      return;
    }
    _submit();
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step -= 1);
  }

  Future<void> _submit({bool skipWeight = false}) async {
    final weightText = _weight.text.trim();
    final parsed =
        skipWeight || weightText.isEmpty ? null : double.tryParse(weightText);
    if (!skipWeight &&
        weightText.isNotEmpty &&
        (parsed == null || parsed < 35 || parsed > 180)) {
      setState(() {
        _step = _stepCount - 1;
        _error = 'Enter a realistic starting weight, or skip it for now.';
      });
      return;
    }

    if (parsed != null && (parsed < 35 || parsed > 180)) {
      setState(() => _error = 'Enter a realistic starting weight.');
      return;
    }

    setState(() => _error = null);
    final auth = context.read<AuthController>();
    final state = context.read<AppState>();
    try {
      await auth.completeOnboarding(
        goal: _goal,
        experienceLevel: _level,
        weeklyTrainingDays: _days,
        startingWeightKg: parsed,
      );
      await state.startFreshCamp(
        startingWeightKg: parsed,
        weeklyTrainingDays: _days,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not save setup. Try again.');
    }
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
    required String goal,
    required String level,
    required int days,
    required TextEditingController weight,
    required String? error,
    required List<String> goals,
    required List<String> levels,
    required ValueChanged<String> onGoal,
    required ValueChanged<String> onLevel,
    required ValueChanged<int> onDays,
  }) {
    return switch (index) {
      0 => _OnboardingStep(
          eyebrow: 'Fresh account',
          title: 'What are you training for?',
          subtitle:
              'Pick the outcome that should shape your first Fighter Edge camp.',
          child: _ChoiceWrap(
            values: goals,
            selected: goal,
            onSelected: onGoal,
          ),
        ),
      1 => _OnboardingStep(
          eyebrow: 'Experience',
          title: 'Where are you starting from?',
          subtitle:
              'This keeps the app from pushing beginner athletes like pros, or boring experienced fighters.',
          child: _ChoiceWrap(
            values: levels,
            selected: level,
            onSelected: onLevel,
          ),
        ),
      2 => _OnboardingStep(
          eyebrow: 'Weekly rhythm',
          title: 'How many days can you train?',
          subtitle:
              'Choose a realistic week. Consistency beats an impossible plan.',
          child: _DayStepper(value: days, onChanged: onDays),
        ),
      _ => _OnboardingStep(
          eyebrow: 'Optional',
          title: 'Add a starting weight?',
          subtitle:
              'Useful for progress tracking, but you can skip it and add a weigh-in later.',
          child: AppTextField(
            controller: weight,
            label: 'Starting weight in kg',
            icon: Icons.monitor_weight_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d*\.?\d{0,1}'),
              ),
            ],
            errorText: error,
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
                value == 1 ? 'day' : 'days',
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
  const _StepButton(
      {required this.icon, this.onTap, required this.semanticLabel});

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
  final String goal;
  final String level;
  final int days;
  const _PreviewCard({
    required this.goal,
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
              '$days-day $level plan · $goal',
              style: AppType.subhead(weight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
