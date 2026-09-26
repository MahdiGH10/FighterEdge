import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_haptics.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/animated_count.dart';
import '../widgets/app_scaffold.dart';
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
          onToggle: _confirmToggled,
        ),
      1 => _MealsView(
          edgeFuel: edgeFuel,
          onEdit: _editFood,
          onLogged: _confirmLogged,
          onToggle: _confirmToggled,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: Column(children: [
              _DateSwitcher(edgeFuel: edgeFuel),
              const SizedBox(height: Insets.sm),
              _NutritionSegments(
                  selected: _tab,
                  onSelected: (index) => setState(() => _tab = index)),
            ]),
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

  /// Marking a meal eaten/not-eaten used to be a silent side effect of
  /// tapping the row (see the row-tap fix below) — it now gets the same
  /// haptic + Undo treatment as adding one, so it is never a one-way door
  /// either. Undo restores the exact original entry rather than toggling
  /// again, since toggling the same stale [entry] object twice would flip
  /// to the same state both times.
  void _confirmToggled(EdgeFuelController edgeFuel, FoodLogEntry entry) {
    AppHaptics.commit();
    final l = L.of(context);
    final nowEaten = !entry.consumed;
    edgeFuel.toggleEntry(entry);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(nowEaten
              ? l.foodMarkedEaten(entry.name)
              : l.foodMarkedNotEaten(entry.name)),
          action: SnackBarAction(
            label: l.commonUndo,
            textColor: AppColors.accentText,
            onPressed: () => edgeFuel.updateEntry(entry),
          ),
        ),
      );
  }

  Future<void> _editFood(
    EdgeFuelController edgeFuel, {
    FoodLogEntry? existing,
  }) async {
    final entry = await showDialog<FoodLogEntry>(
      context: context,
      builder: (_) => _FoodEntryDialog(existing: existing),
    );
    if (entry == null) return;
    // Shown at once; storage confirms in the background (audit A-4).
    if (existing == null) {
      unawaited(edgeFuel.addEntry(entry));
      if (mounted) _confirmLogged(edgeFuel, entry);
    } else {
      unawaited(edgeFuel.updateEntry(entry));
    }
  }
}

class _DateSwitcher extends StatelessWidget {
  final EdgeFuelController edgeFuel;
  const _DateSwitcher({required this.edgeFuel});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final label = edgeFuel.isToday
        ? l.commonToday
        : DateFormat('EEE, MMM d').format(edgeFuel.selectedDate);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      child: Row(
        children: [
          HeaderIcon(
            Icons.chevron_left,
            label: l.nutritionPreviousDay,
            onTap: () => edgeFuel.shiftDate(-1),
          ),
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
          HeaderIcon(
            Icons.chevron_right,
            label: l.nutritionNextDay,
            onTap: () => edgeFuel.shiftDate(1),
          ),
        ],
      ),
    );
  }
}

/// A calorie figure above this is a typo, not a meal.
const int _maxManualCalories = 10000;

/// Same for any single macro, in grams.
const int _maxManualMacroGrams = 1000;

/// Manual food entry. Owns its controllers so they are disposed with the
/// dialog, after its exit animation, never while it is still on screen.
class _FoodEntryDialog extends StatefulWidget {
  final FoodLogEntry? existing;
  const _FoodEntryDialog({this.existing});

  @override
  State<_FoodEntryDialog> createState() => _FoodEntryDialogState();
}

