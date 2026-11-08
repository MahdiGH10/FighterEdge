import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/fight_camp/domain/calendar.dart';
import '../../features/training_plan/domain/session_status_resolver.dart';
import '../../features/training_plan/presentation/plan_controller.dart';
import '../../features/training_plan/presentation/plan_labels.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/app_accessibility.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/stat_card.dart';

/// The first seven days of the athlete's real plan, shown on the plan-ready
/// screen so the payment decision follows proof of what was built.
///
/// It reads the same [PlanController] week as the Train tab, so the sessions
/// and dates here are exactly the ones the athlete will see after the gate.
/// Nothing is invented: with no plan or no session in the window it draws
/// nothing.
class PlanWeekPreview extends StatelessWidget {
  const PlanWeekPreview({super.key});

  /// Sessions from [PlanController.today] for seven days, in date order. A
  /// moved session is listed once, on the day it moved to.
  static List<ResolvedSession> upcoming(PlanController plan) {
    final today = plan.today;
    final end = addDays(today, 7);
    final days = [
      ...plan.weekDays(start: today),
      ...plan.weekDays(start: addDays(today, 7)),
    ];
    return [
      for (final day in days)
        for (final row in day.rows)
          if (row.movedTo == null &&
              !row.date.isBefore(today) &&
              row.date.isBefore(end))
            row,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final plan = context.watch<PlanController>();
    final rows = upcoming(plan);
    if (rows.isEmpty) return const SizedBox.shrink();
    final muted = AppAccessibility.textSecondary(context);
    return AppCard(
      accent: AppColors.primary,
      edge: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(l.planReadyWeekTitle, style: AppType.title2()),
          ),
          const SizedBox(height: Insets.md),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.md),
              child: MergeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        PlanLabels.icon(
                            row.session.kind, row.session.discipline),
                        color: AppColors.accentText,
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _dayLabel(context, l, plan, row),
                            style: AppType.subhead(color: muted),
                          ),
                          Text(
                            PlanLabels.title(l, row.session),
                            style: AppType.headline(),
                          ),
                          Text(
                            PlanLabels.subtitle(l, row.session),
                            style: AppType.subhead(color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Text(l.planReadyWeekFootnote, style: AppType.micro(color: muted)),
        ],
      ),
    );
  }

  static String _dayLabel(
    BuildContext context,
    L l,
    PlanController plan,
    ResolvedSession row,
  ) =>
      daysBetween(plan.today, row.date) == 0
          ? l.dashboardToday
          : PlanLabels.weekday(context, row.date);
}
