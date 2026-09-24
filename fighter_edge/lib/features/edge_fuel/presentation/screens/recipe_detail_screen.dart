import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../billing/subscription.dart';
import '../../../../routing/app_navigation.dart';
import '../../../../routing/app_router.dart';
import '../../../../screens/paywall_screen.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_haptics.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_scaffold.dart';
import '../../../../widgets/primary_button.dart';
import '../../domain/calculators/recipe_nutrient_calculator.dart';
import '../../domain/models/food_enums.dart';
import '../../domain/models/food_item.dart';
import '../../domain/models/food_log_entry.dart';
import '../../domain/models/recipe.dart';
import '../controllers/edge_fuel_controller.dart';
import '../controllers/recipe_library_controller.dart';
import '../recipe_copy.dart';
import '../widgets/allergen_notice.dart';
import '../widgets/serving_stepper.dart';

/// Full recipe view with serving scaling and add-to-day (master prompt §5.3).
class RecipeDetailScreen extends StatefulWidget {
  final RecipeListing listing;
  final Map<String, FoodItem> foodsById;
  final Set<Allergen> conflictingAllergens;
  final bool locked;
  final double? initialServings;

  const RecipeDetailScreen({
    super.key,
    required this.listing,
    required this.foodsById,
    this.conflictingAllergens = const {},
    this.locked = false,
    this.initialServings,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late double _servings =
      widget.initialServings ?? widget.listing.recipe.servings.toDouble();
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final recipe = widget.listing.recipe;

    // Master prompt §10: opening a premium recipe is an allowed upgrade
    // moment. It is also the ONLY one EF-3 introduces — never while the user
    // is actively logging food.
    if (widget.locked) {
      return ScreenScaffold(
        title: recipe.title,
        showBack: true,
        body: _LockedRecipe(title: recipe.title),
      );
    }

    final nutrients = RecipeNutrientCalculator.forServings(
      recipe,
      widget.foodsById,
      _servings,
    );
    final scale = _servings / (recipe.servings < 1 ? 1 : recipe.servings);

    return ScreenScaffold(
      title: recipe.title,
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
        children: [
          Text(
            recipe.description,
            style: AppType.callout(color: AppColors.textSecondary),
          ),
          const SizedBox(height: Insets.md),
          _MetaRow(listing: widget.listing),
          const SizedBox(height: Insets.xl),
          _ServingsCard(
            servings: _servings,
            onChanged: (v) => setState(() => _servings = v),
            nutrients: nutrients,
          ),
          const SizedBox(height: Insets.xl),
          const _SectionTitle('INGREDIENTS'),
          const SizedBox(height: Insets.sm),
          for (final ingredient in recipe.ingredients)
            _IngredientRow(
              ingredient: ingredient,
              food: widget.foodsById[ingredient.foodId],
              scale: scale,
            ),
          const SizedBox(height: Insets.xl),
          const _SectionTitle('METHOD'),
          const SizedBox(height: Insets.sm),
          for (var i = 0; i < recipe.steps.length; i++)
            _StepRow(number: i + 1, text: recipe.steps[i]),
          if (recipe.substitutions.isNotEmpty) ...[
            const SizedBox(height: Insets.xl),
            const _SectionTitle('SWAPS'),
            const SizedBox(height: Insets.sm),
            for (final sub in recipe.substitutions)
              _SubstitutionRow(
                from: widget.foodsById[sub.forFoodId]?.name ?? sub.forFoodId,
                to: widget.foodsById[sub.useFoodId]?.name ?? sub.useFoodId,
                reason: sub.reason,
              ),
          ],
          const SizedBox(height: Insets.xl),
          AllergenStatement(
            allergens: widget.listing.allergens,
            conflicting: widget.conflictingAllergens,
          ),
          const SizedBox(height: Insets.lg),
          const _Provenance(),
          const SizedBox(height: Insets.xl),
          PrimaryButton(
            _adding ? 'Adding…' : 'Add to today',
            icon: Icons.add_circle_outline,
            onPressed: _adding ? null : () => _addToDay(nutrients),
          ),
        ],
      ),
    );
  }

  Future<void> _addToDay(RecipeNutrients nutrients) async {
    final edgeFuel = context.read<EdgeFuelController>();
    final recipe = widget.listing.recipe;
    setState(() => _adding = true);

    final entry = FoodLogEntry(
      // Deterministic-ish but unique: a user may legitimately add the same
      // recipe twice in a day, so the timestamp is part of the id.
      id: 'recipe-${recipe.id}-${DateTime.now().microsecondsSinceEpoch}',
      name: recipe.title,
      notes: RecipeCopy.servingsLabel(_servings),
      calories: nutrients.kcalRounded,
      proteinGrams: nutrients.proteinRounded,
      carbGrams: nutrients.carbsRounded,
      fatGrams: nutrients.fatRounded,
      source: FoodLogSource.recipe,
      loggedAt: DateTime.now(),
    );

    await edgeFuel.addEntry(entry);
    AppHaptics.commit();
    if (!mounted) return;
    setState(() => _adding = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${recipe.title} added — ${nutrients.kcalRounded} kcal',
          style: AppType.subhead(),
        ),
        backgroundColor: AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }
}