class _FoodEntryDialogState extends State<_FoodEntryDialog> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fats;

  String? _nameError;
  String? _caloriesError;
  String? _proteinError;
  String? _carbsError;
  String? _fatsError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _calories = TextEditingController(text: e?.calories.toString() ?? '');
    _protein = TextEditingController(text: e?.proteinGrams.toString() ?? '');
    _carbs = TextEditingController(text: e?.carbGrams.toString() ?? '');
    _fats = TextEditingController(text: e?.fatGrams.toString() ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fats.dispose();
    super.dispose();
  }

  /// Empty is allowed for macros (counted as 0); anything typed must be a
  /// whole number in range. Digits-only fields already rule out signs.
  String? _macroError(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final v = int.tryParse(t);
    if (v == null || v > _maxManualMacroGrams) {
      return 'Enter 0 to $_maxManualMacroGrams g.';
    }
    return null;
  }

  void _save() {
    final calories = int.tryParse(_calories.text.trim());
    setState(() {
      _nameError = _name.text.trim().isEmpty ? 'Enter a name.' : null;
      _caloriesError = calories == null || calories > _maxManualCalories
          ? 'Enter 0 to $_maxManualCalories kcal.'
          : null;
      _proteinError = _macroError(_protein.text);
      _carbsError = _macroError(_carbs.text);
      _fatsError = _macroError(_fats.text);
    });
    if ([_nameError, _caloriesError, _proteinError, _carbsError, _fatsError]
        .any((e) => e != null)) {
      return;
    }
    final existing = widget.existing;
    Navigator.pop(
      context,
      FoodLogEntry(
        id: existing?.id ?? 'food-${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        notes: _notes.text.trim().isEmpty ? 'Custom meal' : _notes.text.trim(),
        calories: calories!,
        proteinGrams: int.tryParse(_protein.text.trim()) ?? 0,
        carbGrams: int.tryParse(_carbs.text.trim()) ?? 0,
        fatGrams: int.tryParse(_fats.text.trim()) ?? 0,
        consumed: existing?.consumed ?? true,
        saved: existing?.saved ?? false,
        source: existing?.source ?? FoodLogSource.manual,
        loggedAt: existing?.loggedAt ?? DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Add food' : 'Edit food',
        style: AppType.title2(),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogField(
              controller: _name,
              label: 'Food or meal name',
              errorText: _nameError,
            ),
            _DialogField(controller: _notes, label: 'Notes'),
            _DialogField(
              controller: _calories,
              label: 'Calories',
              number: true,
              errorText: _caloriesError,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DialogField(
                    controller: _protein,
                    label: 'Protein',
                    number: true,
                    errorText: _proteinError,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: _DialogField(
                    controller: _carbs,
                    label: 'Carbs',
                    number: true,
                    errorText: _carbsError,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: _DialogField(
                    controller: _fats,
                    label: 'Fats',
                    number: true,
                    errorText: _fatsError,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppType.callout(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _save,
          child: Text(
            'Save',
            style: AppType.callout(
              weight: FontWeight.w700,
              color: AppColors.accentText,
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool number;
  final String? errorText;
  const _DialogField({
    required this.controller,
    required this.label,
    this.number = false,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        inputFormatters: number
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ]
            : null,
        style: AppType.callout(),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          errorMaxLines: 2,
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
  final void Function(EdgeFuelController, FoodLogEntry) onToggle;
  const _TodayView(
      {required this.edgeFuel,
      required this.ratio,
      required this.ringColor,
      required this.onEdit,
      required this.onAdd,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hasTarget = edgeFuel.hasUsableTarget;
    final left = (edgeFuel.targetCalories - edgeFuel.consumedCalories)
        .clamp(0, edgeFuel.targetCalories);
    final over =
        hasTarget && edgeFuel.consumedCalories > edgeFuel.targetCalories;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
      children: [
        AppCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Center(
                  child: ProgressRing(
                progress: ratio.clamp(0.0, 1.0),
                size: AppAccessibility.isLargeText(context)
                    ? LayoutTokens.fuelRingLarge
                    : LayoutTokens.fuelRing,
                strokeWidth: Insets.sm,
                color: ringColor,
                child: Padding(
                    padding: const EdgeInsets.all(Insets.xl),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      AnimatedCount(
                          value: (hasTarget ? left : edgeFuel.consumedCalories)
                              .toDouble(),
                          formatter: (value) => '${value.round()}',
                          style: AppType.largeTitle()),
                      Text(
                          hasTarget
                              ? l.nutritionKcalLeft
                              : l.nutritionLoggedToday,
                          textAlign: TextAlign.center,
                          style: AppType.subhead(
                              color: AppAccessibility.textSecondary(context))),
                    ])),
              )),
              if (over) ...[
                const SizedBox(height: Insets.md),
                Text(
                    l.nutritionOverTarget(
                        edgeFuel.consumedCalories - edgeFuel.targetCalories),
                    textAlign: TextAlign.center,
                    style: AppType.subhead(color: AppColors.negative)),
              ],
              const SizedBox(height: Insets.xl),
              _Macro(l.nutritionProtein, edgeFuel.consumedProtein,
                  edgeFuel.targetProtein, AppColors.protein),
              const SizedBox(height: Insets.md),
              _Macro(l.nutritionCarbs, edgeFuel.consumedCarbs,
                  edgeFuel.targetCarbs, AppColors.carbs),
              const SizedBox(height: Insets.md),
              _Macro(l.nutritionFats, edgeFuel.consumedFats,
                  edgeFuel.targetFats, AppColors.fats),
              const SizedBox(height: Insets.md),
              TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    minimumSize:
                        const Size.fromHeight(AppAccessibility.minTouchTarget),
                  ),
                  onPressed: () => AppNavigation.push(
                      context,
                      edgeFuel.hasCompletedSetup
                          ? AppRoutes.fuelPlan
                          : AppRoutes.fuelSetup,
                      fallbackBuilder: (_) => edgeFuel.hasCompletedSetup
                          ? const EdgeFuelPlanScreen()
                          : const EdgeFuelSetupScreen()),
                  child: Text(
                      hasTarget ? l.nutritionViewPlan : l.dashboardSetFuel)),
              if (FuelWhatIsLeft.appliesTo(edgeFuel))
                FuelWhatIsLeft(edgeFuel: edgeFuel, compact: true),
            ])),
        const SizedBox(height: Insets.xl),
        SectionHeader(l.nutritionMeals),
        if (edgeFuel.entries.isEmpty)
          _QuickStartMeals(edgeFuel: edgeFuel, onSearch: onAdd)
        else
          _MealGroup(edgeFuel: edgeFuel, onEdit: onEdit, onToggle: onToggle),
        if (edgeFuel.entries.isNotEmpty) ...[
          const SizedBox(height: Insets.md),
          PrimaryButton(l.nutritionAddFood,
              icon: Icons.add, expand: true, onPressed: onAdd),
        ],
      ],
    );
  }
}

class _NutritionSegments extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;
  const _NutritionSegments({required this.selected, required this.onSelected});
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final labels = [
      l.nutritionTabToday,
      l.nutritionTabMeals,
      l.nutritionTabRecipes
    ];
    if (AppAccessibility.isLargeText(context)) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (index, label) in labels.indexed)
          Semantics(
              selected: selected == index,
              child: TextButton(
                  style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(
                          AppAccessibility.minTouchTarget),
                      backgroundColor: selected == index
                          ? AppColors.surfaceElevated
                          : AppColors.surface,
                      foregroundColor: AppColors.textPrimary),
                  onPressed: () => onSelected(index),
                  child: Text(label, style: AppType.callout()))),
      ]);
    }
    return SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: selected,
          backgroundColor: AppColors.surface,
          thumbColor: AppColors.surfaceElevated,
          padding: const EdgeInsets.all(Insets.xs),
          onValueChanged: (value) {
            if (value != null) {
              AppHaptics.selection();
              onSelected(value);
            }
          },
          children: {
            for (final (index, label) in labels.indexed)
              index: ConstrainedBox(
                  constraints: const BoxConstraints(
                      minHeight: AppAccessibility.minTouchTarget),
                  child: Center(
                      child: Text(label,
                          style: AppType.subhead(
                              color: selected == index
                                  ? AppColors.textPrimary
                                  : AppAccessibility.textSecondary(context)))))
          },
        ));
  }
}

