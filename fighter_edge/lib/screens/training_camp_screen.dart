import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_icons.dart';

import '../controllers/auth_controller.dart';
import '../l10n/gen/app_localizations.dart';
import '../features/training_plan/domain/models/session_status.dart';
import '../features/training_plan/domain/session_status_resolver.dart';
import '../features/training_plan/presentation/plan_controller.dart';
import '../features/training_plan/presentation/plan_labels.dart';
import '../models/training_log_entry.dart';
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
    final plan = context.watch<PlanController>();
    final campStart = context.watch<AuthController>().user?.createdAt;
    final now = context.watch<AppState>().now;
    final days = plan.weekDays();
    final next = plan.todaySession ?? plan.nextSession;
    // The camp begins when the account does — onboarding seeds a fresh camp,
    // and there is no separate camp-start model yet. Week 1 is the first
    // calendar week of the account, not a fixed number.
    final weekNumber =
        campStart == null ? 1 : (now.difference(campStart).inDays ~/ 7) + 1;
    // Monday-to-Sunday range for the current week.
    final weekStart = plan.thisWeekStart;
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
        if (!plan.hasPlan)
          const Padding(
            padding: EdgeInsets.only(top: Insets.xxl),
            child: _PlaceholderView(
              'No sessions planned yet. Your training week appears here '
              'once your camp is set up.',
            ),
          ),
        for (final day in days) ...[
          // Days before the plan began are left out; a rest day is calm
          // text, never a gap to fill.
          if (day.isRest && day.emptyStatus != SessionStatus.beforeStart)
            _RestRow(date: day.date),
          for (final row in day.rows)
            _SessionRow(
              row,
              isNext: row.session.id == next?.session.id &&
                  row.status != SessionStatus.moved,
              onLog: () => logSessionWithRpe(context, plan, row.session),
            ),
        ],
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

/// A day with nothing planned. Never a miss.
class _RestRow extends StatelessWidget {
  final DateTime date;
  const _RestRow({required this.date});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Text(
        '${PlanLabels.weekday(context, date)} ${date.day} · '
        '${l.dashboardRestDay}',
        style: AppType.subhead(color: AppAccessibility.textMuted(context)),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final ResolvedSession row;
  final bool isNext;
  final VoidCallback onLog;
  const _SessionRow(this.row, {required this.isNext, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final plan = context.read<PlanController>();
    final session = row.session;
    final status = row.status;
    final title = PlanLabels.title(l, session);
    final large = AppAccessibility.isLargeText(context);
    final done = status == SessionStatus.completed;
    // A session that was moved away or skipped is not asked for again.
    final open = status == SessionStatus.today ||
        status == SessionStatus.planned ||
        status == SessionStatus.missed;
    final note = switch (status) {
      SessionStatus.completed => l.trainingSessionDone,
      SessionStatus.skipped => l.planStatusSkipped,
      SessionStatus.missed => l.planStatusNotDone,
      SessionStatus.moved =>
        l.planStatusMovedTo(PlanLabels.weekday(context, row.movedTo!)),
      _ => row.movedFrom == null
          ? null
          : l.planStatusMovedFrom(PlanLabels.weekday(context, row.movedFrom!)),
    };
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${PlanLabels.weekday(context, row.date)} ${row.date.day}',
          style: AppType.subhead(color: AppAccessibility.textMuted(context))),
      const SizedBox(height: Insets.xs),
      Text(title, style: AppType.headline()),
      const SizedBox(height: Insets.xs),
      Text(PlanLabels.subtitle(l, session),
          style:
              AppType.subhead(color: AppAccessibility.textSecondary(context))),
      if (note != null) ...[
        const SizedBox(height: Insets.sm),
        Row(children: [
          if (done) ...[
            const Icon(AppIcons.check,
                size: IconSizes.inline, color: AppColors.textSecondary),
            const SizedBox(width: Insets.xs),
          ],
          Flexible(
              child: Text(note,
                  style: AppType.subhead(color: AppColors.textSecondary))),
        ]),
      ],
    ]);
    final menu = _menu(context, plan, l);
    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      if (done)
        HeaderIcon(AppIcons.notePencil,
            label: l.trainingEditSessionLog, onTap: onLog)
      else if (open)
        _LogIconButton(label: title, primary: isNext, onTap: onLog),
      if (menu != null) menu,
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
                    Icon(PlanLabels.icon(session.kind, session.discipline),
                        size: IconSizes.row, color: AppColors.textSecondary),
                    const SizedBox(width: Insets.md),
                    Expanded(child: content),
                    const SizedBox(width: Insets.sm),
                    actions,
                  ])));
  }

  /// Skip, move to today, or put a skipped or moved session back. Nothing
  /// here is a penalty: the athlete is choosing, and rest never counts as a
  /// miss.
  Widget? _menu(BuildContext context, PlanController plan, L l) {
    final session = row.session;
    final status = row.status;
    final canSkip = status == SessionStatus.today ||
        status == SessionStatus.planned ||
        status == SessionStatus.missed;
    final canMove = plan.canMoveToToday(row);
    final canPutBack = status == SessionStatus.skipped ||
        status == SessionStatus.moved ||
        row.movedFrom != null;
    if (!canSkip && !canPutBack) return null;
    return PopupMenuButton<_RowAction>(
      tooltip: l.planActionMore,
      icon: const Icon(AppIcons.dotsThreeVertical,
          size: IconSizes.row, color: AppColors.textSecondary),
      onSelected: (action) {
        switch (action) {
          case _RowAction.skip:
            plan.skip(session);
          case _RowAction.moveToToday:
            plan.move(session, plan.today);
          case _RowAction.putBack:
            plan.clearAdjustment(session);
        }
      },
      itemBuilder: (_) => [
        if (canSkip)
          PopupMenuItem(value: _RowAction.skip, child: Text(l.planActionSkip)),
        if (canMove)
          PopupMenuItem(
              value: _RowAction.moveToToday,
              child: Text(l.planActionMoveToToday)),
        if (canPutBack)
          PopupMenuItem(
              value: _RowAction.putBack, child: Text(l.planActionPutBack)),
      ],
    );
  }
}

enum _RowAction { skip, moveToToday, putBack }

class _LogIconButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _LogIconButton(
      {required this.label, required this.primary, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
      container: true,
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
    final sessions = context.watch<AppState>().trainingLog;
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
  final TrainingLogEntry session;
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
            Icon(PlanLabels.logIcon(session),
                color: AppColors.primary, size: 24),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.title,
                      style: AppType.callout(weight: FontWeight.w700)),
                  const SizedBox(height: Insets.xxs),
                  Text(
                    DateFormat('MMM d, h:mm a').format(completedAt),
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
