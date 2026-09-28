import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../features/edge_fuel/presentation/screens/edge_fuel_setup_screen.dart';
import '../l10n/decimal_format.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/weight_entry.dart';
import '../routing/app_navigation.dart';
import '../routing/app_router.dart';
import '../state/app_state.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_haptics.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/animated_count.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_chips.dart';
import '../widgets/number_hero.dart';
import '../widgets/stat_card.dart';

/// Shared with the dashboard's weight card, so the current weight flies here.
const weightHeroTag = 'weight-current';

class WeightTrackerScreen extends StatefulWidget {
  const WeightTrackerScreen({super.key});

  @override
  State<WeightTrackerScreen> createState() => _WeightTrackerScreenState();
}

class _WeightTrackerScreenState extends State<WeightTrackerScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // The goal is the target weight the user set in EdgeFuel. There is no
    // other source of truth for it, so without one there is no goal to show.
    final goalKg = context.watch<EdgeFuelController>().draft?.targetWeightKg;
    final delta = state.weeklyDelta;
    final losing = delta <= 0;

    return ScreenScaffold(
      title: 'Weight tracker',
      showBack: true,
      // A header action, like Nutrition's "Add food", rather than a stock
      // floating button hovering over the history list.
      actions: [
        if (_tab == 0)
          HeaderIcon(
            Icons.add,
            label: L.of(context).weightAddWeighIn,
            onTap: () => _addWeighIn(context, state),
          ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: FilterChips(
              options: const ['Weight', 'Body Fat', 'Measurements'],
              selectedIndex: _tab,
              onSelected: (i) => setState(() => _tab = i),
              // Sized to their labels, so "Measurements" is never cut to
              // "Measure…"; at large text the row scrolls with an edge fade.
            ),
          ),
          const SizedBox(height: Insets.xl),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _WeightView(
                  state: state,
                  delta: delta,
                  losing: losing,
                  goalKg: goalKg,
                ),
                const EmptyState(
                  icon: Icons.percent,
                  title: 'Body Fat',
                  message:
                      'Log a body-fat measurement to start\ntracking your composition trend.',
                ),
                const EmptyState(
                  icon: Icons.straighten,
                  title: 'Measurements',
                  message:
                      'Track chest, waist, arms and more\nto see where the weight is moving.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addWeighIn(BuildContext context, AppState state) async {
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _WeighInDialog(state: state),
    );
    if (value != null) {
      state.addWeight(DateTime.now(), state.weightToKg(value));
      AppHaptics.commit();
    }
  }
}

/// The realistic weigh-in range, in kg. Same limits the onboarding form
/// enforces, so the tracker cannot be fed what setup would have refused.
const double _minWeighInKg = 35;
const double _maxWeighInKg = 220;

/// Owns its controller, so it is disposed with the dialog, after the exit
/// animation. Typed in the user's unit; the caller converts to kg.
class _WeighInDialog extends StatefulWidget {
  final AppState state;
  const _WeighInDialog({required this.state});

  @override
  State<_WeighInDialog> createState() => _WeighInDialogState();
}

class _WeighInDialogState extends State<_WeighInDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Localizations is not reachable until dependencies are wired up, so
    // the locale-formatted pre-fill happens here, not in initState; the
    // flag keeps a later dependency change from overwriting a typed edit.
    final s = widget.state;
    if (!_prefilled && s.latestWeight != 0) {
      _prefilled = true;
      _controller.text = formatFixedDecimal(s.displayWeight(s.latestWeight),
          Localizations.localeOf(context).toString());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final s = widget.state;
    final value = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    final kg = value == null ? null : s.weightToKg(value);
    if (kg == null || kg < _minWeighInKg || kg > _maxWeighInKg) {
      final lo = s.displayWeight(_minWeighInKg).round();
      final hi = s.displayWeight(_maxWeighInKg).round();
      setState(() =>
          _error = 'Enter a weight from $lo to $hi ${s.weightUnitLabel}.');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return AlertDialog(
      title: Text('Add Weigh-In', style: AppType.title2()),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          LengthLimitingTextInputFormatter(6),
        ],
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _save(),
        style: AppType.body(),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          labelText: l.weightFieldLabel,
          suffixText: widget.state.weightUnitLabel,
          errorText: _error,
          errorMaxLines: 2,
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: AppType.callout(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: _save,
          child: Text('Save',
              style: AppType.callout(
                  weight: FontWeight.w700, color: AppColors.accentText)),
        ),
      ],
    );
  }
}

