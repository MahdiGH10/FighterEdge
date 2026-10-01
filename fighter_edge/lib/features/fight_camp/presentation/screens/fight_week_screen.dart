import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_icons.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../../state/app_state.dart';
import '../../../../theme/app_accessibility.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_scaffold.dart';
import '../../../../widgets/grouped_list.dart';
import '../../../../widgets/primary_button.dart';
import '../../../../widgets/stat_card.dart';
import '../../../edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../../domain/calendar.dart';
import '../../domain/fight_camp.dart';
import '../../domain/fight_week_plan.dart';
import '../../domain/weight_path.dart';
import '../../domain/weight_trend.dart';
import '../fight_camp_controller.dart';
import '../fight_camp_copy.dart';
import '../camp_screening_from_draft.dart';
import '../widgets/fight_countdown_card.dart';
import '../widgets/weight_path_summary.dart';

/// Fight week, day by day (pattern brief, screen D): what today asks for,
/// every day to the fight, and the refuel after the weigh-in. Food only; the
/// water line is stated, never hidden.
class FightWeekScreen extends StatelessWidget {
  const FightWeekScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final state = context.watch<AppState>();
    final camp = context.watch<FightCampController>().camp;
    final copy =
        FightCampCopy(l, state, Localizations.localeOf(context).toString());

    if (camp == null) {
      return ScreenScaffold(
        title: l.fightWeekTitle,
        showBack: true,
        body: const Padding(
          padding: EdgeInsets.symmetric(horizontal: Insets.lg),
          child: Column(children: [AddFightRow()]),
        ),
      );
    }

    final today = state.now;
    final fuelDraft = context.watch<EdgeFuelController>().draft;
    final ageYears = fuelDraft?.ageYears;
    final screening = campScreeningFromDraft(fuelDraft);
    final plan = FightWeekPlan.plan(
      camp: camp,
      weights: [for (final w in state.weights) WeightPoint(w.date, w.kg)],
      today: today,
      ageYears: ageYears,
      screening: screening,
    );
    final status = FightCampStatus.of(camp,
        weights: state.weights,
        today: today,
        ageYears: ageYears,
        screening: screening);
    final inWeek =
        status.phase == CampPhase.fightWeek || status.phase == CampPhase.refuel;
    final todayPlan = plan?.dayOn(today);

