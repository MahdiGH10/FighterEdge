import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
import 'round_timer_screen.dart';
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
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
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
            onStart: () => Navigator.of(context).push(CupertinoPageRoute(
              builder: (_) => RoundTimerScreen(session: s),
            )),
            onLog: () => _logSession(context, state, s),
          ),
      ],
    );
  }

  Future<void> _logSession(
    BuildContext context,
    AppState state,
    TrainingSession session,
  ) async {
    final result = await showDialog<({int rpe, String note})>(
      context: context,
      builder: (_) => _SessionLogDialog(session: session),
    );
    if (result == null) return;
    state.completeSession(session, rpe: result.rpe, note: result.note);
    AppHaptics.success();
  }
}

/// Owns the note controller so it is disposed with the dialog, after its exit
/// animation, never while a focused field is still on screen.
class _SessionLogDialog extends StatefulWidget {
  final TrainingSession session;
  const _SessionLogDialog({required this.session});

  @override
  State<_SessionLogDialog> createState() => _SessionLogDialogState();
}

class _SessionLogDialogState extends State<_SessionLogDialog> {
  late int _rpe;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _rpe = widget.session.rpe == 0 ? 7 : widget.session.rpe;
    _note = TextEditingController(text: widget.session.note);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Log ${widget.session.title}', style: AppType.title2()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('RPE $_rpe / 10',
              style: AppType.subhead(
                  weight: FontWeight.w700, color: AppColors.textSecondary)),
          Slider(
            value: _rpe.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: AppColors.primary,
            onChanged: (value) => setState(() => _rpe = value.round()),
          ),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 3,
            style: AppType.callout(),
            cursorColor: AppColors.primary,
            decoration: const InputDecoration(
              hintText: 'Quick reflection',
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: AppType.callout(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, (rpe: _rpe, note: _note.text)),
          child: Text('Save',
              style: AppType.callout(
                  weight: FontWeight.w700, color: AppColors.accentText)),
        ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  final TrainingSession s;
  final bool isNext;
  final VoidCallback onStart, onLog;
  const _SessionRow(this.s,
      {required this.isNext, required this.onStart, required this.onLog});
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
          const Icon(Icons.check,
              size: IconSizes.inline, color: AppColors.textSecondary),
          const SizedBox(width: Insets.xs),
          Flexible(
              child: Text(L.of(context).trainingSessionDone,
                  style: AppType.subhead(color: AppColors.textSecondary))),
        ]),
      ],
    ]);
    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      if (!s.completed)
        _StartIconButton(label: s.title, primary: isNext, onTap: onStart),
      HeaderIcon(s.completed ? Icons.edit_note : Icons.check_circle_outline,
          label: s.completed
              ? L.of(context).trainingEditSessionLog
              : L.of(context).trainingLogSession,
          onTap: onLog),
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

class _StartIconButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _StartIconButton(
      {required this.label, required this.primary, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: L.of(context).trainingStartSession(label),
      child: PressScale(
          key: primary ? const ValueKey('primary-session-start') : null,
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
                  child: Icon(Icons.play_arrow,
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
          padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SESSION HISTORY', style: AppType.title1()),
                const SizedBox(height: Insets.lg),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding:
              const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
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
