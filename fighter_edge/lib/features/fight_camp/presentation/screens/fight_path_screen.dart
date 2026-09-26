import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../../state/app_state.dart';
import '../../../../theme/app_accessibility.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_scaffold.dart';
import '../../../../widgets/grouped_list.dart';
import '../../../../widgets/stat_card.dart';
import '../../../edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../fight_camp_controller.dart';
import '../fight_camp_copy.dart';
import '../widgets/fight_countdown_card.dart';
import '../widgets/weight_path_chart.dart';
import '../widgets/weight_path_summary.dart';

/// The plan behind the countdown (pattern brief, screen C): where the
/// athlete is, the route to fight week, and each week's target. Editing the
/// fight is the header action; reading the plan is the screen.
class FightPathScreen extends StatelessWidget {
  const FightPathScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final state = context.watch<AppState>();
    final camp = context.watch<FightCampController>().camp;
    final copy =
        FightCampCopy(l, state, Localizations.localeOf(context).toString());

    if (camp == null) {
      return ScreenScaffold(
        title: l.fightPathScreenTitle,
        showBack: true,
        body: const Padding(
          padding: EdgeInsets.symmetric(horizontal: Insets.lg),
          child: Column(children: [AddFightRow()]),
        ),
      );
    }

    final status = FightCampStatus.of(
      camp,
      weights: state.weights,
      today: state.now,
      ageYears: context.watch<EdgeFuelController>().draft?.ageYears,
    );
    final checkpoints = status.path.checkpoints;
    final chart = WeightPathChart(
      status: status,
      weights: state.weights,
      today: state.now,
      copy: copy,
    );

    return ScreenScaffold(
      title: l.fightPathScreenTitle,
      showBack: true,
      actions: [
        HeaderIcon(
          Icons.edit_outlined,
          label: l.fightEdit,
          onTap: () => openFightSetup(context),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.lg, Insets.none, Insets.lg, Insets.xxl),
        children: [
          Text(
            '${l.fightNight(copy.date(camp.fightDate))} · '
            '${copy.phaseLine(status, state.now)}',
            style:
                AppType.subhead(color: AppAccessibility.textSecondary(context)),
          ),
          const SizedBox(height: Insets.md),
          WeightPathSummary(status: status, copy: copy),
          const SizedBox(height: Insets.xl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: LayoutTokens.weightChart, child: chart),
                const SizedBox(height: Insets.md),
                WeightPathLegend(
                  showPlan: chart.hasPlan,
                  planColor: WeightPathChart.planColorFor(status.path),
                  copy: copy,
                ),
              ],
            ),
          ),
          if (checkpoints.isNotEmpty) ...[
            const SizedBox(height: Insets.xl),
            Text(l.fightCheckpointsTitle, style: AppType.headline()),
            const SizedBox(height: Insets.md),
            GroupedList(children: [
              for (var i = 0; i < checkpoints.length; i++)
                GroupedRow(
                  title: copy.date(checkpoints[i].date),
                  subtitle: i == checkpoints.length - 1
                      ? l.fightCheckpointFightWeek
                      : null,
                  trailing: Text(
                    '${copy.weight(checkpoints[i].weightKg)} ${copy.unit}',
                    style: AppType.headline(),
                  ),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}