    return ScreenScaffold(
      title: l.fightWeekTitle,
      showBack: true,
      actions: [
        HeaderIcon(
          AppIcons.pencilSimple,
          label: l.fightEdit,
          onTap: () => openFightSetup(context),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.lg, Insets.none, Insets.lg, Insets.xxl),
        children: [
          Text(
            '${l.fightWeekWeighIn(copy.date(camp.weighInDate))} · '
            '${inWeek ? copy.phaseLine(status, today) : l.fightWeekStarts(copy.date(camp.fightWeekStart))}',
            style:
                AppType.subhead(color: AppAccessibility.textSecondary(context)),
          ),
          const SizedBox(height: Insets.md),
          if (plan == null)
            _PlanMessage(status: status.path.status, copy: copy)
          else ...[
            _PlanMessage(status: plan.status, copy: copy, plan: plan),
            if (todayPlan != null && todayPlan.steps.isNotEmpty) ...[
              const SizedBox(height: Insets.xl),
              Text('${l.fightWeekToday} · ${copy.date(today)}',
                  style: AppType.headline()),
              const SizedBox(height: Insets.md),
              _TodayCard(day: todayPlan, copy: copy),
            ],
            const SizedBox(height: Insets.xl),
            Text(l.fightWeekDays, style: AppType.headline()),
            const SizedBox(height: Insets.md),
            GroupedList(children: [
              for (final day in plan.days)
                _DayRow(day: day, today: today, copy: copy),
            ]),
            if (plan.refuel case final refuel?) ...[
              const SizedBox(height: Insets.xl),
              Text(l.fightRefuelTitle, style: AppType.headline()),
              const SizedBox(height: Insets.md),
              _RefuelTargets(refuel: refuel, copy: copy),
            ],
            const SizedBox(height: Insets.md),
            Text(
              l.fightWeekSource,
              style:
                  AppType.subhead(color: AppAccessibility.textMuted(context)),
            ),
          ],
          if (status.path.status == WeightPathStatus.needsScreening) ...[
            const SizedBox(height: Insets.md),
            PrimaryButton(
              l.fightPathStartScreening,
              icon: Icons.arrow_forward,
              expand: true,
              onPressed: () => openCampScreening(context),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the week asks for, then the water line. The status tone matches
/// the weight path, so a warning reads the same on both screens.
class _PlanMessage extends StatelessWidget {
  final WeightPathStatus status;
  final FightCampCopy copy;
  final FightWeekPlan? plan;

  const _PlanMessage({required this.status, required this.copy, this.plan});

  @override
  Widget build(BuildContext context) {
    final plan = this.plan;
    final (tone, icon) = pathStatusStyle(context, status);
    final message = plan == null
        ? copy.pathMessageForStatus(status)
        : copy.fightWeekMessage(plan);
    final warning = status == WeightPathStatus.needsSupervision ||
        status == WeightPathStatus.needsProfessionalReview ||
        status == WeightPathStatus.notSafe;
    return AppCard(
      accent: warning ? tone : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _IconLine(icon: icon, color: tone, text: message, liveRegion: true),
          if (plan != null) ...[
            const SizedBox(height: Insets.md),
            _IconLine(
              icon: AppIcons.drop,
              color: AppAccessibility.textSecondary(context),
              text: copy.l.fightWeekWater,
            ),
          ],
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final bool liveRegion;

  const _IconLine({
    required this.icon,
    required this.color,
    required this.text,
    this.liveRegion = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: liveRegion,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
              child: Icon(icon, size: IconSizes.row, color: color)),
          const SizedBox(width: Insets.sm),
          Expanded(child: Text(text, style: AppType.callout())),
        ],
      ),
    );
  }
}

IconData _stepIcon(FightWeekStep step) => switch (step) {
      FightWeekStep.eatToPlan => AppIcons.forkKnife,
      FightWeekStep.lowFibre => AppIcons.bowlFood,
      FightWeekStep.lowerCarbs => AppIcons.bread,
      FightWeekStep.weighIn => AppIcons.scales,
      FightWeekStep.refuel => AppIcons.drop,
      FightWeekStep.fight => AppIcons.boxingGlove,
    };

/// Today's steps in full, in the order they happen (pattern 3).
class _TodayCard extends StatelessWidget {
  final FightWeekDay day;
  final FightCampCopy copy;

  const _TodayCard({required this.day, required this.copy});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, step) in day.steps.indexed) ...[
            if (i > 0) const SizedBox(height: Insets.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(_stepIcon(step),
                      size: IconSizes.row,
                      color: AppAccessibility.accentText(context)),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(copy.stepTitle(step),
                          style: AppType.callout(weight: FontWeight.w600)),
                      const SizedBox(height: Insets.xxs),
                      Text(copy.stepBody(step),
                          style: AppType.subhead(
                              color: AppAccessibility.textSecondary(context))),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One row per day: past days ticked, today marked, weigh-in and fight
/// with their own glyphs (pattern 3).
class _DayRow extends StatelessWidget {
  final FightWeekDay day;
  final DateTime today;
  final FightCampCopy copy;

  const _DayRow({required this.day, required this.today, required this.copy});

  @override
  Widget build(BuildContext context) {
    final offset = daysBetween(today, day.date);
    final isToday = offset == 0;
    final muted = AppAccessibility.textMuted(context);
    final accent = AppAccessibility.accentText(context);
    final (icon, color) = day.isFight
        ? (AppIcons.boxingGlove, isToday ? accent : muted)
        : day.isWeighIn
            ? (AppIcons.scales, isToday ? accent : muted)
            : offset < 0
                ? (AppIcons.checkCircle, muted)
                : isToday
                    ? (AppIcons.radioButton, accent)
                    : (AppIcons.circle, muted);
    return GroupedRow(
      title: copy.date(day.date),
      subtitle:
          day.steps.isEmpty ? null : day.steps.map(copy.stepTitle).join(' · '),
      leading: ExcludeSemantics(
        child: Icon(icon, size: IconSizes.row, color: color),
      ),
      trailing: isToday
          ? Text(copy.l.fightWeekToday,
              style: AppType.subhead(color: accent, weight: FontWeight.w600))
          : null,
    );
  }
}

/// Targets with their timing (pattern 6), from points 12–14.
class _RefuelTargets extends StatelessWidget {
  final RefuelTargets refuel;
  final FightCampCopy copy;

  const _RefuelTargets({required this.refuel, required this.copy});

  @override
  Widget build(BuildContext context) {
    final l = copy.l;
    final min = refuel.totalCarbMinGrams;
    final max = refuel.totalCarbMaxGrams;
    return GroupedList(children: [
      _TargetRow(
        icon: AppIcons.drop,
        label: l.fightRefuelDrink,
        value: l.fightRefuelPerHour(
            copy.fluidRange(refuel.minLitresPerHour, refuel.maxLitresPerHour)),
        timing: l.fightRefuelDrinkWhen,
      ),
      _TargetRow(
        icon: AppIcons.lightning,
        label: l.fightRefuelCarbs,
        value: l.fightRefuelUpTo(copy.grams(refuel.maxCarbGramsPerHour)),
        timing: l.fightRefuelCarbsWhen,
      ),
      if (min != null && max != null)
        _TargetRow(
          icon: AppIcons.bread,
          label: l.fightRefuelTotal,
          value: copy.gramsRange(min, max),
          timing: l.fightRefuelTotalWhen,
        ),
      _TargetRow(
        icon: AppIcons.bowlFood,
        label: l.fightRefuelFibre,
        value: l.fightRefuelFibreValue,
        timing: l.fightRefuelFibreWhen,
      ),
    ]);
  }
}

/// Label, value, then when: stacked, so a long value never squeezes the
/// label at 320 px.
class _TargetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String timing;

  const _TargetRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.timing,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(icon,
                  size: IconSizes.row,
                  color: AppAccessibility.accentText(context)),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppType.subhead(
                          color: AppAccessibility.textSecondary(context))),
                  const SizedBox(height: Insets.xxs),
                  Text(value, style: AppType.headline()),
                  const SizedBox(height: Insets.sm),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(Radii.chip),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Insets.sm, vertical: Insets.xxs),
                      child: Text(timing, style: AppType.subhead()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
