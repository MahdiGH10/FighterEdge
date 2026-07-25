import 'package:flutter/material.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/app_text_field.dart';
import '../../controllers/edge_fuel_setup_controller.dart';

/// Step 5 of 6 — food preferences (master prompt §6.5). Nothing here is
/// consumed by the deterministic engine or by EF-1 — it's captured now so
/// the recipe system (a later sprint) doesn't need a second onboarding pass.
class FoodStep extends StatefulWidget {
  final EdgeFuelSetupController controller;
  const FoodStep({super.key, required this.controller});

  @override
  State<FoodStep> createState() => _FoodStepState();
}

class _FoodStepState extends State<FoodStep> {
  static const _diets = [
    'omnivore',
    'vegetarian',
    'vegan',
    'pescatarian',
    'halal',
  ];
  static const _budgets = ['low', 'medium', 'high'];
  static const _cookingTimes = ['quick', 'moderate', 'extended'];

  late final TextEditingController _allergens;
  late final TextEditingController _dislikes;

  @override
  void initState() {
    super.initState();
    final draft = widget.controller.draft;
    _allergens = TextEditingController(text: draft.allergens.join(', '));
    _dislikes = TextEditingController(text: draft.dislikedFoods.join(', '));
  }

  @override
  void dispose() {
    _allergens.dispose();
    _dislikes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final draft = controller.draft;
    final mealsPerDay = draft.mealsPerDay ?? 3;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Insets.lg),
      children: [
        Text('Food preferences', style: AppTheme.display(22)),
        const SizedBox(height: Insets.sm),
        Text(
          "Optional now — shapes meal suggestions once recipes launch.",
          style: AppTheme.body(13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: Insets.xl),
        Text('Diet type', style: AppTheme.body(13, weight: FontWeight.w800)),
        const SizedBox(height: Insets.sm),
        _ChipRow(
          options: _diets,
          selected: draft.dietType,
          onSelected: (v) => controller.setFoodPreferences(dietType: v),
        ),
        const SizedBox(height: Insets.lg),
        AppTextField(
          controller: _allergens,
          label: 'Allergens (comma-separated)',
          icon: Icons.warning_amber_outlined,
          onChanged: (_) => _commitList(_allergens, (list) =>
              controller.setFoodPreferences(allergens: list)),
        ),
        const SizedBox(height: Insets.md),
        AppTextField(
          controller: _dislikes,
          label: 'Disliked foods (comma-separated)',
          icon: Icons.thumb_down_outlined,
          onChanged: (_) => _commitList(_dislikes, (list) =>
              controller.setFoodPreferences(dislikedFoods: list)),
        ),
        const SizedBox(height: Insets.lg),
        Text('Meals per day', style: AppTheme.body(13, weight: FontWeight.w800)),
        const SizedBox(height: Insets.sm),
        Row(
          children: [
            _StepButton(
              icon: Icons.remove,
              onTap: mealsPerDay <= 2
                  ? null
                  : () =>
                      controller.setFoodPreferences(mealsPerDay: mealsPerDay - 1),
            ),
            SizedBox(
              width: 56,
              child: Text('$mealsPerDay',
                  textAlign: TextAlign.center, style: AppTheme.display(22)),
            ),
            _StepButton(
              icon: Icons.add,
              onTap: mealsPerDay >= 6
                  ? null
                  : () =>
                      controller.setFoodPreferences(mealsPerDay: mealsPerDay + 1),
            ),
          ],
        ),
        const SizedBox(height: Insets.lg),
        Text('Budget', style: AppTheme.body(13, weight: FontWeight.w800)),
        const SizedBox(height: Insets.sm),
        _ChipRow(
          options: _budgets,
          selected: draft.budgetBand,
          onSelected: (v) => controller.setFoodPreferences(budgetBand: v),
        ),
        const SizedBox(height: Insets.lg),
        Text('Cooking time available',
            style: AppTheme.body(13, weight: FontWeight.w800)),
        const SizedBox(height: Insets.sm),
        _ChipRow(
          options: _cookingTimes,
          selected: draft.cookingTimeBand,
          onSelected: (v) => controller.setFoodPreferences(cookingTimeBand: v),
        ),
      ],
    );
  }

  void _commitList(
    TextEditingController controller,
    void Function(List<String>) apply,
  ) {
    final list = controller.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    apply(list);
  }
}

class _ChipRow extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;
  const _ChipRow(
      {required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: [
        for (final value in options)
          ChoiceChip(
            label: Text(_capitalize(value)),
            selected: value == selected,
            onSelected: (_) => onSelected(value),
            selectedColor: AppColors.primarySoft,
            backgroundColor: AppColors.backgroundRaised,
            side: BorderSide(
              color: value == selected ? AppColors.primary : AppColors.border,
            ),
            labelStyle: AppTheme.body(
              12,
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

  String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Icon(
            icon,
            color: onTap == null ? AppColors.textMuted : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
