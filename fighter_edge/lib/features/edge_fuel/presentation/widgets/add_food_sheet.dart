import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../../theme/app_accessibility.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_haptics.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/primary_button.dart';
import '../../data/food_catalog_repository.dart';
import '../../domain/allergen_matching.dart';
import '../../domain/calculators/portion_calculator.dart';
import '../../domain/models/food_item.dart';
import '../../domain/models/food_log_entry.dart';
import '../controllers/edge_fuel_controller.dart';
import '../recipe_copy.dart';

/// What the add-food sheet ended with.
sealed class AddFoodOutcome {
  const AddFoodOutcome();
}

/// A food went into the log; the caller offers Undo.
class FoodLogged extends AddFoodOutcome {
  final FoodLogEntry entry;
  const FoodLogged(this.entry);
}

/// The athlete chose to type the macros in themselves.
class ManualEntryRequested extends AddFoodOutcome {
  const ManualEntryRequested();
}

/// The one place food gets logged from: saved and recent foods one tap away,
/// the food catalog a search away, manual entry as the fallback.
///
/// Ordered by how often each path is the right one. Most meals repeat, so
/// the foods already logged come first; search is next; typing macros by
/// hand — the only option before this sheet — is last.
Future<AddFoodOutcome?> showAddFoodSheet(
  BuildContext context, {
  required String dayLabel,
}) {
  return showModalBottomSheet<AddFoodOutcome>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: .92,
      child: AddFoodSheet(dayLabel: dayLabel),
    ),
  );
}

class AddFoodSheet extends StatefulWidget {
  final String dayLabel;
  const AddFoodSheet({super.key, required this.dayLabel});

  @override
  State<AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<AddFoodSheet> {
  final _search = TextEditingController();
  String _query = '';
  Future<List<FoodItem>>? _results;
  FoodItem? _selected;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    setState(() {
      _query = value.trim();
      _results = _query.isEmpty
          ? null
          : context.read<FoodCatalogRepository>().search(_query, limit: 30);
    });
  }

  // The entry shows on the day at once; storage confirms in the background.
  // Waiting for that confirmation froze the sheet while offline (audit A-4).
  void _logAgain(FoodLogEntry template) {
    final edgeFuel = context.read<EdgeFuelController>();
    final entry = edgeFuel.entryForLogAgain(template);
    unawaited(edgeFuel.addEntry(entry));
    Navigator.of(context).pop(FoodLogged(entry));
  }

  void _logPortion(FoodLogEntry entry) {
    unawaited(context.read<EdgeFuelController>().addEntry(entry));
    Navigator.of(context).pop(FoodLogged(entry));
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    if (selected != null) {
      return _PortionStep(
        food: selected,
        dayLabel: widget.dayLabel,
        onBack: () => setState(() => _selected = null),
        onAdd: _logPortion,
      );
    }

    final l = L.of(context);
    final edgeFuel = context.watch<EdgeFuelController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, 0),
          child: Text(l.addFoodTitle(widget.dayLabel), style: AppType.title1()),
        ),
        const SizedBox(height: Insets.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
          child: TextField(
            controller: _search,
            autofocus:
                edgeFuel.recentFoods.isEmpty && edgeFuel.savedFoods.isEmpty,
            onChanged: _onQuery,
            textInputAction: TextInputAction.search,
            style: AppType.body(),
            cursorColor: AppColors.primary,
            decoration: InputDecoration(
              hintText: l.nutritionSearchFoods,
              hintStyle:
                  AppType.body(color: AppAccessibility.textMuted(context)),
              prefixIcon: Icon(Icons.search,
                  color: AppAccessibility.textMuted(context)),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        _onQuery('');
                      },
                    ),
              filled: true,
              fillColor: AppColors.backgroundRaised,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.button),
                borderSide: BorderSide(color: AppAccessibility.border(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.button),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: Insets.md),
        Expanded(
          child: _query.isEmpty
              ? _Remembered(
                  saved: edgeFuel.savedFoods,
                  recent: edgeFuel.recentFoods,
                  onLog: _logAgain,
                )
              : _SearchResults(
                  results: _results!,
                  onPick: (food) {
                    AppHaptics.tap();
                    FocusScope.of(context).unfocus();
                    setState(() => _selected = food);
                  },
                ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: _SheetRow(
            icon: Icons.edit_note,
            title: l.addFoodManual,
            subtitle: l.addFoodManualSubtitle,
            onTap: () =>
                Navigator.of(context).pop(const ManualEntryRequested()),
          ),
        ),
      ],
    );
  }
}

class _Remembered extends StatelessWidget {
  final List<FoodLogEntry> saved;
  final List<FoodLogEntry> recent;
  final ValueChanged<FoodLogEntry> onLog;

