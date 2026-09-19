import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../billing/subscription.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../theme/app_accessibility.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/skeleton.dart';
import '../../../../widgets/app_scaffold.dart';
import '../../../../widgets/empty_state.dart';
import '../../../../widgets/filter_chips.dart';
import '../../data/food_catalog_repository.dart';
import '../../data/recipe_catalog_repository.dart';
import '../../domain/models/food_enums.dart';
import '../controllers/edge_fuel_controller.dart';
import '../controllers/recipe_library_controller.dart';
import '../widgets/allergen_notice.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';
import '../../../../theme/app_haptics.dart';
import '../../../../widgets/press_scale.dart';

/// Browse and filter the curated catalog (master prompt §5.3).
class RecipeLibraryScreen extends StatelessWidget {
  /// Optional starting filter, used when arriving from the plan screen.
  final RecipeFilters? initialFilters;

  const RecipeLibraryScreen({super.key, this.initialFilters});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) {
        final controller = RecipeLibraryController(
          recipeCatalog: ctx.read<RecipeCatalogRepository>(),
          foodCatalog: ctx.read<FoodCatalogRepository>(),
        );
        if (initialFilters != null) controller.setFilters(initialFilters!);
        // The allergens the user typed during setup drive the default filter.
        final draft = ctx.read<EdgeFuelController>().draft;
        if (draft != null) controller.setDeclaredAllergens(draft.allergens);
        controller.load();
        return controller;
      },
      child: const _RecipeLibraryView(),
    );
  }
}

class _RecipeLibraryView extends StatefulWidget {
  const _RecipeLibraryView();

  @override
  State<_RecipeLibraryView> createState() => _RecipeLibraryViewState();
}

class _RecipeLibraryViewState extends State<_RecipeLibraryView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RecipeLibraryController>();
    final isPro = context.watch<AuthController>().allows(
          Feature.edgeFuelPremiumRecipes,
        );

    return ScreenScaffold(
      title: 'Recipes',
      showBack: true,
      body: switch (true) {
        _ when controller.isLoading => const _LibrarySkeleton(),
        _ when controller.error != null => Center(
            child: EmptyState(
              icon: Icons.error_outline,
              title: 'Recipes unavailable',
              message: controller.error!,
            ),
          ),
        _ => _Body(controller: controller, isPro: isPro, search: _search),
      },
    );
  }
}

class _Body extends StatelessWidget {
  final RecipeLibraryController controller;
  final bool isPro;
  final TextEditingController search;

  const _Body({
    required this.controller,
    required this.isPro,
    required this.search,
  });

