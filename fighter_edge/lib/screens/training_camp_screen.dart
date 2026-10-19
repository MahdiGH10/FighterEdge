import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_icons.dart';

import '../controllers/auth_controller.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/training_session.dart';
import '../state/app_state.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/filter_chips.dart';
import '../widgets/stat_card.dart';
import '../routing/app_navigation.dart';
import '../routing/app_router.dart';
import '../widgets/grouped_list.dart';
import 'round_timer_screen.dart';
import 'session_log_dialog.dart';
import 'drill_library_screen.dart';
import 'reaction_drill_picker.dart';
import '../theme/app_haptics.dart';
import '../widgets/press_scale.dart';

class TrainingCampScreen extends StatefulWidget {
  const TrainingCampScreen({super.key});

  @override
  State<TrainingCampScreen> createState() => _TrainingCampScreenState();
}

class _TrainingCampScreenState extends State<TrainingCampScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final activeTab = switch (_tab) {
      0 => const _WeekView(),
      1 => const _HistoryView(),
      2 => const DrillLibraryScreen(),
      _ => const ReactionDrillPicker(),
    };
    final l = L.of(context);
    return ScreenScaffold.tab(
      title: l.trainTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: FilterChips(
              options: [
                l.trainTabWeek,
                l.trainTabHistory,
                l.trainTabDrills,
                l.trainTabReaction,
              ],
              selectedIndex: _tab,
              onSelected: (i) => setState(() => _tab = i),
            ),
          ),
          const SizedBox(height: Insets.lg),
          Expanded(child: activeTab),
        ],
      ),
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final campStart = context.watch<AuthController>().user?.createdAt;
    final now = state.now;
    const dayNames = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final unfinished = state.sessions.where((s) => !s.completed);
    final next = unfinished
            .where((s) =>
                s.day.toLowerCase().startsWith(dayNames[now.weekday - 1]))
            .firstOrNull ??
        unfinished.firstOrNull;
    // The camp begins when the account does — onboarding seeds a fresh camp,
    // and there is no separate camp-start model yet. Week 1 is the first
    // calendar week of the account, not a fixed number.
    final weekNumber =
        campStart == null ? 1 : (now.difference(campStart).inDays ~/ 7) + 1;
    // Monday-to-Sunday range for the current week.
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - DateTime.monday));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final rangeFormat = DateFormat('MMM d');

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Insets.lg, Insets.none, Insets.lg, Insets.xxl),
      children: [
        Text('WEEK $weekNumber', style: AppType.title1()),
        const SizedBox(height: Insets.xxs),
        Text(
          '${rangeFormat.format(weekStart)} – ${rangeFormat.format(weekEnd)}',
          style: AppType.subhead(
              weight: FontWeight.w500,
              color: AppAccessibility.textSecondary(context)),
        ),
        const SizedBox(height: Insets.lg),
        if (state.sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: Insets.xxl),
            child: _PlaceholderView(
              'No sessions planned yet. Your training week appears here '
              'once your camp is set up.',
            ),
          ),
        for (final s in state.sessions)
          _SessionRow(
            s,
            isNext: s.id == next?.id,
            onLog: () => logSessionWithRpe(context, state, s),
          ),
        const SizedBox(height: Insets.md),
        Text(L.of(context).trainTools, style: AppType.title2()),
        const SizedBox(height: Insets.sm),
        GroupedList(children: [
          GroupedRow(
            title: L.of(context).timerTitle,
            subtitle: L.of(context).trainTimerToolSubtitle,
            onTap: () => AppNavigation.push(context, AppRoutes.roundTimer,
                fallbackBuilder: (_) => const RoundTimerScreen()),
          ),
        ]),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  final TrainingSession s;
  final bool isNext;
  final VoidCallback onLog;
  const _SessionRow(this.s, {required this.isNext, required this.onLog});
  @override
  Widget build(BuildContext context) {
    final large = AppAccessibility.isLargeText(context);
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(s.day,
          style: AppType.subhead(color: AppAccessibility.textMuted(context))),
      const SizedBox(height: Insets.xs),
      Text(s.title, style: AppType.headline()),
      const SizedBox(height: Insets.xs),
      Text(s.subtitle,
          style:
              AppType.subhead(color: AppAccessibility.textSecondary(context))),
      if (s.completed) ...[
        const SizedBox(height: Insets.sm),
        Row(children: [
          const Icon(AppIcons.check,
              size: IconSizes.inline, color: AppColors.textSecondary),
          const SizedBox(width: Insets.xs),
          Flexible(
              child: Text(L.of(context).trainingSessionDone,
                  style: AppType.subhead(color: AppColors.textSecondary))),
        ]),
      ],
    ]);
    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      if (s.completed)
        HeaderIcon(AppIcons.notePencil,
            label: L.of(context).trainingEditSessionLog, onTap: onLog)
      else
        _LogIconButton(label: s.title, primary: isNext, onTap: onLog),
    ]);
    return Padding(
        padding: const EdgeInsets.only(bottom: Insets.md),
        child: AppCard(
            padding: const EdgeInsets.all(Insets.md),
            child: large
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        content,
                        const SizedBox(height: Insets.md),
                        Align(alignment: Alignment.centerRight, child: actions)
                      ])
                : Row(children: [
                    Icon(s.icon,
                        size: IconSizes.row, color: AppColors.textSecondary),
                    const SizedBox(width: Insets.md),
                    Expanded(child: content),
                    const SizedBox(width: Insets.sm),
                    actions,
                  ])));
  }
}