  const _Remembered({
    required this.saved,
    required this.recent,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    if (saved.isEmpty && recent.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
        children: [
          const SizedBox(height: Insets.lg),
          Text(
            L.of(context).addFoodEmptyHint,
            style:
                AppType.callout(color: AppAccessibility.textSecondary(context)),
          ),
        ],
      );
    }
    // Saved foods are the athlete's own shortlist; anything saved is left
    // out of Recent so nothing appears twice.
    final savedKeys = {for (final s in saved) s.name.trim().toLowerCase()};
    final recentOnly = recent
        .where((r) => !savedKeys.contains(r.name.trim().toLowerCase()))
        .toList();
    return ListView(
      children: [
        if (saved.isNotEmpty) ...[
          _SectionLabel(L.of(context).addFoodSaved),
          for (final food in saved) _RememberedRow(food: food, onLog: onLog),
        ],
        if (recentOnly.isNotEmpty) ...[
          _SectionLabel(L.of(context).addFoodRecent),
          for (final food in recentOnly)
            _RememberedRow(food: food, onLog: onLog),
        ],
      ],
    );
  }
}

class _RememberedRow extends StatelessWidget {
  final FoodLogEntry food;
  final ValueChanged<FoodLogEntry> onLog;
  const _RememberedRow({required this.food, required this.onLog});

  @override
  Widget build(BuildContext context) {
    return _SheetRow(
      icon: Icons.add_circle_outline,
      title: food.name,
      subtitle: '${food.calories} kcal · ${food.proteinGrams}g protein'
          '${food.notes.isEmpty ? '' : ' · ${food.notes}'}',
      semanticHint: 'Logs it again',
      onTap: () => onLog(food),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final Future<List<FoodItem>> results;
  final ValueChanged<FoodItem> onPick;
  const _SearchResults({required this.results, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FoodItem>>(
      future: results,
      builder: (context, snapshot) {
        final foods = snapshot.data;
        if (foods == null) return const SizedBox.shrink();
        if (foods.isEmpty) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
            children: [
              const SizedBox(height: Insets.lg),
              Text(L.of(context).addFoodNotFound, style: AppType.headline()),
              const SizedBox(height: Insets.xs),
              Text(
                L.of(context).addFoodNotFoundHint,
                style: AppType.callout(
                    color: AppAccessibility.textSecondary(context)),
              ),
            ],
          );
        }
        return ListView.builder(
          itemCount: foods.length,
          itemBuilder: (_, i) {
            final food = foods[i];
            return _SheetRow(
              icon: Icons.chevron_right,
              title: food.name,
              subtitle: L.of(context).addFoodPerHundred(
                    food.kcalPer100g.round(),
                    food.proteinPer100g.toStringAsFixed(0),
                  ),
              onTap: () => onPick(food),
            );
          },
        );
      },
    );
  }
}

/// Choosing how much. Household units first when the food has them ("1
/// slice" beats "35 g" for bread), then common gram amounts, then any number.
class _PortionStep extends StatefulWidget {
  final FoodItem food;
  final String dayLabel;
  final VoidCallback onBack;
  final ValueChanged<FoodLogEntry> onAdd;

  const _PortionStep({
    required this.food,
    required this.dayLabel,
    required this.onBack,
    required this.onAdd,
  });

  @override
  State<_PortionStep> createState() => _PortionStepState();
}

class _PortionStepState extends State<_PortionStep> {
  static const _gramPresets = [50.0, 100.0, 150.0, 200.0];

  late final TextEditingController _grams;
  HouseholdUnit? _unit;
  double _unitCount = 1;

  @override
  void initState() {
    super.initState();
    final units = widget.food.householdUnits.where((u) => u.isValid);
    _unit = units.isEmpty ? null : units.first;
    _grams = TextEditingController(
      text: (_unit?.grams ?? 100).round().toString(),
    );
  }

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  double get _currentGrams => (double.tryParse(_grams.text.trim()) ?? 0)
      .clamp(0, PortionCalculator.maxGrams);

