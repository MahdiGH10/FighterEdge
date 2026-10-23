import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../../features/fight_camp/presentation/fight_camp_controller.dart';
import '../../features/fight_camp/presentation/widgets/fight_countdown_card.dart';
import '../../features/training_plan/domain/models/session_status.dart';
import '../../features/training_plan/presentation/plan_controller.dart';
import '../../features/training_plan/presentation/plan_labels.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/glass_surface.dart';
import '../../widgets/primary_button.dart';
import '../session_log_dialog.dart';

/// The action for this day, selected from the dated plan and fight calendar.
/// The fight-week state intentionally contains no cut target or prescription.
enum TodayState { training, done, recovery, fightWeek, noPlan }

TodayState todayState({
  required bool hasPlan,
  required SessionStatus? sessionStatus,
  required int? daysToFight,
}) {
  if (daysToFight != null && daysToFight >= 0 && daysToFight <= 7) {
    return TodayState.fightWeek;
  }
  if (!hasPlan) return TodayState.noPlan;
  if (sessionStatus == SessionStatus.today) return TodayState.training;
  if (sessionStatus == SessionStatus.completed) return TodayState.done;
  return TodayState.recovery;
}

class TodayHero extends StatelessWidget {
  const TodayHero({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final plan = context.watch<PlanController>();
    final fuel = context.watch<EdgeFuelController>();
    final camp = context.watch<FightCampController>().camp;
    final row = plan.todayRow;
    final state = todayState(
      hasPlan: plan.hasPlan,
      sessionStatus: row?.status,
      daysToFight: camp?.daysToFight(plan.today),
    );
    final session = row?.session;
    final sessionTitle = session == null ? null : PlanLabels.title(l, session);
    final sessionDetail =
        session == null ? null : PlanLabels.subtitle(l, session);
    final next = plan.nextSession;
    final nextLine = next == null
        ? l.dashboardRecovery
        : l.dashboardNextUp(
            PlanLabels.weekday(context, next.date),
            PlanLabels.title(l, next.session),
          );
    final title = switch (state) {
      TodayState.training => sessionTitle ?? l.dashboardToday,
      TodayState.done =>
        sessionTitle == null ? l.dashboardWeekDone : '$sessionTitle done',
      TodayState.recovery => l.dashboardRestDay,
      TodayState.fightWeek => l.fightWeekTitle,
      TodayState.noPlan => l.dashboardNoPlan,
    };
    final detail = switch (state) {
      TodayState.training ||
      TodayState.done =>
        sessionDetail ?? l.dashboardRecovery,
      TodayState.recovery => nextLine,
      TodayState.fightWeek => l.fightWeekTitle,
      TodayState.noPlan => l.dashboardPlanHint,
    };
    final fuelLine = fuel.hasUsableTarget
        ? l.fuelLeftToday((fuel.targetCalories - fuel.consumedCalories)
            .clamp(0, fuel.targetCalories))
        : l.dashboardSetFuel;
    final action = switch (state) {
      TodayState.training => l.dashboardLogSession,
      TodayState.done => l.navFuel,
      TodayState.recovery || TodayState.noPlan => l.dashboardOpenCamp,
      TodayState.fightWeek => l.fightWeekTitle,
    };
    void onAction() {
      switch (state) {
        case TodayState.training:
          if (session != null) logSessionWithRpe(context, plan, session);
        case TodayState.done:
          onNavigate(2);
        case TodayState.recovery || TodayState.noPlan:
          onNavigate(1);
        case TodayState.fightWeek:
          openFightWeek(context);
      }
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            state == TodayState.done
                ? l.dashboardStatCompleted
                : l.dashboardToday,
            style: AppType.micro(
              color: state == TodayState.done
                  ? AppColors.positive
                  : AppColors.emberSoft,
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(title,
              style: state == TodayState.recovery || state == TodayState.noPlan
                  ? AppType.largeTitle()
                  : AppType.display()),
          const SizedBox(height: Insets.xs),
          Text(detail, style: AppType.callout(color: AppColors.textSecondary)),
          if (state != TodayState.fightWeek) ...[
            const SizedBox(height: Insets.md),
            Row(children: [
              Expanded(
                child: Text(fuelLine,
                    style: AppType.callout(color: AppColors.textSecondary)),
              ),
              IconButton(
                tooltip: l.dashboardFuelInfo,
                icon: const Icon(AppIcons.info, size: IconSizes.row),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l.dashboardFuelInfo),
                    content: Text(l.dashboardFuelExplanation),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l.commonClose),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ],
          const SizedBox(height: Insets.xl),
          PrimaryButton(action, expand: true, onPressed: onAction),
        ],
      ),
    );
  }
}