class _LogIconButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _LogIconButton(
      {required this.label, required this.primary, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: L.of(context).trainingLogNamedSession(label),
      child: PressScale(
          key: primary ? const ValueKey('primary-session-log') : null,
          onTap: onTap,
          haptic: AppHaptics.commit,
          child: DecoratedBox(
              decoration: BoxDecoration(
                  color: primary ? AppColors.primaryFill : AppColors.surface,
                  border: primary
                      ? null
                      : Border.all(color: AppAccessibility.border(context)),
                  shape: BoxShape.circle),
              child: SizedBox.square(
                  dimension: AppAccessibility.minTouchTarget,
                  child: Icon(AppIcons.checkCircle,
                      color: primary
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      size: IconSizes.row)))));
}

class _HistoryView extends StatelessWidget {
  const _HistoryView();

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<AppState>().completedSessionsDesc;
    if (sessions.isEmpty) {
      return const _PlaceholderView(
          'Complete or log a session to build history');
    }
    // A lazy sliver list rather than building every row up front (audit
    // P-4): the log grows for as long as the account trains, with no cap.
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              Insets.lg, Insets.none, Insets.lg, Insets.none),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session history', style: AppType.title1()),
                const SizedBox(height: Insets.lg),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              Insets.lg, Insets.none, Insets.lg, Insets.xxl),
          sliver: SliverList.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) => _HistoryRow(sessions[index]),
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final TrainingSession session;
  const _HistoryRow(this.session);

  @override
  Widget build(BuildContext context) {
    final completedAt = session.completedAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: AppCard(
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            Icon(session.icon, color: AppColors.primary, size: 24),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.title,
                      style: AppType.callout(weight: FontWeight.w700)),
                  const SizedBox(height: Insets.xxs),
                  Text(
                    completedAt == null
                        ? 'Logged'
                        : DateFormat('MMM d, h:mm a').format(completedAt),
                    style: AppType.subhead(color: AppColors.textSecondary),
                  ),
                  if (session.note.isNotEmpty) ...[
                    const SizedBox(height: Insets.xs),
                    Text(session.note,
                        style: AppType.subhead(color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            Text('RPE ${session.rpe}',
                style: AppType.subhead(
                    weight: FontWeight.w800, color: AppColors.warning)),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderView extends StatelessWidget {
  final String message;
  const _PlaceholderView(this.message);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Text(message,
            textAlign: TextAlign.center,
            style: AppType.callout(
                weight: FontWeight.w500, color: AppColors.textMuted)),
      ),
    );
  }
}