class _MealGroup extends StatelessWidget {
  final EdgeFuelController edgeFuel;
  final Future<void> Function(EdgeFuelController, {FoodLogEntry? existing})
      onEdit;
  final void Function(EdgeFuelController, FoodLogEntry) onToggle;
  const _MealGroup(
      {required this.edgeFuel, required this.onEdit, required this.onToggle});
  @override
  Widget build(BuildContext context) => AppCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (final (index, entry) in edgeFuel.entries.indexed) ...[
          if (index > 0)
            Divider(
                height: Insets.xxs / 2,
                color: AppAccessibility.border(context)),
          _FoodRow(
              entry: entry,
              onToggle: () => onToggle(edgeFuel, entry),
              onEdit: () => onEdit(edgeFuel, existing: entry),
              onDelete: () => edgeFuel.deleteEntry(entry),
              onSaveToggle: () => edgeFuel.toggleSavedFood(entry)),
        ],
      ]));
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
            if (meal != _meals.last)
              Divider(
                  height: Insets.xxs / 2,
                  color: AppAccessibility.border(context)),
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
    unawaited(edgeFuel.addEntry(
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
    ));
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(Radii.tile),
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
  final void Function(EdgeFuelController, FoodLogEntry) onToggle;

  const _MealsView({
    required this.edgeFuel,
    required this.onEdit,
    required this.onLogged,
    required this.onToggle,
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
                  onPressed: () {
                    final logged = edgeFuel.entryForLogAgain(entry);
                    unawaited(edgeFuel.addEntry(logged));
                    onLogged(edgeFuel, logged);
                  },
                ),
            ],
          ),
          const SizedBox(height: Insets.lg),
        ],
        SectionHeader('Meals logged - $eaten/${edgeFuel.entries.length}'),
        if (edgeFuel.entries.isEmpty) _QuickStartMeals(edgeFuel: edgeFuel),
        if (edgeFuel.entries.isNotEmpty)
          _MealGroup(edgeFuel: edgeFuel, onEdit: onEdit, onToggle: onToggle),
      ],
    );
  }
}