  void _setGrams(double grams, {HouseholdUnit? unit, double count = 1}) {
    AppHaptics.selection();
    setState(() {
      _unit = unit;
      _unitCount = count;
      _grams.text = grams.round().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final food = widget.food;
    final grams = _currentGrams;
    final nutrients = PortionCalculator.forGrams(food, grams);
    final secondary = AppAccessibility.textSecondary(context);
    final userAllergens = AllergenMatcher.match(
      context.read<EdgeFuelController>().draft?.allergens ?? const [],
    ).matched;
    final conflicts = food.allergens.intersection(userAllergens);
    final units = food.householdUnits.where((u) => u.isValid).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView(
            padding:
                const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.xl, Insets.lg),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back to search',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: widget.onBack,
                  ),
                  const SizedBox(width: Insets.xs),
                  Expanded(
                    child: Text(food.name, style: AppType.title2()),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: Insets.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (conflicts.isNotEmpty) ...[
                      const SizedBox(height: Insets.sm),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: IconSizes.inline, color: AppColors.warning),
                          const SizedBox(width: Insets.sm),
                          Expanded(
                            child: Text(
                              l.addFoodAllergenWarning(
                                  RecipeCopy.allergenList(conflicts)),
                              style: AppType.subhead(
                                weight: FontWeight.w700,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: Insets.lg),
                    Text(
                      l.addFoodHowMuch,
                      style: AppType.micro(
                        weight: FontWeight.w800,
                        color: AppAccessibility.textMuted(context),
                        spacing: .8,
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    Wrap(
                      spacing: Insets.sm,
                      runSpacing: Insets.sm,
                      children: [
                        for (final unit in units)
                          for (final count in const [1.0, 2.0])
                            _AmountChip(
                              label: count == 1
                                  ? unit.label
                                  : '${unit.label} ×${count.toInt()}',
                              selected: _unit == unit && _unitCount == count,
                              onTap: () => _setGrams(unit.grams * count,
                                  unit: unit, count: count),
                            ),
                        for (final g in _gramPresets)
                          _AmountChip(
                            label: '${g.toInt()} g',
                            selected: _unit == null && grams == g,
                            onTap: () => _setGrams(g),
                          ),
                      ],
                    ),
                    const SizedBox(height: Insets.md),
                    TextField(
                      controller: _grams,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      onChanged: (_) => setState(() => _unit = null),
                      style: AppType.body(),
                      cursorColor: AppColors.primary,
                      decoration: InputDecoration(
                        labelText: l.addFoodGrams,
                        suffixText: 'g',
                        labelStyle: AppType.callout(color: secondary),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.xl),
                    _NutrientSummary(nutrients: nutrients),
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.xl, Insets.sm, Insets.xl, Insets.lg),
            child: PrimaryButton(
              l.addFoodAddTo(widget.dayLabel),
              icon: Icons.add,
              expand: true,
              onPressed: grams <= 0
                  ? null
                  : () => widget.onAdd(
                        FoodLogEntry(
                          id: 'food-${DateTime.now().microsecondsSinceEpoch}',
                          name: food.name,
                          notes: PortionCalculator.label(
                            grams,
                            unitLabel: _unit?.label,
                            units: _unit == null ? null : _unitCount,
                          ),
                          calories: nutrients.calories,
                          proteinGrams: nutrients.proteinGrams,
                          carbGrams: nutrients.carbGrams,
                          fatGrams: nutrients.fatGrams,
                          source: FoodLogSource.catalog,
                          loggedAt: DateTime.now(),
                        ),
                      ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NutrientSummary extends StatelessWidget {
  final PortionNutrients nutrients;
  const _NutrientSummary({required this.nutrients});

  @override
  Widget build(BuildContext context) {
    Widget macro(String label, int grams, Color color) => Expanded(
          child: Column(
            children: [
              Text('${grams}g', style: AppType.title2(color: color)),
              Text(
                label,
                style: AppType.micro(
                  weight: FontWeight.w700,
                  color: AppAccessibility.textMuted(context),
                ),
              ),
            ],
          ),
        );

    return Semantics(
      liveRegion: true,
      label: '${nutrients.calories} calories, '
          '${nutrients.proteinGrams} grams protein, '
          '${nutrients.carbGrams} grams carbs, '
          '${nutrients.fatGrams} grams fat',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(Insets.lg),
        decoration: BoxDecoration(
          color: AppColors.backgroundRaised,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: AppAccessibility.border(context)),
        ),
        child: Column(
          children: [
            Text('${nutrients.calories} kcal', style: AppType.largeTitle()),
            const SizedBox(height: Insets.md),
            Row(
              children: [
                macro('PROTEIN', nutrients.proteinGrams, AppColors.protein),
                macro('CARBS', nutrients.carbGrams, AppColors.carbs),
                macro('FAT', nutrients.fatGrams, AppColors.fats),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AmountChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: AppType.callout(
        weight: FontWeight.w600,
        color: selected ? AppColors.textPrimary : AppColors.textSecondary,
      ),
      selectedColor: AppColors.primarySoft,
      backgroundColor: AppColors.backgroundRaised,
      side: BorderSide(
        color: selected ? AppColors.primary : AppAccessibility.border(context),
      ),
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Insets.xl, Insets.md, Insets.xl, Insets.xs),
      child: Text(
        text,
        style: AppType.micro(
          weight: FontWeight.w800,
          color: AppAccessibility.textMuted(context),
          spacing: .8,
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? semanticHint;
  final VoidCallback onTap;

  const _SheetRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.semanticHint,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      hint: semanticHint,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: AppAccessibility.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.xl, vertical: Insets.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppType.headline()),
                      const SizedBox(height: Insets.xxs),
                      Text(
                        subtitle,
                        style: AppType.subhead(
                            color: AppAccessibility.textSecondary(context)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Insets.md),
                Icon(icon, color: AppColors.accentText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
