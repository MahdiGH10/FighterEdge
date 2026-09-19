import 'package:flutter/material.dart';

import '../../../../theme/app_accessibility.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/stat_card.dart';
import '../../domain/calculators/weekly_fuel_calculator.dart';
import '../../domain/models/nutrition_day.dart';
import '../controllers/edge_fuel_controller.dart';

/// This week's fuel, day by day, against the target — the trend a single
/// day's ring can't show. Sits under the training week on the dashboard so
/// the two halves of camp read together.
class FuelWeekCard extends StatefulWidget {
  final EdgeFuelController edgeFuel;

  const FuelWeekCard({super.key, required this.edgeFuel});

  @override
  State<FuelWeekCard> createState() => _FuelWeekCardState();
}

class _FuelWeekCardState extends State<FuelWeekCard> {
  late Future<List<NutritionDay>> _week;

  @override
  void initState() {
    super.initState();
    _week = widget.edgeFuel.loadThisWeek();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.edgeFuel.target;
    if (target == null || !target.isSuccess) return const SizedBox.shrink();
    return FutureBuilder<List<NutritionDay>>(
      future: _week,
      builder: (context, snapshot) {
        final days = snapshot.data;
        if (days == null) return const SizedBox.shrink();
        final summary =
            WeeklyFuelCalculator.summarise(days: days, target: target);
        return _FuelWeekBody(summary: summary);
      },
    );
  }
}

class _FuelWeekBody extends StatelessWidget {
  final WeeklyFuelSummary summary;
  const _FuelWeekBody({required this.summary});

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  /// Bars top out at 130% of target, so "over" still reads as over without
  /// one big day flattening the rest of the week.
  static const _barCeiling = 1.3;
  static const _barHeight = Insets.xxxl + Insets.lg;

  @override
  Widget build(BuildContext context) {
    final muted = AppAccessibility.textMuted(context);
    final average = summary.averageCalories;
    final todayIndex = summary.days.length - 1;

    return Semantics(
      container: true,
      label: 'Fuel this week: ${summary.loggedDays} of 7 days logged, '
          '${summary.onTargetDays} on target, protein hit on '
          '${summary.proteinHitDays} days.',
      excludeSemantics: true,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'FUEL THIS WEEK',
                    style: AppType.micro(
                      weight: FontWeight.w800,
                      color: muted,
                      spacing: .8,
                    ),
                  ),
                ),
                Text(
                  '${summary.loggedDays}/7 logged',
                  style: AppType.subhead(
                    weight: FontWeight.w700,
                    color: AppAccessibility.textSecondary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++) ...[
                  Expanded(
                    child: _DayBar(
                      day: i < summary.days.length ? summary.days[i] : null,
                      target: summary.targetCalories,
                      letter: _letters[i],
                      isToday: i == todayIndex,
                    ),
                  ),
                  if (i < 6) const SizedBox(width: Insets.sm),
                ],
              ],
            ),
            const SizedBox(height: Insets.lg),
            if (summary.loggedDays == 0)
              Text(
                'Log meals this week and your fuel trend builds here, day '
                'by day against your target.',
                style: AppType.subhead(
                    color: AppAccessibility.textSecondary(context)),
              )
            else
              Row(
                children: [
                  _WeekStat(
                    value: '${summary.onTargetDays}',
                    label: 'on target',
                    color: AppColors.positive,
                  ),
                  _WeekStat(
                    value: '${summary.proteinHitDays}',
                    label: 'protein hit',
                    color: AppColors.protein,
                  ),
                  _WeekStat(
                    value: average == null ? '—' : '$average',
                    label: 'avg kcal',
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  final FuelDaySummary? day;
  final int target;
  final String letter;
  final bool isToday;

  const _DayBar({
    required this.day,
    required this.target,
    required this.letter,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final d = day;
    final fraction = d == null || target <= 0
        ? 0.0
        : (d.calories / target / _FuelWeekBody._barCeiling).clamp(0.0, 1.0);
    final color = switch (d?.status) {
      FuelDayStatus.onTarget => AppColors.positive,
      FuelDayStatus.over => AppColors.negative,
      FuelDayStatus.under => AppColors.warning,
      _ => AppColors.track,
    };
    // Where 100% of target sits on the bar.
    const targetLine = 1 / _FuelWeekBody._barCeiling;

    return Column(
      children: [
        SizedBox(
          height: _FuelWeekBody._barHeight,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.track,
                  borderRadius: BorderRadius.circular(Insets.xs),
                ),
              ),
              FractionallySizedBox(
                heightFactor: fraction,
                widthFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(Insets.xs),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: _FuelWeekBody._barHeight * targetLine,
                child: Container(
                  height: Insets.xxs / 2,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.xs),
        Text(
          letter,
          style: AppType.micro(
            weight: FontWeight.w700,
            color: isToday
                ? AppColors.accentText
                : AppAccessibility.textMuted(context),
          ),
        ),
      ],
    );
  }
}

class _WeekStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _WeekStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppType.title1(color: color)),
          Text(
            label,
            style:
                AppType.subhead(color: AppAccessibility.textSecondary(context)),
          ),
        ],
      ),
    );
  }
}
