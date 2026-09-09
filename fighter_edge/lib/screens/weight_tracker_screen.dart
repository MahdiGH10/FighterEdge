import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/weight_entry.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_chips.dart';
import '../widgets/stat_card.dart';

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
              scrollable: false,
            ),
          ),
          const SizedBox(height: Insets.xl),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _WeightView(state: state, delta: delta, losing: losing),
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
    final controller =
        TextEditingController(text: state.latestWeight.toStringAsFixed(1));
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Add Weigh-In', style: AppTheme.display(18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppTheme.body(16),
          cursorColor: AppColors.primary,
          decoration: const InputDecoration(
            suffixText: 'kg',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTheme.body(14, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text.trim())),
            child: Text('Save',
                style: AppTheme.body(14,
                    weight: FontWeight.w700, color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (value != null && value > 0) {
      state.addWeight(DateTime.now(), value);
    }
  }
}

/// Tab 0 — current weight, trend chart, and weigh-in history.
class _WeightView extends StatelessWidget {
  final AppState state;
  final double delta;
  final bool losing;
  const _WeightView(
      {required this.state, required this.delta, required this.losing});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, 80),
      children: [
        Center(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(state.latestWeight.toStringAsFixed(1),
                      style: AppTheme.display(52)),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('kg',
                        style: AppTheme.body(16,
                            weight: FontWeight.w600,
                            color: AppColors.textMuted)),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(losing ? Icons.arrow_downward : Icons.arrow_upward,
                      size: 14,
                      color: losing ? AppColors.positive : AppColors.primary),
                  const SizedBox(width: 3),
                  Text('${delta.abs().toStringAsFixed(1)} kg vs last weigh-in',
                      style: AppTheme.body(13,
                          weight: FontWeight.w600,
                          color:
                              losing ? AppColors.positive : AppColors.primary)),
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
                value: state.sevenDayAverage.toStringAsFixed(1),
                unit: 'kg',
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: StatCard(
                label: 'Goal gap',
                value: state.weightToGoal.abs().toStringAsFixed(1),
                unit: 'kg',
                delta: state.weightToGoal <= 0 ? 'At goal' : 'To 74 kg',
                deltaColor: state.weightToGoal <= 0
                    ? AppColors.positive
                    : AppColors.warning,
                deltaIcon: state.weightToGoal <= 0
                    ? Icons.check_circle
                    : Icons.flag_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.xl),
        AppCard(
          child: SizedBox(
            height: 200,
            child: _WeightChart(
              entries: state.weights,
              goalWeightKg: state.goalWeightKg,
            ),
          ),
        ),
        const SizedBox(height: Insets.xl),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < state.weightHistoryDesc.length; i++) ...[
                if (i > 0)
                  const Divider(
                      height: 1, thickness: 1, color: AppColors.border),
                _HistoryRow(state.weightHistoryDesc[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WeightChart extends StatelessWidget {
  final List<WeightEntry> entries;
  final double goalWeightKg;
  const _WeightChart({required this.entries, required this.goalWeightKg});

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) {
      return Center(
        child: Text('Add more weigh-ins to see a trend',
            style: AppTheme.body(13, color: AppColors.textMuted)),
      );
    }
    final spots = <FlSpot>[
      for (int i = 0; i < entries.length; i++)
        FlSpot(i.toDouble(), entries[i].kg),
    ];
    final values = entries.map((e) => e.kg).toList();
    final minValue = [...values, goalWeightKg].reduce((a, b) => a < b ? a : b);
    final maxValue = [...values, goalWeightKg].reduce((a, b) => a > b ? a : b);
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
                  style: AppTheme.body(10, color: AppColors.textMuted)),
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
                      style: AppTheme.body(9, color: AppColors.textMuted)),
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
            HorizontalLine(
              y: goalWeightKg,
              color: AppColors.warning.withValues(alpha: .82),
              strokeWidth: 1.5,
              dashArray: [6, 5],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: AppTheme.body(10,
                    weight: FontWeight.w700, color: AppColors.warning),
                labelResolver: (_) => 'Goal ${goalWeightKg.toStringAsFixed(0)}',
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
  const _HistoryRow(this.entry);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg, vertical: Insets.md + 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(DateFormat('MMM d, yyyy').format(entry.date),
              style: AppTheme.body(14,
                  weight: FontWeight.w500, color: AppColors.textSecondary)),
          Text('${entry.kg.toStringAsFixed(1)} kg',
              style: AppTheme.body(15, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}
