import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_icons.dart';

import '../auth/verification_gate.dart';
import '../controllers/auth_controller.dart';
import '../features/corner_brief/presentation/corner_line_row.dart';
import '../features/fight_camp/domain/calendar.dart';
import '../features/fight_camp/presentation/widgets/fight_countdown_card.dart';
import '../features/training_plan/presentation/plan_controller.dart';
import '../features/training_plan/presentation/plan_labels.dart';
import '../features/weekly_review/domain/review_window.dart';
import '../features/weekly_review/presentation/weekly_review_screen.dart';
import '../l10n/decimal_format.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/training_log_entry.dart';
import '../routing/app_navigation.dart';
import '../routing/app_router.dart';
import '../features/edge_fuel/presentation/controllers/nutrition_mode_controller.dart';
import '../state/app_state.dart';
import '../state/first_run_controller.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/access_status.dart';
import '../widgets/dev_message_card.dart';
import '../widgets/number_hero.dart';
import '../widgets/press_scale.dart';
import '../widgets/stat_card.dart';
import '../widgets/sync_notice.dart';
import '../widgets/grouped_list.dart';
import '../widgets/weekly_target_card.dart';
import 'auth/verify_email_screen.dart';
import 'first_run/first_week_checklist.dart';
import 'weight_tracker_screen.dart';
import 'home/today_hero.dart';
import 'round_timer_screen.dart';

class DashboardScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  final GlobalKey? checklistKey;
  final VoidCallback? onStartTour;

  const DashboardScreen({
    super.key,
    required this.onNavigate,
    this.checklistKey,
    this.onStartTour,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final auth = context.watch<AuthController>();
    final state = context.watch<AppState>();
    final firstRun = context.watch<FirstRunController>();
    final plan = context.watch<PlanController>();
    // Weight, Fuel and the weigh-in shortcut are hidden while nutrition is
    // paused (and until the athlete's choice has been read).
    final showNutrition = context.watch<NutritionModeController>().visible;
    final user = auth.user;
    final week = plan.thisWeek;
    final streakWeeks = plan.weeklyStreak.count;
    final reviewWeek = plan.hasPlan ? ReviewWindow.weekFor(plan.today) : null;
    final reviewReady =
        reviewWeek != null && plan.reviewDecision(reviewWeek) == null;
    final upcoming = plan.nextSession;
    final nextThisWeek =
        upcoming != null && daysBetween(plan.thisWeekStart, upcoming.date) < 7
            ? upcoming
            : null;
    final recent = state.trainingLog.take(3).toList();
    // The header says what day it is, which is more use than the word
    // "Dashboard" on the screen the bottom bar already calls Home.
    final locale = Localizations.localeOf(context).toString();
    return ScreenScaffold.tab(
      title: l.dashboardToday,
      scrollsUnderHeader: true,
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
              Insets.lg,
              MediaQuery.paddingOf(context).top,
              Insets.lg,
              ScreenScaffold.tabBottomPadding(context)),
          children: [
            // Only while a change was refused by the server.
            const SyncNotice(),
            Text(DateFormat.MMMEd(locale).format(state.now),
                style: AppType.subhead(
                    color: AppAccessibility.textSecondary(context))),
            Text(
                user?.displayName.isNotEmpty == true
                    ? user!.displayName
                    : l.dashboardFighter,
                style: AppType.title1()),
            if (user?.goal.isNotEmpty == true)
              Text(user!.goal,
                  style: AppType.subhead(
                      color: AppAccessibility.textSecondary(context))),
            const SizedBox(height: Insets.lg),
            const AccessStatus(),
            if (firstRun.isActive) ...[
              FirstWeekChecklist(
                  key: checklistKey,
                  compact: true,
                  onStartTour: onStartTour ?? () {},
                  onLogMeal: () => onNavigate(2),
                  onTrain: () => onNavigate(1)),
              const SizedBox(height: Insets.md),
            ],
            TodayHero(onNavigate: onNavigate),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.sm,
              children: [
                if (showNutrition) ...[
                  TextButton.icon(
                    onPressed: () => AppNavigation.push(
                      context,
                      AppRoutes.weightTracker,
                      fallbackBuilder: (_) => const WeightTrackerScreen(),
                    ),
                    icon: const Icon(AppIcons.scales),
                    label: Text(l.dashboardAddWeighIn),
                  ),
                  TextButton.icon(
                    onPressed: () => onNavigate(2),
                    icon: const Icon(AppIcons.forkKnife),
                    label: Text(l.navFuel),
                  ),
                ],
                TextButton.icon(
                  onPressed: () => AppNavigation.push(
                    context,
                    AppRoutes.roundTimer,
                    fallbackBuilder: (_) => const RoundTimerScreen(),
                  ),
                  icon: const Icon(AppIcons.timer),
                  label: Text(l.dashboardTimerAction),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            const FightCountdownSection(),
            const CornerLineRow(),
            const SizedBox(height: Insets.md),
            if (auth.supportsEmailVerification &&
                user != null &&
                !user.emailVerified) ...[
              _VerificationBanner(auth: auth),
              const SizedBox(height: Insets.md),
            ],
            const DevMessageCard(),
            _DashboardStats(streakWeeks: streakWeeks),
            const AddFightRow(),
            const SizedBox(height: Insets.xl),
            WeeklyTargetCard(
              completed: week.completed,
              planned: week.planned,
              target: week.target,
              streakWeeks: streakWeeks,
              nextDay: nextThisWeek == null
                  ? null
                  : PlanLabels.weekday(context, nextThisWeek.date),
              nextTitle: nextThisWeek == null
                  ? null
                  : PlanLabels.title(l, nextThisWeek.session),
              onOpenWeek: () => onNavigate(1),
              onOpenReview: reviewReady
                  ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) =>
                          WeeklyReviewScreen(weekStart: reviewWeek)))
                  : null,
            ),
            const SizedBox(height: Insets.xl),
            Row(children: [
              Expanded(
                  child: Text(l.dashboardRecentActivity,
                      style: AppType.headline())),
              TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary),
                  onPressed: () => onNavigate(1),
                  child: Text(l.dashboardSeeAll)),
            ]),
            if (recent.isEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.md),
                  child: Text(l.dashboardNoActivity,
                      style: AppType.callout(
                          color: AppAccessibility.textSecondary(context))))
            else
              GroupedList(children: [
                for (final entry in recent)
                  _ActivityRow(entry: entry, now: state.now),
              ]),
          ],
        ),
      ),
    );
  }
}