class _Macro extends StatelessWidget {
  final String label;
  final int value, target;
  final Color color;
  const _Macro(this.label, this.value, this.target, this.color);
  @override
  Widget build(BuildContext context) {
    final over = target > 0 && value > target;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: Insets.sm,
          runSpacing: Insets.xs,
          children: [
            Text(label,
                style: AppType.subhead(
                    color: AppAccessibility.textSecondary(context))),
            Text(
                target > 0
                    ? L.of(context).nutritionMacroGrams(value, target)
                    : L.of(context).nutritionGrams(value),
                style: AppType.subhead(
                    color: over ? AppColors.negative : AppColors.textPrimary)),
          ]),
      const SizedBox(height: Insets.sm),
      ClipRRect(
          borderRadius: BorderRadius.circular(Radii.chip),
          child: LinearProgressIndicator(
              value: target <= 0 ? 0 : (value / target).clamp(0.0, 1.0),
              minHeight: Insets.xs,
              backgroundColor: AppColors.track,
              color: over ? AppColors.negative : color)),
    ]);
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
    final secondary = AppAccessibility.textSecondary(context);
    // The row itself used to toggle eaten/not-eaten on any tap, with no
    // visible control and no way back — the exact bug a tester hit. A tap on
    // the row now opens it for editing, matching what tapping a list row
    // means everywhere else in the app; eaten/not-eaten moves to its own
    // small control with its own label, below.
    return Padding(
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: '${entry.name}, ${entry.notes}, ${entry.calories} kcal'
                  '${entry.saved ? ', saved' : ''}',
              child: PressScale(
                onTap: onEdit,
                child: ExcludeSemantics(
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
                      Text('${entry.calories} kcal',
                          style: AppType.subhead(color: secondary)),
                      Text(
                        entry.notes,
                        style: AppType.subhead(
                          weight: FontWeight.w500,
                          color: secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _ToggleCheck(checked: entry.consumed, onTap: onToggle),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
            color: AppColors.surface,
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'save') onSaveToggle();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(L.of(context).commonEdit),
              ),
              PopupMenuItem(
                value: 'save',
                child: Text(entry.saved
                    ? L.of(context).commonUnsave
                    : L.of(context).commonSaveMeal),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(L.of(context).commonDelete),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The eaten/not-eaten control: its own tap target and its own label,
/// distinct from the row (which opens the entry) and sized to
/// [AppAccessibility.minTouchTarget] without inflating the 26px glyph a
/// larger visual circle would have looked heavy next to.
class _ToggleCheck extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;
  const _ToggleCheck({required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Semantics(
      button: true,
      toggled: checked,
      label: checked ? l.foodMarkNotEaten : l.foodMarkEaten,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: AppAccessibility.minTouchTarget / 2,
        child: SizedBox.square(
          dimension: AppAccessibility.minTouchTarget,
          child: Center(child: _Check(checked: checked)),
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
