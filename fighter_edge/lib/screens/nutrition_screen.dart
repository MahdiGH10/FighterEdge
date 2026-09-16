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
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_chips.dart';
import '../widgets/primary_button.dart';
import '../widgets/progress_ring.dart';
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
    final edgeFuel = context.watch<EdgeFuelController>();
    final targetCalories = edgeFuel.targetCalories;
    final ratio =
        targetCalories == 0 ? 0.0 : edgeFuel.consumedCalories / targetCalories;
    final ringColor = ratio > 1 ? AppColors.negative : AppColors.positive;

    return ScreenScaffold.tab(
      title: 'Nutrition',
      actions: [
        HeaderIcon(Icons.add, onTap: () => _editFood(edgeFuel)),
      ],
      body: Column(
        children: [
          _DateSwitcher(edgeFuel: edgeFuel),
          const SizedBox(height: Insets.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: FilterChips(
              options: const ['Today', 'Meals', 'Recipes'],
              selectedIndex: _tab,
              onSelected: (i) => setState(() => _tab = i),
              scrollable: false,
            ),
          ),
          const SizedBox(height: Insets.lg),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _TodayView(
                  edgeFuel: edgeFuel,
                  ratio: ratio,
                  ringColor: ringColor,
                  onEdit: _editFood,
                ),
                _MealsView(edgeFuel: edgeFuel, onEdit: _editFood),
                const _RecipesTab(),
              ],
            ),
          ),
        ],
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
        ? 'Today'
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

  const _TodayView({
    required this.edgeFuel,
    required this.ratio,
    required this.ringColor,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
      children: [
        const _EdgeFuelEntryCard(),
        const SizedBox(height: Insets.lg),
        if (!edgeFuel.hasUsableTarget) ...[
          const EmptyState(
            icon: Icons.bolt,
            title: 'Set your fuel target',
            message:
                'Complete EdgeFuel setup so your daily log can track against your own plan.',
          ),
          const SizedBox(height: Insets.lg),
        ],
        const SectionHeader('Calories'),
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
                    Text(
                      '${edgeFuel.consumedCalories}',
                      style: AppType.largeTitle(),
                    ),
                    Text(
                      edgeFuel.hasUsableTarget
                          ? '/ ${edgeFuel.targetCalories} kcal'
                          : 'logged today',
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
                    'Protein',
                    edgeFuel.consumedProtein,
                    edgeFuel.targetProtein,
                    AppColors.protein,
                  ),
                  _Macro(
                    'Carbs',
                    edgeFuel.consumedCarbs,
                    edgeFuel.targetCarbs,
                    AppColors.carbs,
                  ),
                  _Macro(
                    'Fats',
                    edgeFuel.consumedFats,
                    edgeFuel.targetFats,
                    AppColors.fats,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.xl),
        const SectionHeader('Meals'),
        if (edgeFuel.entries.isEmpty)
          const EmptyState(
            icon: Icons.restaurant,
            title: 'No food logged',
            message: 'Use + to log a meal, snack, or drink for this day.',
          ),
        for (final entry in edgeFuel.entries)
          _FoodRow(
            entry: entry,
            onToggle: () => edgeFuel.toggleEntry(entry),
            onEdit: () => onEdit(edgeFuel, existing: entry),
            onDelete: () => edgeFuel.deleteEntry(entry),
            onSaveToggle: () =>
                edgeFuel.updateEntry(entry.copyWith(saved: !entry.saved)),
          ),
      ],
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
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RecipeLibraryScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        const Row(
          children: [
            Expanded(
              child: _RecipeShortcut(
                icon: Icons.bolt,
                label: 'Before training',
                filters: RecipeFilters(
                  trainingTiming: TrainingTiming.preTraining,
                ),
              ),
            ),
            SizedBox(width: Insets.md),
            Expanded(
              child: _RecipeShortcut(
                icon: Icons.restart_alt,
                label: 'After training',
                filters: RecipeFilters(
                  trainingTiming: TrainingTiming.postTraining,
                ),
              ),
            ),
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
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecipeLibraryScreen(initialFilters: filters),
        ),
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

  const _MealsView({required this.edgeFuel, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final eaten = edgeFuel.entries.where((entry) => entry.consumed).length;
    final quickAdds = [
      ...edgeFuel.entries.where((entry) => entry.saved),
      ...edgeFuel.recentEntries(),
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
                    entry.saved ? Icons.star : Icons.history,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  onPressed: () => edgeFuel.addEntry(
                    entry.copyWith(
                      id: 'food-${DateTime.now().microsecondsSinceEpoch}',
                      source: entry.saved
                          ? FoodLogSource.savedMeal
                          : FoodLogSource.recent,
                      consumed: true,
                      loggedAt: DateTime.now(),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Insets.lg),
        ],
        SectionHeader('Meals logged · $eaten/${edgeFuel.entries.length}'),
        if (edgeFuel.entries.isEmpty)
          const EmptyState(
            icon: Icons.restaurant_menu,
            title: 'Fresh day',
            message:
                'No entries yet. Add food manually or quick-add a recent meal.',
          ),
        for (final entry in edgeFuel.entries)
          _FoodRow(
            entry: entry,
            onToggle: () => edgeFuel.toggleEntry(entry),
            onEdit: () => onEdit(edgeFuel, existing: entry),
            onDelete: () => edgeFuel.deleteEntry(entry),
            onSaveToggle: () =>
                edgeFuel.updateEntry(entry.copyWith(saved: !entry.saved)),
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
  const _EdgeFuelEntryCard();

  @override
  Widget build(BuildContext context) {
    final edgeFuel = context.watch<EdgeFuelController>();
    final hasSetup = edgeFuel.hasCompletedSetup;
    final target = edgeFuel.target;

    return AppCard(
      accent: AppColors.premium,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => hasSetup
              ? const EdgeFuelPlanScreen()
              : const EdgeFuelSetupScreen(),
        ),
      ),
      child: Row(
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
                  'EdgeFuel AI',
                  style: AppType.subhead(weight: FontWeight.w800),
                ),
                const SizedBox(height: Insets.xxs),
                Text(
                  hasSetup && target != null && target.isSuccess
                      ? 'Your plan: ${target.targetCalories} kcal · view details'
                      : 'Get a personalized daily calorie and macro target',
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
    );
  }
}
