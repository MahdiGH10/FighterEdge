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

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

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
              Text('Set up your edge', style: AppType.largeTitle()),
              const SizedBox(height: Insets.sm),
              Text(
                'Fresh account, fresh camp. Answer a few basics and Fighter Edge will start clean around your goals.',
                style: AppType.callout(color: AppColors.textSecondary),
              ),
              const SizedBox(height: Insets.xl),
              AppCard(
                accent: AppColors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Main goal'),
                    _ChoiceWrap(
                      values: _goals,
                      selected: _goal,
                      onSelected: (value) => setState(() => _goal = value),
                    ),
                    const SizedBox(height: Insets.lg),
                    const _FieldLabel('Experience'),
                    _ChoiceWrap(
                      values: _levels,
                      selected: _level,
                      onSelected: (value) => setState(() => _level = value),
                    ),
                    const SizedBox(height: Insets.lg),
                    const _FieldLabel('Training days per week'),
                    _DayStepper(
                      value: _days,
                      onChanged: (value) => setState(() => _days = value),
                    ),
                    const SizedBox(height: Insets.lg),
                    AppTextField(
                      controller: _weight,
                      label: 'Starting weight in kg',
                      icon: Icons.monitor_weight_outlined,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,1}'),
                        ),
                      ],
                      errorText: _error,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.lg),
              _PreviewCard(goal: _goal, level: _level, days: _days),
              const SizedBox(height: Insets.xl),
              PrimaryButton(
                auth.isBusy ? 'Creating your camp...' : 'Start fresh',
                icon: Icons.flag,
                expand: true,
                onPressed: auth.isBusy ? null : _submit,
              ),
              const SizedBox(height: Insets.md),
              Text(
                'You can change units, reminders, and safety preferences later in Settings.',
                textAlign: TextAlign.center,
                style: AppType.micro(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final parsed = double.tryParse(_weight.text.trim());
    if (parsed == null || parsed < 35 || parsed > 180) {
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

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Text(
        label,
        style: AppType.subhead(weight: FontWeight.w800),
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
