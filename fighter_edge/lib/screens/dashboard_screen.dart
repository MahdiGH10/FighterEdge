import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/verification_gate.dart';
import '../controllers/auth_controller.dart';
import '../features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../features/edge_fuel/presentation/widgets/fuel_week_card.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/training_session.dart';
import '../routing/app_navigation.dart';
import '../routing/app_router.dart';
import '../state/app_state.dart';
import '../state/first_run_controller.dart';
import '../state/streak_controller.dart';
import '../state/streak_engine.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_haptics.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/dev_message_card.dart';
import '../widgets/number_hero.dart';
import '../widgets/press_scale.dart';
import '../widgets/primary_button.dart';
import '../widgets/stat_card.dart';
import '../widgets/grouped_list.dart';
import '../widgets/weekly_overview.dart';
import 'auth/verify_email_screen.dart';
import 'first_run/first_week_checklist.dart';
import 'round_timer_screen.dart';
import 'weight_tracker_screen.dart';

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
    final streak = context.watch<StreakController>();
    final fuel = context.watch<EdgeFuelController>();
    final user = auth.user;
    final streakDays = StreakEngine.streakDays(state.trainingDayKeys,
        protectedDateKeys: streak.protectedDateKeys, now: state.now);
    final atRisk = StreakEngine.isAtRisk(state.trainingDayKeys,
        protectedDateKeys: streak.protectedDateKeys, now: state.now);
    const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final today = days[state.now.weekday - 1];
    final unfinished = state.sessions.where((s) => !s.completed);
    final todaysSession = unfinished
        .where((s) => s.day.toLowerCase().startsWith(today))
        .firstOrNull;
    final next = todaysSession ?? unfinished.firstOrNull;
    final recent = state.completedSessionsDesc.take(3).toList();
    return ScreenScaffold.tab(
      title: l.dashboardTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.lg, Insets.none, Insets.lg, Insets.xxl),
        children: [
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
          if (firstRun.isActive) ...[
            FirstWeekChecklist(
                key: checklistKey,
                compact: true,
                onStartTour: onStartTour ?? () {},
                onLogMeal: () => onNavigate(2),
                onTrain: () => onNavigate(1)),
            const SizedBox(height: Insets.md),
          ],
          _SessionHero(
              session: next,
              today: todaysSession != null,
              hasPlan: state.sessions.isNotEmpty,
              onNavigate: onNavigate),
          const SizedBox(height: Insets.md),
          if (auth.supportsEmailVerification &&
              user != null &&
              !user.emailVerified) ...[
            _VerificationBanner(auth: auth),
            const SizedBox(height: Insets.md),
          ],
          if (atRisk) ...[
            _StreakFreezeBanner(streak: streak, onNavigate: onNavigate),
            const SizedBox(height: Insets.md),
          ],
          const DevMessageCard(),
          _DashboardStats(streakDays: streakDays),
          const SizedBox(height: Insets.xl),
          Text(l.dashboardThisWeek, style: AppType.headline()),
          const SizedBox(height: Insets.md),
          AppCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                WeeklyOverview(
                  dayLetters: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
                  progress: [
                    for (final day in days)
                      state.sessions.any((s) =>
                              s.completed &&
                              s.day.toLowerCase().startsWith(day))
                          ? 1.0
                          : 0.0
                  ],
                  todayIndex: state.now.weekday - 1,
                ),
                if (fuel.hasUsableTarget) ...[
                  const SizedBox(height: Insets.xl),
                  FuelWeekCard(
                      key: ValueKey(
                          '${fuel.targetCalories}-${fuel.consumedCalories}-${fuel.entries.length}'),
                      edgeFuel: fuel,
                      embedded: true),
                ],
              ])),
          const SizedBox(height: Insets.xl),
          Row(children: [
            Expanded(
                child:
                    Text(l.dashboardRecentActivity, style: AppType.headline())),
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
              for (final session in recent)
                _ActivityRow(session: session, now: state.now),
            ]),
        ],
      ),
    );
  }
}

