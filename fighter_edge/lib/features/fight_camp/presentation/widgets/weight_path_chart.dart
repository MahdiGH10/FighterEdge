import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../models/weight_entry.dart';
import '../../../../theme/app_accessibility.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/calendar.dart';
import '../../domain/weight_path.dart';
import '../../domain/weight_trend.dart';
import '../fight_camp_controller.dart';
import '../fight_camp_copy.dart';

/// The last four weeks and the plan to fight week on one date axis
/// (pattern brief, pattern 4): single weigh-ins faint, the 7-day trend
/// solid, the planned path dashed, the limit flat. Screen readers get the
/// same facts from [WeightPathSummary], so the drawing itself is hidden.
class WeightPathChart extends StatelessWidget {
  final FightCampStatus status;
  final List<WeightEntry> weights;
  final DateTime today;
  final FightCampCopy copy;

  const WeightPathChart({
    super.key,
    required this.status,
    required this.weights,
    required this.today,
    required this.copy,
  });

  static const int pastDays = 28;

  /// The plan's colour carries its status; no plan is drawn otherwise.
  static Color? planColorFor(WeightPath path) => switch (path.status) {
        WeightPathStatus.onTrack => AppColors.positive,
        WeightPathStatus.needsSupervision => AppColors.warning,
        _ => null,
      };

  Color? get _planColor => planColorFor(status.path);

  bool get hasPlan => _planColor != null && status.path.checkpoints.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l = copy.l;
    final day0 = calendarDay(today);
    final start = addDays(day0, -(pastDays - 1));
    final points = [
      for (final w in weights)
        if (daysBetween(start, w.date) >= 0 && daysBetween(w.date, day0) >= 0)
          WeightPoint(calendarDay(w.date), w.kg),
    ];
    if (points.length < 2) {
      return Center(
        child: Text(
          l.fightChartEmpty,
          textAlign: TextAlign.center,
          style: AppType.subhead(color: AppAccessibility.textMuted(context)),
        ),
      );
    }

    double x(DateTime date) => daysBetween(start, date).toDouble();
    double y(double kg) => copy.units.displayWeight(kg);

    final trend = {
      for (final p in WeightTrend.series(points, from: start, to: day0))
        daysBetween(start, p.date): p.kg,
    };
    final trendSpots = [
      for (var d = 0; d <= x(day0); d++)
        trend[d] == null ? FlSpot.nullSpot : FlSpot(d.toDouble(), y(trend[d]!)),
    ];
    final checkpoints = status.path.checkpoints;
    final planSpots = hasPlan && trend[x(day0).toInt()] != null
        ? [
            FlSpot(x(day0), y(trend[x(day0).toInt()]!)),
            for (final c in checkpoints) FlSpot(x(c.date), y(c.weightKg)),
          ]
        : const <FlSpot>[];
    final endX = math.max(
      x(day0),
      planSpots.isEmpty ? x(day0) : planSpots.last.x,
    );
    final limit = y(status.camp.weightLimitKg);
    final values = [
      for (final p in points) y(p.kg),
      for (final s in planSpots) s.y,
      limit,
    ];
    // Whole-number steps, with both ends on a step, so no two axis labels
    // land on top of each other.
    final low = values.reduce(math.min) - 1;
    final high = values.reduce(math.max) + 1;
    final interval = math.max(1, ((high - low) / 4).ceil()).toDouble();
    final minY = (low / interval).floorToDouble() * interval;
    final maxY = (high / interval).ceilToDouble() * interval;
    final labelled = {0, x(day0).toInt(), endX.toInt()};
    final muted = AppAccessibility.textMuted(context);

    String dateLabel(int d) => d == x(day0).toInt()
        ? l.fightChartToday
        : copy.shortDate(addDays(start, d));

    return ExcludeSemantics(
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: endX,
          minY: minY,
          maxY: maxY,
          lineTouchData: const LineTouchData(enabled: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => const FlLine(
                color: AppColors.border, strokeWidth: Insets.hairline),
          ),
          borderData: FlBorderData(show: false),
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
                  final d = v.round();
                  if ((v - d).abs() > 0.01 || !labelled.contains(d)) {
                    return const SizedBox.shrink();
                  }
                  // Kept inside the chart, so the last date is never cut
                  // off at the card's edge.
                  return SideTitleWidget(
                    meta: meta,
                    space: Insets.xs,
                    fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                    child:
                        Text(dateLabel(d), style: AppType.micro(color: muted)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            // Single weigh-ins: dots only, behind the trend.
            LineChartBarData(
              spots: [for (final p in points) FlSpot(x(p.date), y(p.kg))],
              barWidth: 0,
              color: AppColors.transparent,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: ChartTokens.faintDot,
                  color: muted,
                  strokeWidth: 0,
                ),
              ),
            ),
            LineChartBarData(
              spots: trendSpots,
              isCurved: true,
              curveSmoothness: 0.2,
              preventCurveOverShooting: true,
              color: AppColors.primary,
              barWidth: ChartTokens.line,
              dotData: const FlDotData(show: false),
            ),
            if (planSpots.isNotEmpty)
              LineChartBarData(
                spots: planSpots,
                color: _planColor,
                barWidth: ChartTokens.guide,
                dashArray: ChartTokens.dash,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: ChartTokens.faintDot,
                    color: _planColor!,
                    strokeWidth: 0,
                  ),
                ),
              ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: limit,
                color: AppAccessibility.textSecondary(context),
                strokeWidth: ChartTokens.guide,
                dashArray: ChartTokens.dash,
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: AppType.micro(
                      weight: FontWeight.w700,
                      color: AppAccessibility.textSecondary(context)),
                  labelResolver: (_) =>
                      l.fightChartLimit(copy.weight(status.camp.weightLimitKg)),
                ),
              ),
            ],
            verticalLines: [
              if (endX > x(day0))
                VerticalLine(
                  x: x(day0),
                  color: AppColors.border,
                  strokeWidth: Insets.hairline,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What each mark means, under the chart.
class WeightPathLegend extends StatelessWidget {
  final bool showPlan;
  final Color? planColor;
  final FightCampCopy copy;

  const WeightPathLegend({
    super.key,
    required this.showPlan,
    required this.planColor,
    required this.copy,
  });

  @override
  Widget build(BuildContext context) {
    final l = copy.l;
    final muted = AppAccessibility.textMuted(context);
    Widget item(Widget swatch, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch,
            const SizedBox(width: Insets.xs),
            Text(label,
                style: AppType.subhead(
                    color: AppAccessibility.textSecondary(context))),
          ],
        );
    Widget line(Color color, double height) => Container(
          width: IconSizes.small,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
        );
    return Wrap(
      spacing: Insets.lg,
      runSpacing: Insets.xs,
      children: [
        item(
          Container(
            width: ChartTokens.faintDot * 2,
            height: ChartTokens.faintDot * 2,
            decoration: BoxDecoration(color: muted, shape: BoxShape.circle),
          ),
          l.fightChartWeighIns,
        ),
        item(line(AppColors.primary, ChartTokens.line), l.fightChartTrend),
        if (showPlan && planColor != null)
          item(line(planColor!, ChartTokens.guide), l.fightChartPlan),
      ],
    );
  }
}