class _LockedRecipe extends StatelessWidget {
  final String title;
  const _LockedRecipe({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.premium.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 28,
                color: AppColors.premium,
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppType.title1(),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              'This one is part of the Pro recipe library. Everything you have '
              'already unlocked stays free.',
              textAlign: TextAlign.center,
              style: AppType.subhead(color: AppColors.textMuted),
            ),
            const SizedBox(height: Insets.xl),
            PrimaryButton(
              'See Pro',
              icon: Icons.bolt,
              onPressed: () => AppNavigation.push(
                context,
                AppRoutes.paywall,
                extra: const PaywallRouteArgs(
                  highlight: Feature.edgeFuelPremiumRecipes,
                  trigger: PaywallTrigger.premiumRecipe,
                ),
                fallbackBuilder: (_) => const PaywallScreen(
                  highlight: Feature.edgeFuelPremiumRecipes,
                  trigger: PaywallTrigger.premiumRecipe,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final RecipeListing listing;
  const _MetaRow({required this.listing});

  @override
  Widget build(BuildContext context) {
    final recipe = listing.recipe;
    return Wrap(
      spacing: Insets.md,
      runSpacing: Insets.sm,
      children: [
        _Meta(Icons.schedule, RecipeCopy.timeLabel(recipe.totalMinutes)),
        _Meta(Icons.restaurant, RecipeCopy.mealTypeLabel(recipe.mealType)),
        if (recipe.trainingTiming != TrainingTiming.any)
          _Meta(
            Icons.fitness_center,
            RecipeCopy.timingLabel(recipe.trainingTiming),
          ),
        _Meta(Icons.payments_outlined, RecipeCopy.costLabel(recipe.costBand)),
        for (final tag in listing.dietTags)
          if (tag == DietTag.vegan || tag == DietTag.vegetarian)
            _Meta(Icons.eco_outlined, RecipeCopy.dietLabel(tag)),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: Insets.xs),
          Text(text, style: AppType.subhead(color: AppColors.textSecondary)),
        ],
      );
}

class _ServingsCard extends StatelessWidget {
  final double servings;
  final ValueChanged<double> onChanged;
  final RecipeNutrients nutrients;

  const _ServingsCard({
    required this.servings,
    required this.onChanged,
    required this.nutrients,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          ServingStepper(servings: servings, onChanged: onChanged),
          const SizedBox(height: Insets.lg),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedMacroValue(
                      value: nutrients.kcalRounded,
                      style: AppType.largeTitle(spacing: -0.5),
                    ),
                    Text(
                      'KCAL',
                      style: AppType.micro(
                        color: AppColors.textMuted,
                        weight: FontWeight.w700,
                        spacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              _Macro('PROTEIN', nutrients.proteinRounded, AppColors.protein),
              _Macro('CARBS', nutrients.carbsRounded, AppColors.carbs),
              _Macro('FAT', nutrients.fatRounded, AppColors.fats),
            ],
          ),
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  final String label;
  final int grams;
  final Color color;
  const _Macro(this.label, this.grams, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            AnimatedMacroValue(
              value: grams,
              suffix: 'g',
              style: AppType.title2(color: color),
            ),
            Text(
              label,
              style: AppType.micro(
                color: AppColors.textMuted,
                weight: FontWeight.w700,
                spacing: 0.8,
              ),
            ),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppType.micro(
          color: AppColors.textMuted,
          weight: FontWeight.w700,
          spacing: 0.8,
        ),
      );
}

class _IngredientRow extends StatelessWidget {
  final RecipeIngredient ingredient;
  final FoodItem? food;
  final double scale;

  const _IngredientRow({
    required this.ingredient,
    required this.food,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final grams = ingredient.grams * scale;
    final label = ingredient.householdUnitLabel;
    final note = ingredient.note;
    final optional = ingredient.optional;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '${grams.round()} g',
              style: AppType.subhead(
                weight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food?.name ?? ingredient.foodId,
                  style: AppType.subhead(color: AppColors.textSecondary),
                ),
                if (label != null || note.isNotEmpty || optional)
                  Text(
                    [
                      // Household units are shown only at the original serving
                      // count — "2 tbsp" stops being true once you scale to
                      // 1.5x, and a wrong household measure is worse than none.
                      if (label != null && (scale - 1).abs() < 1e-9) label,
                      if (note.isNotEmpty) note,
                      if (optional) 'optional',
                    ].join(' · '),
                    style: AppType.subhead(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int number;
  final String text;
  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Insets.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '$number',
                style: AppType.title2(color: AppColors.primary),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: AppType.callout(
                  color: AppColors.textSecondary,
                  weight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      );
}

class _SubstitutionRow extends StatelessWidget {
  final String from;
  final String to;
  final String reason;

  const _SubstitutionRow({
    required this.from,
    required this.to,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Insets.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.swap_horiz, size: 15, color: AppColors.textMuted),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                reason.isEmpty ? '$from → $to' : '$from → $to  ·  $reason',
                style: AppType.subhead(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
}

class _Provenance extends StatelessWidget {
  const _Provenance();

  @override
  Widget build(BuildContext context) => Text(
        RecipeCopy.draftNotice,
        style: AppType.subhead(color: AppColors.textMuted),
      );
}
