import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../features/edge_fuel/presentation/screens/edge_fuel_setup_screen.dart';
import '../models/weight_entry.dart';
import '../routing/app_navigation.dart';
import '../routing/app_router.dart';
import '../state/app_state.dart';
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
      title: 'Weight Tracker',
      showBack: true,
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () => _addWeighIn(context, state),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
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
    // Typed in the user's unit, stored in kg.
    final controller = TextEditingController(
      text: state.latestWeight == 0
          ? ''
          : state.displayWeight(state.latestWeight).toStringAsFixed(1),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Add Weigh-In', style: AppType.title2()),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppType.body(),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            suffixText: state.weightUnitLabel,
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppType.callout(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              ctx,
              double.tryParse(controller.text.trim().replaceAll(',', '.')),
            ),
            child: Text('Save',
                style: AppType.callout(
                    weight: FontWeight.w700, color: AppColors.accentText)),
          ),
        ],
      ),
    );
    if (value != null && value > 0) {
      state.addWeight(DateTime.now(), state.weightToKg(value));
      AppHaptics.commit();
    }
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

  String _fmt(double kg) => state.displayWeight(kg).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    // Read once: the getter is O(n) per call (audit P-4), and the history
    // list below used to call it twice per row inside its loop.
    final history = state.weightHistoryDesc;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, 80),
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
                        text: _fmt(state.latestWeight),
                        style: AppType.display(),
                        // Counts when a new weigh-in lands; static otherwise.
                        child: AnimatedCount(
                          value: state.displayWeight(state.latestWeight),
                          formatter: (v) => v.toStringAsFixed(1),
                          style: AppType.display(),
                        ),
                      ),
                    const SizedBox(width: Insets.xs),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(state.weightUnitLabel,
                          style: AppType.body(
                              weight: FontWeight.w600,
                              color: AppColors.textMuted)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(losing ? Icons.arrow_downward : Icons.arrow_upward,
                      size: 14,
                      color: losing ? AppColors.positive : AppColors.primary),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                        '${_fmt(delta.abs())} ${state.weightUnitLabel} '
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
          ),
        ),
        const SizedBox(height: Insets.xl),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: '7-day avg',
                value: _fmt(state.sevenDayAverage),
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
            height: 200,
            child: _WeightChart(state: state, goalKg: goalKg),
          ),
        ),
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
                  display: _fmt(history[i].kg),
                  unit: state.weightUnitLabel,
                ),
              ],
            ],
          ),
        ),
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
            style: AppType.subhead(color: AppColors.textMuted)),
      );
    }
    final spots = <FlSpot>[
      for (int i = 0; i < entries.length; i++)
        FlSpot(i.toDouble(), state.displayWeight(entries[i].kg)),
    ];
    final values = [for (final spot in spots) spot.y, if (goal != null) goal];
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minY = (minValue - 1).floorToDouble();
    final maxY = (maxValue + 1).ceilToDouble();

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxY - minY) / 4).clamp(0.5, 100),
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: ((maxY - minY) / 4).clamp(0.5, 100),
              getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0),
                  style: AppType.micro(color: AppColors.textMuted)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox();
                // Show a few labels to avoid crowding.
                if (entries.length > 6 && i % 2 != 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(DateFormat('M/d').format(entries[i].date),
                      style: AppType.micro(color: AppColors.textMuted)),
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
            curveSmoothness: 0.3,
            color: AppColors.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3.5,
                color: AppColors.primary,
                strokeWidth: 2,
                strokeColor: AppColors.background,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.25),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (goal != null)
              HorizontalLine(
                y: goal,
                color: AppColors.warning.withValues(alpha: .82),
                strokeWidth: 1.5,
                dashArray: [6, 5],
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
          horizontal: Insets.lg, vertical: Insets.md + 2),
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
    return StatCard(
      label: 'Goal gap',
      value: state.displayWeight(gap.abs()).toStringAsFixed(1),
      unit: unit,
      delta: atGoal
          ? 'At goal'
          : 'To ${state.displayWeight(goal).toStringAsFixed(1)} $unit',
      deltaColor: atGoal ? AppColors.positive : AppColors.warning,
      deltaIcon: atGoal ? Icons.check_circle : Icons.flag_outlined,
    );
  }
}
