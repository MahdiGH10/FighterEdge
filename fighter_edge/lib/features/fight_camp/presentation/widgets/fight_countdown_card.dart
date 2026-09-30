import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../../routing/app_navigation.dart';
import '../../../../routing/app_router.dart';
import '../../../../state/app_state.dart';
import '../../../../theme/app_accessibility.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/grouped_list.dart';
import '../../../../widgets/stat_card.dart';
import '../../../edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../../domain/fight_camp.dart';
import '../../domain/fight_week_plan.dart';
import '../../domain/weight_path.dart';
import '../../domain/weight_trend.dart';
import '../fight_camp_controller.dart';
import '../fight_camp_copy.dart';
import '../screens/fight_path_screen.dart';
import '../screens/fight_setup_screen.dart';
import '../screens/fight_week_screen.dart';

void openFightSetup(BuildContext context) => AppNavigation.push<void>(
      context,
      AppRoutes.fightSetup,
      fallbackBuilder: (_) => const FightSetupScreen(),
    );

void openFightPath(BuildContext context) => AppNavigation.push<void>(
      context,
      AppRoutes.fightPath,
      fallbackBuilder: (_) => const FightPathScreen(),
    );

void openFightWeek(BuildContext context) => AppNavigation.push<void>(
      context,
      AppRoutes.fightWeek,
      fallbackBuilder: (_) => const FightWeekScreen(),
    );

/// From fight week on, the days matter more than the weekly path.
bool opensFightWeek(CampPhase phase) =>
    phase == CampPhase.fightWeek || phase == CampPhase.refuel;

/// The fight the camp is built around, at the top of the dashboard (pattern
/// brief, screen B). Shown only while the fight is still ahead; afterwards
/// [AddFightRow] invites the next one.
class FightCountdownSection extends StatelessWidget {
  const FightCountdownSection({super.key});

  @override
  Widget build(BuildContext context) {
    final camp = context.watch<FightCampController>().camp;
    final state = context.watch<AppState>();
    if (camp == null || camp.daysToFight(state.now) < 0) {
      return const SizedBox.shrink();
    }
    final l = L.of(context);
    final copy =
        FightCampCopy(l, state, Localizations.localeOf(context).toString());
    final ageYears = context.watch<EdgeFuelController>().draft?.ageYears;
    final status = FightCampStatus.of(
      camp,
      weights: state.weights,
      today: state.now,
      ageYears: ageYears,
    );
    final todaySteps = opensFightWeek(status.phase)
        ? FightWeekPlan.plan(
              camp: camp,
              weights: [
                for (final w in state.weights) WeightPoint(w.date, w.kg)
              ],
              today: state.now,
              ageYears: ageYears,
            )?.dayOn(state.now)?.steps ??
            const <FightWeekStep>[]
        : const <FightWeekStep>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: FightCountdownCard(
        status: status,
        copy: copy,
        today: state.now,
        todaySteps: todaySteps,
        onTap: () => opensFightWeek(status.phase)
            ? openFightWeek(context)
            : openFightPath(context),
      ),
    );
  }
}

class FightCountdownCard extends StatelessWidget {
  final FightCampStatus status;
  final FightCampCopy copy;
  final DateTime today;
  final VoidCallback onTap;

  /// Fight week's steps for [today]. When set, they replace the path line,
  /// unless the path is a warning: a warning always shows.
  final List<FightWeekStep> todaySteps;

  const FightCountdownCard({
    super.key,
    required this.status,
    required this.copy,
    required this.today,
    required this.onTap,
    this.todaySteps = const [],
  });

  @override
  Widget build(BuildContext context) {
    final l = copy.l;
    final camp = status.camp;
    final days = status.daysToFight;
    final dateLine = l.fightNight(copy.date(camp.fightDate));
    final phaseLine = copy.phaseLine(status, today);
    final warning = status.path.status == WeightPathStatus.needsSupervision ||
        status.path.status == WeightPathStatus.notSafe;
    final pathLine = todaySteps.isEmpty || warning
        ? copy.pathLine(status.path)
        : l.fightTodaySteps(todaySteps.map(copy.stepTitle).join(' · '));
    final tone = switch (status.path.status) {
      WeightPathStatus.needsSupervision => AppColors.warning,
      WeightPathStatus.notSafe => AppColors.negative,
      _ => AppAccessibility.textSecondary(context),
    };
    final summary = [
      dateLine,
      if (days > 0) '$days ${l.fightDaysToGo(days)}',
      phaseLine,
      pathLine,
      // Where the tap goes.
      opensFightWeek(status.phase) ? l.fightWeekTitle : l.fightPathScreenTitle,
    ].join('. ');

    return Semantics(
      button: true,
      label: summary,
      onTap: onTap,
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(dateLine,
                style: AppType.subhead(
                    color: AppAccessibility.accentText(context),
                    weight: FontWeight.w600)),
            const SizedBox(height: Insets.xs),
            if (days > 0)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: Insets.sm,
                children: [
                  // A count of real days: never animated (motion rule 4).
                  Text(
                    '$days',
                    style: AppType.heroNumeral(),
                    textScaler: AppAccessibility.heroNumeralScaler(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child:
                        Text(l.fightDaysToGo(days), style: AppType.headline()),
                  ),
                ],
              )
            else
              Text(phaseLine, style: AppType.largeTitle()),
            if (days > 0) ...[
              const SizedBox(height: Insets.xs),
              Text(phaseLine,
                  style: AppType.subhead(
                      color: AppAccessibility.textSecondary(context))),
            ],
            if (status.phase == CampPhase.camp) ...[
              const SizedBox(height: Insets.md),
              _CampWeeks(
                total: camp.campWeeks,
                current: camp.campWeekOn(today) ?? 0,
              ),
            ],
            const SizedBox(height: Insets.md),
            Text(pathLine, style: AppType.callout(color: tone)),
          ],
        ),
      ),
    );
  }
}

/// One segment per camp week; weeks reached so far are filled (pattern
/// brief, pattern 1).
class _CampWeeks extends StatelessWidget {
  final int total;
  final int current;
  const _CampWeeks({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var week = 1; week <= total; week++) ...[
          if (week > 1) const SizedBox(width: Insets.xs),
          Expanded(
            child: Container(
              height: Insets.xs,
              decoration: BoxDecoration(
                color:
                    week <= current ? AppColors.primaryFill : AppColors.track,
                borderRadius: BorderRadius.circular(Radii.chip),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The way in when there is no upcoming fight: one quiet row, so the
/// dashboard keeps a single primary action.
class AddFightRow extends StatelessWidget {
  const AddFightRow({super.key});

  @override
  Widget build(BuildContext context) {
    final fights = context.watch<FightCampController>();
    final now = context.watch<AppState>().now;
    final camp = fights.camp;
    if (!fights.loaded || (camp != null && camp.daysToFight(now) >= 0)) {
      return const SizedBox.shrink();
    }
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Insets.md),
      child: GroupedList(children: [
        GroupedRow(
          title: camp == null ? l.fightAddTitle : l.fightDone,
          subtitle: l.fightAddSubtitle,
          leading: Icon(Icons.sports_mma_outlined,
              size: IconSizes.row, color: AppAccessibility.accentText(context)),
          onTap: () => openFightSetup(context),
        ),
      ]),
    );
  }
}