class _SessionHero extends StatelessWidget {
  final TrainingSession? session;
  final bool today;
  final bool hasPlan;
  final ValueChanged<int> onNavigate;
  const _SessionHero(
      {required this.session,
      required this.today,
      required this.hasPlan,
      required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final fuel = context.watch<EdgeFuelController>();
    final title = session == null
        ? (hasPlan ? l.dashboardWeekDone : l.dashboardNoPlan)
        : today
            ? session!.title
            : l.dashboardRestDay;
    return AppCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.dashboardToday,
          style:
              AppType.subhead(color: AppAccessibility.textSecondary(context))),
      const SizedBox(height: Insets.xs),
      Text(title, style: AppType.largeTitle()),
      const SizedBox(height: Insets.sm),
      Text(
          session == null
              ? (hasPlan ? l.dashboardRecovery : l.dashboardPlanHint)
              : today
                  ? session!.subtitle
                  : l.dashboardNextUp(session!.day, session!.title),
          style:
              AppType.callout(color: AppAccessibility.textSecondary(context))),
      const SizedBox(height: Insets.lg),
      PrimaryButton(today ? l.dashboardStartSession : l.dashboardOpenCamp,
          expand: true,
          onPressed: today
              ? () => Navigator.of(context).push(CupertinoPageRoute<void>(
                  builder: (_) => RoundTimerScreen(session: session)))
              : () => onNavigate(1)),
      const SizedBox(height: Insets.sm),
      Row(children: [
        Expanded(
            child: TextButton(
          style: TextButton.styleFrom(
              alignment: Alignment.centerLeft, padding: EdgeInsets.zero),
          onPressed: () => onNavigate(2),
          child: Text(
              fuel.hasUsableTarget
                  ? l.fuelLeftToday(
                      (fuel.targetCalories - fuel.consumedCalories)
                          .clamp(0, fuel.targetCalories))
                  : l.dashboardSetFuel,
              style: AppType.subhead(
                  color: AppAccessibility.textSecondary(context))),
        )),
        IconButton(
            tooltip: l.dashboardFuelInfo,
            icon: const Icon(Icons.info_outline, size: IconSizes.row),
            onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                      title: Text(l.dashboardFuelInfo),
                      content: Text(l.dashboardFuelExplanation),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(l.commonClose))
                      ],
                    ))),
      ]),
    ]));
  }
}

class _DashboardStats extends StatelessWidget {
  final int streakDays;
  const _DashboardStats({required this.streakDays});
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final state = context.watch<AppState>();
    final weight = state.latestWeight == 0
        ? '—'
        : state.displayWeight(state.latestWeight).toStringAsFixed(1);
    final stats = [
      _Stat(
          label: l.dashboardStatWeight,
          value: weight,
          unit: state.weightUnitLabel,
          detail: state.weights.length < 2 ? l.dashboardAddWeighIn : null,
          heroTag: state.latestWeight == 0 ? null : weightHeroTag,
          onTap: () => AppNavigation.push(context, AppRoutes.weightTracker,
              fallbackBuilder: (_) => const WeightTrackerScreen())),
      _Stat(
          label: l.dashboardStatSessions,
          value: '${state.completedSessionCount}',
          unit: l.dashboardStatCompleted),
      _Stat(
          label: l.dashboardStatStreak,
          value: '$streakDays',
          unit: l.dashboardStatDays(streakDays)),
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
          const Icon(Icons.chevron_right,
              size: IconSizes.row, color: AppColors.textSecondary),
        ]));
  }
}

class _StreakFreezeBanner extends StatelessWidget {
  final StreakController streak;
  final ValueChanged<int> onNavigate;
  const _StreakFreezeBanner({required this.streak, required this.onNavigate});
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hasFreeze = streak.freezesAvailable > 0;
    return AppCard(
        accent: AppColors.negative,
        padding: const EdgeInsets.all(Insets.md),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.dashboardRiskTitle, style: AppType.headline()),
          const SizedBox(height: Insets.xs),
          Text(
              hasFreeze
                  ? l.dashboardFreezeHint(streak.freezesAvailable)
                  : l.dashboardLogHint,
              style: AppType.subhead(
                  color: AppAccessibility.textSecondary(context))),
          const SizedBox(height: Insets.sm),
          GhostButton(hasFreeze ? l.dashboardFreeze : l.dashboardLogNow,
              onPressed: hasFreeze
                  ? () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final used = await streak.useFreezeForYesterday();
                      if (!messenger.mounted || !used) return;
                      AppHaptics.success();
                      messenger.showSnackBar(
                          SnackBar(content: Text(l.dashboardFreezeUsed)));
                    }
                  : () => onNavigate(1)),
        ]));
  }
}

class _ActivityRow extends StatelessWidget {
  final TrainingSession session;
  final DateTime now;
  const _ActivityRow({required this.session, required this.now});
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final date = session.completedAt;
    final days = date == null
        ? null
        : DateUtils.dateOnly(now).difference(DateUtils.dateOnly(date)).inDays;
    final when = days == null
        ? l.dashboardLogged
        : days <= 0
            ? l.commonToday
            : days == 1
                ? l.dashboardYesterday
                : l.dashboardDaysAgo(days);
    return Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(session.icon,
              size: IconSizes.row, color: AppColors.textSecondary),
          const SizedBox(width: Insets.md),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(session.title,
                    style: AppType.callout(weight: FontWeight.w600)),
                const SizedBox(height: Insets.xs),
                Text(session.subtitle,
                    style: AppType.subhead(
                        color: AppAccessibility.textSecondary(context))),
                const SizedBox(height: Insets.xs),
                Text(
                    session.rpe == 0
                        ? when
                        : '$when · ${l.dashboardEffort(session.rpe)}',
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
      child:
          Icon(Icons.person, size: size * .55, color: AppColors.textSecondary));
}