  @override
  Widget build(BuildContext context) {
    final visible = controller.visible;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            0,
            Insets.lg,
            Insets.md,
          ),
          child: TextField(
            controller: search,
            onChanged: controller.setQuery,
            style: AppType.callout(),
            decoration: InputDecoration(
              hintText: 'Search recipes',
              hintStyle: AppType.callout(color: AppColors.textMuted),
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: AppColors.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.button),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        _FilterBar(controller: controller),
        const SizedBox(height: Insets.md),
        Expanded(
          child: visible.isEmpty
              ? _EmptyResults(controller: controller)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.lg,
                    0,
                    Insets.lg,
                    Insets.xxl,
                  ),
                  // builder, not a plain ListView — the fixed-children form
                  // only mounts what fits the viewport, which has bitten this
                  // codebase in widget tests before (HANDOFF.md gotcha 2).
                  itemCount: visible.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _Notices(controller: controller);
                    final listing = visible[index - 1];
                    final locked = listing.recipe.isPremium && !isPro;
                    return RecipeCard(
                      listing: listing,
                      locked: locked,
                      conflictingAllergens: controller.conflictingAllergens(
                        listing,
                      ),
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => RecipeDetailScreen(
                            listing: listing,
                            foodsById: controller.foodsById,
                            conflictingAllergens:
                                controller.conflictingAllergens(listing),
                            locked: locked,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Notices extends StatelessWidget {
  final RecipeLibraryController controller;
  const _Notices({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        UnmatchedAllergenNotice(terms: controller.allergenMatch.unmatched),
        AllergenFilterBanner(
          hiddenCount: controller.hiddenByAllergens,
          showingConflicts: controller.filters.showAllergenConflicts,
          onToggle: controller.toggleAllergenConflicts,
        ),
      ],
    );
  }
}

class _EmptyResults extends StatelessWidget {
  final RecipeLibraryController controller;
  const _EmptyResults({required this.controller});

  @override
  Widget build(BuildContext context) {
    final hiddenByAllergens = controller.hiddenByAllergens;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
      children: [
        _Notices(controller: controller),
        const SizedBox(height: Insets.xl),
        EmptyState(
          icon: Icons.search_off,
          title: 'Nothing matches',
          message: hiddenByAllergens > 0
              ? 'Every recipe matching these filters contains one of your '
                  'allergens.'
              : 'Try clearing a filter or searching for something else.',
        ),
        const SizedBox(height: Insets.lg),
        Center(
          child: TextButton(
            onPressed: controller.clearFilters,
            child: Text(
              'Clear filters',
              style: AppType.subhead(
                color: AppColors.accentText,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final RecipeLibraryController controller;
  const _FilterBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final filters = controller.filters;

    const mealLabels = ['All', 'Breakfast', 'Lunch', 'Dinner', 'Snack'];
    const mealValues = <MealType?>[
      null,
      MealType.breakfast,
      MealType.lunch,
      MealType.dinner,
      MealType.snack,
    ];
    final mealIndex = mealValues.indexOf(filters.mealType);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          child: FilterChips(
            options: mealLabels,
            selectedIndex: mealIndex < 0 ? 0 : mealIndex,
            onSelected: (i) => controller.setFilters(
              i == 0
                  ? filters.copyWith(clearMealType: true)
                  : filters.copyWith(mealType: mealValues[i]),
            ),
          ),
        ),
        const SizedBox(height: Insets.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Toggle(
                  label: 'Before training',
                  selected:
                      filters.trainingTiming == TrainingTiming.preTraining,
                  onTap: () => controller.setFilters(
                    filters.trainingTiming == TrainingTiming.preTraining
                        ? filters.copyWith(clearTrainingTiming: true)
                        : filters.copyWith(
                            trainingTiming: TrainingTiming.preTraining,
                          ),
                  ),
                ),
                _Toggle(
                  label: 'After training',
                  selected:
                      filters.trainingTiming == TrainingTiming.postTraining,
                  onTap: () => controller.setFilters(
                    filters.trainingTiming == TrainingTiming.postTraining
                        ? filters.copyWith(clearTrainingTiming: true)
                        : filters.copyWith(
                            trainingTiming: TrainingTiming.postTraining,
                          ),
                  ),
                ),
                _Toggle(
                  label: 'Vegan',
                  selected: filters.dietTag == DietTag.vegan,
                  onTap: () => controller.setFilters(
                    filters.dietTag == DietTag.vegan
                        ? filters.copyWith(clearDietTag: true)
                        : filters.copyWith(dietTag: DietTag.vegan),
                  ),
                ),
                _Toggle(
                  label: 'Vegetarian',
                  selected: filters.dietTag == DietTag.vegetarian,
                  onTap: () => controller.setFilters(
                    filters.dietTag == DietTag.vegetarian
                        ? filters.copyWith(clearDietTag: true)
                        : filters.copyWith(dietTag: DietTag.vegetarian),
                  ),
                ),
                _Toggle(
                  label: 'Under 20 min',
                  selected: filters.maxMinutes == 20,
                  onTap: () => controller.setFilters(
                    filters.maxMinutes == 20
                        ? filters.copyWith(clearMaxMinutes: true)
                        : filters.copyWith(maxMinutes: 20),
                  ),
                ),
                _Toggle(
                  label: 'No oven',
                  selected: filters.noOvenOnly,
                  onTap: () => controller.setFilters(
                    filters.copyWith(noOvenOnly: !filters.noOvenOnly),
                  ),
                ),
                _Toggle(
                  label: 'Budget',
                  selected: filters.costBand == CostBand.low,
                  onTap: () => controller.setFilters(
                    filters.costBand == CostBand.low
                        ? filters.copyWith(clearCostBand: true)
                        : filters.copyWith(costBand: CostBand.low),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Toggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Insets.sm),
      child: Semantics(
        button: true,
        selected: selected,
        child: PressScale(
          onTap: onTap,
          haptic: AppHaptics.selection,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySoft : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.chip),
            ),
            child: Container(
              // Accessibility floor, not the visually-driven 36 this used to be.
              constraints: const BoxConstraints(
                  minHeight: AppAccessibility.minTouchTarget),
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.lg,
                vertical: Insets.sm,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.chip),
                border: Border.all(
                  color: selected ? AppColors.primary : Colors.transparent,
                ),
              ),
              child: Text(
                label,
                style: AppType.subhead(
                  weight: FontWeight.w600,
                  color: selected
                      ? AppColors.primaryBright
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stands in for the library while the catalog loads: search, filters, and
/// a few recipe cards in the shape they will arrive in.
class _LibrarySkeleton extends StatelessWidget {
  const _LibrarySkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.lg, 0),
        children: [
          const SkeletonBox(height: 48),
          const SizedBox(height: Insets.md),
          const Row(
            children: [
              SkeletonBox(width: 72, height: 32, radius: Radii.chip),
              SizedBox(width: Insets.sm),
              SkeletonBox(width: 88, height: 32, radius: Radii.chip),
              SizedBox(width: Insets.sm),
              SkeletonBox(width: 64, height: 32, radius: Radii.chip),
            ],
          ),
          const SizedBox(height: Insets.lg),
          for (var i = 0; i < 3; i++) ...const [
            SkeletonBox(height: 120, radius: Radii.card),
            SizedBox(height: Insets.sm),
            SkeletonBox.line(width: 200),
            SizedBox(height: Insets.xs),
            SkeletonBox.line(width: 140),
            SizedBox(height: Insets.lg),
          ],
        ],
      ),
    );
  }
}