/// Tab 0 — current weight, trend chart, and weigh-in history.
class _WeightView extends StatelessWidget {
  final AppState state;
  final double delta;
  final bool losing;
  final double? goalKg;
  const _WeightView({
    required this.state,
    required this.delta,
    required this.losing,
    required this.goalKg,
  });

  String _fmt(double kg, String locale) =>
      formatFixedDecimal(state.displayWeight(kg), locale);

  @override
  Widget build(BuildContext context) {
    // Read once: the getter is O(n) per call (audit P-4), and the history
    // list below used to call it twice per row inside its loop.
    final history = state.weightHistoryDesc;
    final locale = Localizations.localeOf(context).toString();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Insets.lg, Insets.none, Insets.lg, Insets.bottomClearance),
      children: [
        Center(
          child: Column(
            children: [
              // The hero number shrinks to fit rather than overflowing at
              // large text sizes.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (state.latestWeight == 0)
                      Text('—', style: AppType.display())
                    else
                      NumberHero(
                        tag: weightHeroTag,
                        text: _fmt(state.latestWeight, locale),
                        style: AppType.display(),
                        // Counts when a new weigh-in lands; static otherwise.
                        child: AnimatedCount(
                          value: state.displayWeight(state.latestWeight),
                          formatter: (v) => formatFixedDecimal(v, locale),
                          style: AppType.display(),
                        ),
                      ),
                    const SizedBox(width: Insets.xs),
                    Padding(
                      padding: const EdgeInsets.only(bottom: Insets.sm),
                      child: Text(state.weightUnitLabel,
                          style: AppType.body(
                              weight: FontWeight.w600,
                              color: AppColors.textMuted)),
                    ),
                  ],
                ),
              ),
              // A change needs something to compare with: at least two
              // weigh-ins, never a fabricated 0.0.
              if (state.weights.length >= 2) ...[
                const SizedBox(height: Insets.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(losing ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 14,
                        color: losing ? AppColors.positive : AppColors.primary),
                    const SizedBox(width: Insets.xs),
                    Flexible(
                      child: Text(
                          '${_fmt(delta.abs(), locale)} ${state.weightUnitLabel} '
                          'vs last weigh-in',
                          textAlign: TextAlign.center,
                          style: AppType.subhead(
                              weight: FontWeight.w600,
                              color: losing
                                  ? AppColors.positive
                                  : AppColors.primary)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Insets.xl),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: '7-day avg',
                value: state.weights.isEmpty
                    ? '—'
                    : _fmt(state.sevenDayAverage, locale),
                unit: state.weightUnitLabel,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(child: _GoalCard(state: state, goalKg: goalKg)),
          ],
        ),
        const SizedBox(height: Insets.xl),
        AppCard(
          child: SizedBox(
            height: LayoutTokens.weightChart,
            child: _WeightChart(state: state, goalKg: goalKg),
          ),
        ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: Insets.xl),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < history.length; i++) ...[
                  if (i > 0)
                    const Divider(
                        height: 1, thickness: 1, color: AppColors.border),
                  _HistoryRow(
                    entry: history[i],
                    display: _fmt(history[i].kg, locale),
                    unit: state.weightUnitLabel,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _WeightChart extends StatelessWidget {
  final AppState state;
  final double? goalKg;
  const _WeightChart({required this.state, required this.goalKg});

  @override
  Widget build(BuildContext context) {
    final entries = state.weights;
    final goal = goalKg == null ? null : state.displayWeight(goalKg!);
    if (entries.length < 2) {
      return Center(
        child: Text('Add more weigh-ins to see a trend',
            style: AppType.subhead(color: AppAccessibility.textMuted(context))),
      );
    }
    final spots = <FlSpot>[
      for (int i = 0; i < entries.length; i++)
        FlSpot(i.toDouble(), state.displayWeight(entries[i].kg)),
    ];
    final values = [for (final spot in spots) spot.y, if (goal != null) goal];
    // Whole-number steps, with both ends on a step, so no two axis labels
    // land on top of each other (same fix as the fight-camp weight chart).
    final low = values.reduce(math.min) - 1;
    final high = values.reduce(math.max) + 1;
    final interval = math.max(1, ((high - low) / 4).ceil()).toDouble();
    final minY = (low / interval).floorToDouble() * interval;
    final maxY = (high / interval).ceilToDouble() * interval;
    final muted = AppAccessibility.textMuted(context);
    // A handful of evenly spaced labels regardless of how many weigh-ins
    // there are: "every other" still crowded three weeks of daily entries
    // into unreadable overlap, where a few widely spaced dates read fine.
    final labelCount = math.min(entries.length, 4);
    final labelled = <int>{
      for (var k = 0; k < labelCount; k++)
        (k * (entries.length - 1) / math.max(1, labelCount - 1)).round(),
    };

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.border, strokeWidth: Insets.hairline),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: ChartTokens.valueAxis,
              interval: interval,
              getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0),
                  style: AppType.micro(color: muted)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: ChartTokens.dateAxis,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length || !labelled.contains(i)) {
                  return const SizedBox();
                }
                // Kept inside the chart, so the last date is never cut off
                // at the card's edge.
                return SideTitleWidget(
                  meta: meta,
                  space: Insets.xs,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(DateFormat('M/d').format(entries[i].date),
                      style: AppType.micro(color: muted)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: AppColors.primary,
            barWidth: ChartTokens.line,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: ChartTokens.dot,
                color: AppColors.primary,
                strokeWidth: 0,
              ),
            ),
          ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (goal != null)
              HorizontalLine(
                y: goal,
                color: AppColors.warning,
                strokeWidth: ChartTokens.guide,
                dashArray: ChartTokens.dash,
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: AppType.micro(
                      weight: FontWeight.w700, color: AppColors.warning),
                  labelResolver: (_) => 'Goal ${goal.toStringAsFixed(0)}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final WeightEntry entry;
  final String display;
  final String unit;
  const _HistoryRow({
    required this.entry,
    required this.display,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg, vertical: Insets.md + Insets.xxs),
      child: Row(
        children: [
          // The date takes the leftover space and wraps at large text; the
          // weight is short, so it keeps its size, flush right.
          Expanded(
            child: Text(DateFormat('MMM d, yyyy').format(entry.date),
                style: AppType.callout(
                    weight: FontWeight.w500, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: Insets.md),
          Text('$display $unit',
              style: AppType.callout(weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Distance to the EdgeFuel target weight — or, with no target set, the way
/// to set one rather than a made-up number.
class _GoalCard extends StatelessWidget {
  final AppState state;
  final double? goalKg;
  const _GoalCard({required this.state, required this.goalKg});

  @override
  Widget build(BuildContext context) {
    final goal = goalKg;
    if (goal == null || state.latestWeight == 0) {
      return StatCard(
        label: 'Goal',
        value: '—',
        delta: 'Set in EdgeFuel',
        deltaColor: AppColors.accentText,
        deltaIcon: Icons.flag_outlined,
        onTap: () => AppNavigation.push(
          context,
          AppRoutes.fuelSetup,
          fallbackBuilder: (_) => const EdgeFuelSetupScreen(),
        ),
      );
    }
    final gap = state.latestWeight - goal;
    // Within a tenth of the unit counts as there; a scale is not that precise.
    final atGoal = state.displayWeight(gap.abs()) < 0.1;
    final unit = state.weightUnitLabel;
    final locale = Localizations.localeOf(context).toString();
    return StatCard(
      label: 'Goal gap',
      value: formatFixedDecimal(state.displayWeight(gap.abs()), locale),
      unit: unit,
      delta: atGoal
          ? 'At goal'
          : 'To ${formatFixedDecimal(state.displayWeight(goal), locale)} $unit',
      deltaColor: atGoal ? AppColors.positive : AppColors.warning,
      deltaIcon: atGoal ? Icons.check_circle : Icons.flag_outlined,
    );
  }
}
