import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../features/edge_fuel/domain/models/food_log_entry.dart';
import '../features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../features/edge_fuel/domain/models/food_enums.dart';
import '../features/edge_fuel/presentation/controllers/recipe_library_controller.dart';
import '../features/edge_fuel/presentation/screens/edge_fuel_plan_screen.dart';
import '../features/edge_fuel/presentation/screens/recipe_library_screen.dart';
import '../features/edge_fuel/presentation/screens/edge_fuel_setup_screen.dart';
import '../features/edge_fuel/presentation/widgets/add_food_sheet.dart';
import '../features/edge_fuel/presentation/widgets/fuel_what_is_left.dart';
import '../l10n/gen/app_localizations.dart';
import '../routing/app_navigation.dart';
import '../routing/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_haptics.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/animated_count.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_chips.dart';
import '../widgets/primary_button.dart';
import '../widgets/progress_ring.dart';
import '../widgets/press_scale.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final edgeFuel = context.watch<EdgeFuelController>();
    final targetCalories = edgeFuel.targetCalories;
    final ratio =
        targetCalories == 0 ? 0.0 : edgeFuel.consumedCalories / targetCalories;
    final ringColor = ratio > 1 ? AppColors.negative : AppColors.positive;
    final activeTab = switch (_tab) {
      0 => _TodayView(
          edgeFuel: edgeFuel,
          ratio: ratio,
          ringColor: ringColor,
          onEdit: _editFood,
          onAdd: () => _addFood(edgeFuel),
        ),
      1 => _MealsView(
          edgeFuel: edgeFuel,
          onEdit: _editFood,
          onLogged: _confirmLogged,
        ),
      _ => const _RecipesTab(),
    };

    return ScreenScaffold.tab(
      title: l.nutritionTitle,
      actions: [
        HeaderIcon(
          Icons.add,
          label: l.nutritionAddFood,
          onTap: () => _addFood(edgeFuel),
        ),
      ],
      body: Column(
        children: [
          _DateSwitcher(edgeFuel: edgeFuel),
          const SizedBox(height: Insets.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: FilterChips(
              options: [
                l.nutritionTabToday,
                l.nutritionTabMeals,
                l.nutritionTabRecipes,
              ],
              selectedIndex: _tab,
              onSelected: (i) => setState(() => _tab = i),
              scrollable: false,
            ),
          ),
          const SizedBox(height: Insets.lg),
          Expanded(child: activeTab),
        ],
      ),
    );
  }

  Future<void> _addFood(EdgeFuelController edgeFuel) async {
    final l = L.of(context);
    final dayLabel = edgeFuel.isToday
        ? l.commonToday
        : DateFormat('EEE, MMM d').format(edgeFuel.selectedDate);
    final outcome = await showAddFoodSheet(context, dayLabel: dayLabel);
    if (!mounted) return;
    switch (outcome) {
      case FoodLogged(:final entry):
        _confirmLogged(edgeFuel, entry);
      case ManualEntryRequested():
        await _editFood(edgeFuel);
      case null:
        break;
    }
  }

  /// Every add lands with the same feedback: a haptic, what went in, and a
  /// way to take it back, so one-tap logging is never a one-way door.
  void _confirmLogged(EdgeFuelController edgeFuel, FoodLogEntry entry) {
    AppHaptics.commit();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
              L.of(context).nutritionAddedSnack(entry.name, entry.calories)),
          action: SnackBarAction(
            label: L.of(context).commonUndo,
            textColor: AppColors.accentText,
            onPressed: () => edgeFuel.deleteEntry(entry),
          ),
        ),
      );
  }

  Future<void> _editFood(
    EdgeFuelController edgeFuel, {
    FoodLogEntry? existing,
  }) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    final calories = TextEditingController(
      text: existing?.calories.toString() ?? '',
    );
    final protein = TextEditingController(
      text: existing?.proteinGrams.toString() ?? '',
    );
    final carbs = TextEditingController(
      text: existing?.carbGrams.toString() ?? '',
    );
    final fats = TextEditingController(
      text: existing?.fatGrams.toString() ?? '',
    );

    final entry = await showDialog<FoodLogEntry>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          existing == null ? 'Add food' : 'Edit food',
          style: AppType.title2(),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogField(controller: name, label: 'Food or meal name'),
              _DialogField(controller: notes, label: 'Notes'),
              _DialogField(
                controller: calories,
                label: 'Calories',
                number: true,
              ),
              Row(
                children: [
                  Expanded(
                    child: _DialogField(
                      controller: protein,
                      label: 'Protein',
                      number: true,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: _DialogField(
                      controller: carbs,
                      label: 'Carbs',
                      number: true,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: _DialogField(
                      controller: fats,
                      label: 'Fats',
                      number: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppType.callout(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              final parsedCalories = int.tryParse(calories.text.trim());
              if (name.text.trim().isEmpty || parsedCalories == null) return;
              Navigator.pop(
                ctx,
                FoodLogEntry(
                  id: existing?.id ??
                      'food-${DateTime.now().microsecondsSinceEpoch}',
                  name: name.text.trim(),
                  notes: notes.text.trim().isEmpty
                      ? 'Custom meal'
                      : notes.text.trim(),
                  calories: parsedCalories,
                  proteinGrams: int.tryParse(protein.text.trim()) ?? 0,
                  carbGrams: int.tryParse(carbs.text.trim()) ?? 0,
                  fatGrams: int.tryParse(fats.text.trim()) ?? 0,
                  consumed: existing?.consumed ?? true,
                  saved: existing?.saved ?? false,
                  source: existing?.source ?? FoodLogSource.manual,
                  loggedAt: existing?.loggedAt ?? DateTime.now(),
                ),
              );
            },
            child: Text(
              'Save',
              style: AppType.callout(
                weight: FontWeight.w700,
                color: AppColors.accentText,
              ),
            ),
          ),
        ],
      ),
    );

    name.dispose();
    notes.dispose();
    calories.dispose();
    protein.dispose();
    carbs.dispose();
    fats.dispose();

    if (entry == null) return;
    if (existing == null) {
      await edgeFuel.addEntry(entry);
      if (mounted) _confirmLogged(edgeFuel, entry);
    } else {
      await edgeFuel.updateEntry(entry);
    }
  }
}

