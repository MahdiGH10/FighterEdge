import 'package:flutter/material.dart';

import '../../features/edge_fuel/domain/models/nutrition_enums.dart';
import '../../features/edge_fuel/presentation/nutrition_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/stat_card.dart';

class OnboardingProgressHeader extends StatelessWidget {
  final int step;
  final int stepCount;
  const OnboardingProgressHeader(
      {super.key, required this.step, required this.stepCount});

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

class QuestionStep extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;

  const QuestionStep({
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

class ChoiceWrap extends StatelessWidget {
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  const ChoiceWrap({
    super.key,
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

class SelectCard<T> extends StatelessWidget {
  final T value;
  final T selected;
  final String title;
  final String description;
  final IconData icon;
  final ValueChanged<T> onSelected;

  const SelectCard({
    super.key,
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

class DayStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const DayStepper({super.key, required this.value, required this.onChanged});

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

class PlanPreviewCard extends StatelessWidget {
  final String campGoal;
  final NutritionGoal nutritionGoal;
  final String level;
  final int days;

  const PlanPreviewCard({
    super.key,
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