class _DashboardStats extends StatelessWidget {
  final int streakWeeks;
  const _DashboardStats({required this.streakWeeks});
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final state = context.watch<AppState>();
    final weight = state.latestWeight == 0
        ? '—'
        : formatFixedDecimal(state.displayWeight(state.latestWeight),
            Localizations.localeOf(context).toString());
    final showWeight = context.watch<NutritionModeController>().visible;
    final stats = [
      if (showWeight)
        _Stat(
          label: l.dashboardStatWeight,
          value: weight,
          unit: state.weightUnitLabel,
          detail: state.weights.length < 2 ? l.dashboardAddWeighIn : null,
          heroTag: state.latestWeight == 0 ? null : weightHeroTag,
          onTap: () => AppNavigation.push(context, AppRoutes.weightTracker,
              fallbackBuilder: (_) => const WeightTrackerScreen()),
        ),
      _Stat(
          label: l.dashboardStatSessions,
          value: '${state.completedSessionCount}',
          unit: l.dashboardStatCompleted),
      _Stat(
          label: l.dashboardStatStreak,
          value: '$streakWeeks',
          unit: l.dashboardStatWeeks(streakWeeks)),
    ];
    return AppCard(
        child: AppAccessibility.isLargeText(context)
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final (index, stat) in stats.indexed) ...[
                  if (index > 0) const SizedBox(height: Insets.lg),
                  stat,
                ]
              ])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final (index, stat) in stats.indexed) ...[
                  if (index > 0) const SizedBox(width: Insets.sm),
                  Expanded(child: stat),
                ]
              ]));
  }
}

class _Stat extends StatelessWidget {
  final String label, value, unit;
  final String? detail;
  final Object? heroTag;
  final VoidCallback? onTap;
  const _Stat(
      {required this.label,
      required this.value,
      required this.unit,
      this.detail,
      this.heroTag,
      this.onTap});
  @override
  Widget build(BuildContext context) {
    final number = Text(value, style: AppType.title1());
    final body =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style:
              AppType.subhead(color: AppAccessibility.textSecondary(context))),
      const SizedBox(height: Insets.sm),
      if (heroTag case final tag?)
        NumberHero(
            tag: tag, text: value, style: AppType.title1(), child: number)
      else
        number,
      Text(unit,
          style:
              AppType.subhead(color: AppAccessibility.textSecondary(context))),
      if (detail != null) ...[
        const SizedBox(height: Insets.xs),
        Text(detail!,
            style:
                AppType.subhead(color: AppAccessibility.accentText(context))),
      ],
    ]);
    return MergeSemantics(
        child: Semantics(
            button: onTap != null,
            child: onTap == null
                ? body
                : PressScale(
                    onTap: onTap,
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            minHeight: AppAccessibility.minTouchTarget),
                        child: body))));
  }
}

class _VerificationBanner extends StatelessWidget {
  final AuthController auth;
  const _VerificationBanner({required this.auth});
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final urgent = auth.verificationStage == VerificationStage.urgent;
    return AppCard(
        accent: urgent ? AppColors.negative : AppColors.warning,
        padding: const EdgeInsets.all(Insets.md),
        onTap: () => AppNavigation.push(context, AppRoutes.verifyEmail,
            fallbackBuilder: (_) => const VerifyEmailScreen()),
        child: Row(children: [
          Expanded(
              child: Text(
                  urgent ? l.dashboardConfirmEmail : l.dashboardVerifyEmail,
                  style: AppType.callout())),
          const Icon(AppIcons.caretRight,
              size: IconSizes.row, color: AppColors.textSecondary),
        ]));
  }
}

class _ActivityRow extends StatelessWidget {
  final TrainingLogEntry entry;
  final DateTime now;
  const _ActivityRow({required this.entry, required this.now});
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final days = DateUtils.dateOnly(now)
        .difference(DateUtils.dateOnly(entry.completedAt))
        .inDays;
    final when = days <= 0
        ? l.commonToday
        : days == 1
            ? l.dashboardYesterday
            : l.dashboardDaysAgo(days);
    return Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(PlanLabels.logIcon(entry),
              size: IconSizes.row, color: AppColors.textSecondary),
          const SizedBox(width: Insets.md),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(entry.title,
                    style: AppType.callout(weight: FontWeight.w600)),
                const SizedBox(height: Insets.xs),
                Text(
                    entry.rpe == 0
                        ? when
                        : '$when · ${l.dashboardEffort(entry.rpe)}',
                    style: AppType.subhead(
                        color: AppAccessibility.textMuted(context))),
              ])),
        ]));
  }
}

/// A local avatar; never requires a network image.
class FighterAvatar extends StatelessWidget {
  final double size;
  const FighterAvatar({super.key, this.size = AppAccessibility.minTouchTarget});
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
          shape: BoxShape.circle, color: AppColors.surfaceElevated),
      child: Icon(AppIcons.user,
          size: size * .55, color: AppColors.textSecondary));
}