class _DateSwitcher extends StatelessWidget {
  final EdgeFuelController edgeFuel;
  const _DateSwitcher({required this.edgeFuel});

  @override
  Widget build(BuildContext context) {
    final label = edgeFuel.isToday
        ? L.of(context).commonToday
        : DateFormat('EEE, MMM d').format(edgeFuel.selectedDate);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      child: Row(
        children: [
          HeaderIcon(Icons.chevron_left, onTap: () => edgeFuel.shiftDate(-1)),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppType.subhead(
                weight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          HeaderIcon(Icons.chevron_right, onTap: () => edgeFuel.shiftDate(1)),
        ],
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool number;
  const _DialogField({
    required this.controller,
    required this.label,
    this.number = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        style: AppType.callout(),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          labelText: label,
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

class _TodayView extends StatelessWidget {
  final EdgeFuelController edgeFuel;
  final double ratio;
  final Color ringColor;
  final Future<void> Function(EdgeFuelController, {FoodLogEntry? existing})
      onEdit;
  final VoidCallback onAdd;

  const _TodayView({
    required this.edgeFuel,
    required this.ratio,
    required this.ringColor,
    required this.onEdit,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
      children: [
        _EdgeFuelEntryCard(edgeFuel: edgeFuel),
        const SizedBox(height: Insets.lg),
        if (!edgeFuel.hasUsableTarget) ...[
          EmptyState(
            icon: Icons.bolt,
            title: 'Set your fuel target',
            message:
                'Complete EdgeFuel setup so your daily log can track against your own plan.',
            actionLabel: 'Set up EdgeFuel',
            onAction: () => AppNavigation.push(
              context,
              AppRoutes.fuelSetup,
              fallbackBuilder: (_) => const EdgeFuelSetupScreen(),
            ),
          ),
          const SizedBox(height: Insets.lg),
        ],
        SectionHeader(L.of(context).nutritionCalories),
        AppCard(
          child: Column(
            children: [
              const SizedBox(height: Insets.sm),
              ProgressRing(
                progress: ratio.clamp(0.0, 1.0),
                size: 160,
                strokeWidth: 12,
                color: ringColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Counts when a meal lands: the number moving is the
                    // meal you just logged, arriving.
                    AnimatedCount(
                      value: edgeFuel.consumedCalories.toDouble(),
                      formatter: (v) => '${v.round()}',
                      style: AppType.largeTitle(),
                    ),
                    Text(
                      edgeFuel.hasUsableTarget
                          ? '/ ${edgeFuel.targetCalories} kcal'
                          : L.of(context).nutritionLoggedToday,
                      style: AppType.subhead(
                        weight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.xl),
              Row(
                children: [
                  _Macro(
                    l.nutritionProtein,
                    edgeFuel.consumedProtein,
                    edgeFuel.targetProtein,
                    AppColors.protein,
                  ),
                  _Macro(
                    l.nutritionCarbs,
                    edgeFuel.consumedCarbs,
                    edgeFuel.targetCarbs,
                    AppColors.carbs,
                  ),
                  _Macro(
                    l.nutritionFats,
                    edgeFuel.consumedFats,
                    edgeFuel.targetFats,
                    AppColors.fats,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (FuelWhatIsLeft.appliesTo(edgeFuel)) ...[
          const SizedBox(height: Insets.md),
          FuelWhatIsLeft(edgeFuel: edgeFuel),
        ],
        const SizedBox(height: Insets.xl),
        SectionHeader(L.of(context).nutritionMeals),
        if (edgeFuel.entries.isEmpty)
          _QuickStartMeals(edgeFuel: edgeFuel, onSearch: onAdd),
        for (final entry in edgeFuel.entries)
          _FoodRow(
            entry: entry,
            onToggle: () => edgeFuel.toggleEntry(entry),
            onEdit: () => onEdit(edgeFuel, existing: entry),
            onDelete: () => edgeFuel.deleteEntry(entry),
            onSaveToggle: () => edgeFuel.toggleSavedFood(entry),
          ),
        if (edgeFuel.entries.isNotEmpty) ...[
          const SizedBox(height: Insets.sm),
          GhostButton(
            L.of(context).nutritionAddFood,
            icon: Icons.add,
            expand: true,
            onPressed: onAdd,
          ),
        ],
      ],
    );
  }
}

class _QuickStartMeals extends StatelessWidget {
  final EdgeFuelController edgeFuel;
  final VoidCallback? onSearch;

  const _QuickStartMeals({required this.edgeFuel, this.onSearch});

  static const _meals = [
    _QuickMeal(
      name: 'Greek yogurt + oats',
      notes: 'Fast breakfast · add fruit if available',
      calories: 420,
      protein: 28,
      carbs: 52,
      fats: 10,
      icon: Icons.breakfast_dining,
    ),
    _QuickMeal(
      name: 'Chicken rice bowl',
      notes: 'Simple post-training meal',
      calories: 610,
      protein: 46,
      carbs: 72,
      fats: 14,
      icon: Icons.rice_bowl,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Start with something simple', style: AppType.title2()),
          const SizedBox(height: Insets.xs),
          Text(
            'Log a realistic meal now and your target becomes useful immediately.',
            style: AppType.subhead(color: AppColors.textSecondary),
          ),
          const SizedBox(height: Insets.md),
          if (onSearch != null) ...[
            PrimaryButton(
              L.of(context).nutritionSearchFoods,
              icon: Icons.search,
              expand: true,
              onPressed: onSearch,
            ),
            const SizedBox(height: Insets.md),
          ],
          for (final meal in _meals) ...[
            _QuickMealTile(
              meal: meal,
              onTap: () => _addMeal(context, meal),
            ),
            if (meal != _meals.last) const SizedBox(height: Insets.sm),
          ],
          const SizedBox(height: Insets.md),
          GhostButton(
            'Browse recipes',
            icon: Icons.menu_book_outlined,
            expand: true,
            onPressed: () => AppNavigation.push(
              context,
              AppRoutes.fuelRecipes,
              fallbackBuilder: (_) => const RecipeLibraryScreen(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addMeal(BuildContext context, _QuickMeal meal) async {
    AppHaptics.commit();
    await edgeFuel.addEntry(
      FoodLogEntry(
        id: 'quick-${DateTime.now().microsecondsSinceEpoch}',
        name: meal.name,
        notes: meal.notes,
        calories: meal.calories,
        proteinGrams: meal.protein,
        carbGrams: meal.carbs,
        fatGrams: meal.fats,
        source: FoodLogSource.manual,
        loggedAt: DateTime.now(),
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${meal.name} added to today')),
    );
  }
}

class _QuickMeal {
  final String name;
  final String notes;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  final IconData icon;

  const _QuickMeal({
    required this.name,
    required this.notes,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.icon,
  });
}

class _QuickMealTile extends StatelessWidget {
  final _QuickMeal meal;
  final VoidCallback onTap;

  const _QuickMealTile({required this.meal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.backgroundRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(meal.icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meal.name,
                        style: AppType.callout(weight: FontWeight.w800)),
                    const SizedBox(height: Insets.xxs),
                    Text(meal.notes,
                        style: AppType.micro(color: AppColors.textMuted)),
                    const SizedBox(height: Insets.xs),
                    Text(
                      '${meal.calories} kcal · ${meal.protein}g protein · ${meal.carbs}g carbs',
                      style: AppType.micro(
                          color: AppColors.textSecondary,
                          weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              const Icon(Icons.add_circle_outline, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entry point into the curated recipe catalog (EF-3).
///
/// A tab rather than a pushed screen so browsing recipes sits alongside the
/// day's log, not away from it. The library itself is a full screen; this is
/// the doorway, with a preview of what is inside so the tab is never a blank
/// call-to-action.
class _RecipesTab extends StatelessWidget {
  const _RecipesTab();

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.4;
    const beforeTraining = _RecipeShortcut(
      icon: Icons.bolt,
      label: 'Before training',
      filters: RecipeFilters(
        trainingTiming: TrainingTiming.preTraining,
      ),
    );
    const afterTraining = _RecipeShortcut(
      icon: Icons.restart_alt,
      label: 'After training',
      filters: RecipeFilters(
        trainingTiming: TrainingTiming.postTraining,
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
      children: [
        AppCard(
          accent: AppColors.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RECIPE LIBRARY',
                style: AppType.micro(
                  color: AppColors.textMuted,
                  weight: FontWeight.w700,
                  spacing: 0.8,
                ),
              ),
              const SizedBox(height: Insets.xs),
              Text('Food you can actually cook', style: AppType.title1()),
              const SizedBox(height: Insets.sm),
              Text(
                'Fighter-focused recipes with the macros worked out, built '
                'around what you have in the kitchen. Filter by training '
                'timing, diet, cost and time.',
                style: AppType.subhead(color: AppColors.textSecondary),
              ),
              const SizedBox(height: Insets.lg),
              PrimaryButton(
                'Browse recipes',
                icon: Icons.menu_book_outlined,
                onPressed: () => AppNavigation.push(
                  context,
                  AppRoutes.fuelRecipes,
                  fallbackBuilder: (_) => const RecipeLibraryScreen(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        if (largeText) ...[
          beforeTraining,
          const SizedBox(height: Insets.md),
          afterTraining,
        ] else
          const Row(
            children: [
              Expanded(child: beforeTraining),
              SizedBox(width: Insets.md),
              Expanded(child: afterTraining),
            ],
          ),
      ],
    );
  }
}

class _RecipeShortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final RecipeFilters filters;

  const _RecipeShortcut({
    required this.icon,
    required this.label,
    required this.filters,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => AppNavigation.push(
        context,
        AppRoutes.fuelRecipes,
        extra: filters,
        fallbackBuilder: (_) => RecipeLibraryScreen(initialFilters: filters),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: Insets.sm),
          Text(label, style: AppType.subhead(weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MealsView extends StatelessWidget {
  final EdgeFuelController edgeFuel;
  final Future<void> Function(EdgeFuelController, {FoodLogEntry? existing})
      onEdit;
  final void Function(EdgeFuelController, FoodLogEntry) onLogged;

  const _MealsView({
    required this.edgeFuel,
    required this.onEdit,
    required this.onLogged,
  });

  @override
  Widget build(BuildContext context) {
    final eaten = edgeFuel.entries.where((entry) => entry.consumed).length;
    // Saved first, then recents not already saved. Both span days, so the
    // shortlist is there on a fresh morning too.
    final savedKeys = {
      for (final s in edgeFuel.savedFoods) s.name.trim().toLowerCase(),
    };
    final quickAdds = [
      ...edgeFuel.savedFoods,
      ...edgeFuel.recentFoods
          .where((r) => !savedKeys.contains(r.name.trim().toLowerCase())),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
      children: [
        if (quickAdds.isNotEmpty) ...[
          const SectionHeader('Quick add'),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              for (final entry in quickAdds.take(8))
                ActionChip(
                  label: Text(entry.name),
                  avatar: Icon(
                    savedKeys.contains(entry.name.trim().toLowerCase())
                        ? Icons.star
                        : Icons.history,
                    size: IconSizes.inline,
                    color: AppColors.primary,
                  ),
                  onPressed: () async {
                    final logged = await edgeFuel.logAgain(entry);
                    onLogged(edgeFuel, logged);
                  },
                ),
            ],
          ),
          const SizedBox(height: Insets.lg),
        ],
        SectionHeader('Meals logged - $eaten/${edgeFuel.entries.length}'),
        if (edgeFuel.entries.isEmpty) _QuickStartMeals(edgeFuel: edgeFuel),
        for (final entry in edgeFuel.entries)
          _FoodRow(
            entry: entry,
            onToggle: () => edgeFuel.toggleEntry(entry),
            onEdit: () => onEdit(edgeFuel, existing: entry),
            onDelete: () => edgeFuel.deleteEntry(entry),
            onSaveToggle: () => edgeFuel.toggleSavedFood(entry),
          ),
      ],
    );
  }
}

class _Macro extends StatelessWidget {
  final String label;
  final int value;
  final int target;
  final Color color;
  const _Macro(this.label, this.value, this.target, this.color);

  @override
  Widget build(BuildContext context) {
    final over = target > 0 && value > target;
    final progress = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    return Expanded(
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: AppType.micro(
              weight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text('$value g', style: AppType.title2()),
          Text(
            target <= 0 ? 'set target' : '/ $target g',
            style: AppType.micro(
              weight: FontWeight.w500,
              color: over ? AppColors.negative : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: Insets.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppColors.track,
              valueColor: AlwaysStoppedAnimation(
                over ? AppColors.negative : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  final FoodLogEntry entry;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSaveToggle;

  const _FoodRow({
    required this.entry,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onSaveToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: AppCard(
        onTap: onToggle,
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.name,
                          style: AppType.callout(weight: FontWeight.w700),
                        ),
                      ),
                      if (entry.saved) ...[
                        const SizedBox(width: Insets.xs),
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: Insets.xxs),
                  Text(
                    entry.notes,
                    style: AppType.subhead(
                      weight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${entry.calories} kcal',
              style: AppType.subhead(
                weight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: Insets.md),
            _Check(checked: entry.consumed),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
              color: AppColors.surface,
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'save') onSaveToggle();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'save',
                  child: Text(entry.saved ? 'Unsave' : 'Save meal'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  final bool checked;
  const _Check({required this.checked});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : MotionTokens.fast,
      curve: MotionTokens.emphasized,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: checked ? AppColors.positive : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: checked ? AppColors.positive : AppColors.border,
          width: 2,
        ),
      ),
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : MotionTokens.fast,
        transitionBuilder: (child, animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: checked
            ? const Icon(
                Icons.check,
                key: ValueKey('meal-check'),
                size: 16,
                color: Colors.white,
              )
            : const SizedBox(key: ValueKey('meal-empty')),
      ),
    );
  }
}

class _EdgeFuelEntryCard extends StatelessWidget {
  final EdgeFuelController edgeFuel;

  const _EdgeFuelEntryCard({required this.edgeFuel});

  @override
  Widget build(BuildContext context) {
    final hasSetup = edgeFuel.hasCompletedSetup;
    final target = edgeFuel.target;
    final hasTarget = hasSetup && target != null && target.isSuccess;
    final consumed = edgeFuel.consumedCalories;
    final targetCalories = edgeFuel.targetCalories;
    final remaining = (targetCalories - consumed).clamp(0, targetCalories);
    final progress =
        targetCalories <= 0 ? 0.0 : (consumed / targetCalories).clamp(0.0, 1.0);
    final overTarget = targetCalories > 0 && consumed > targetCalories;

    return AppCard(
      accent: AppColors.premium,
      onTap: () => AppNavigation.push(
        context,
        hasSetup ? AppRoutes.fuelPlan : AppRoutes.fuelSetup,
        fallbackBuilder: (_) =>
            hasSetup ? const EdgeFuelPlanScreen() : const EdgeFuelSetupScreen(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bolt, color: AppColors.primary),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasTarget ? 'Today\'s EdgeFuel target' : 'EdgeFuel AI',
                      style: AppType.subhead(weight: FontWeight.w800),
                    ),
                    const SizedBox(height: Insets.xxs),
                    Text(
                      hasTarget
                          ? 'Personalized calories and macros for this day.'
                          : 'Get a personalized daily calorie and macro target.',
                      style: AppType.subhead(
                        weight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
          if (hasTarget) ...[
            const SizedBox(height: Insets.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    '$targetCalories kcal',
                    style: AppType.largeTitle(),
                  ),
                ),
                const SizedBox(width: Insets.md),
                AnimatedCount(
                  value: remaining.toDouble(),
                  formatter: (v) =>
                      overTarget ? 'Over target' : '${v.round()} left',
                  style: AppType.callout(
                    weight: FontWeight.w800,
                    color: overTarget ? AppColors.negative : AppColors.positive,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            AnimatedCount(
              value: consumed.toDouble(),
              formatter: (v) => '${v.round()} kcal logged',
              style: AppType.subhead(
                weight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: Insets.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.track,
                valueColor: AlwaysStoppedAnimation(
                  overTarget ? AppColors.negative : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                _TargetMacroChip(
                  label: 'Protein',
                  value: '${edgeFuel.targetProtein}g',
                  color: AppColors.protein,
                ),
                _TargetMacroChip(
                  label: 'Carbs',
                  value: '${edgeFuel.targetCarbs}g',
                  color: AppColors.carbs,
                ),
                _TargetMacroChip(
                  label: 'Fats',
                  value: '${edgeFuel.targetFats}g',
                  color: AppColors.fats,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TargetMacroChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TargetMacroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm, vertical: Insets.xs),
      decoration: BoxDecoration(
        color: AppColors.backgroundRaised,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: Insets.xs),
          Text(
            '$label $value',
            style: AppType.micro(
              weight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
