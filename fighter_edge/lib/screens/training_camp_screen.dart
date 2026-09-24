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
    final now = DateTime.now();
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
        for (final s in state.sessions)
          _SessionRow(
            s,
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
    var rpe = session.rpe == 0 ? 7 : session.rpe;
    final note = TextEditingController(text: session.note);
    final result = await showDialog<({int rpe, String note})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Log ${session.title}', style: AppType.title2()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('RPE $rpe / 10',
                  style: AppType.subhead(
                      weight: FontWeight.w700, color: AppColors.textSecondary)),
              Slider(
                value: rpe.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: AppColors.primary,
                onChanged: (value) => setDialogState(() => rpe = value.round()),
              ),
              TextField(
                controller: note,
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
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: AppType.callout(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, (rpe: rpe, note: note.text)),
              child: Text('Save',
                  style: AppType.callout(
                      weight: FontWeight.w700, color: AppColors.accentText)),
            ),
          ],
        ),
      ),
    );
    note.dispose();
    if (result == null) return;
    state.completeSession(session, rpe: result.rpe, note: result.note);
    AppHaptics.success();
  }
}

class _SessionRow extends StatelessWidget {
  final TrainingSession s;
  final VoidCallback onStart;
  final VoidCallback onLog;
  const _SessionRow(this.s, {required this.onStart, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.4;
    final leading = Row(
      children: [
        SizedBox(
          width: 38,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              s.day.toUpperCase(),
              style: AppType.subhead(
                  weight: FontWeight.w700, color: AppColors.textMuted),
            ),
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(s.icon,
              size: 20,
              color: s.completed ? AppColors.primary : AppColors.textSecondary),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.callout(weight: FontWeight.w700)),
              const SizedBox(height: Insets.xxs),
              Text(s.subtitle,
                  maxLines: largeText ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.subhead(
                      weight: FontWeight.w500, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          largeText ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (s.completed)
          _CompletionDot(completed: s.completed)
        else
          _StartIconButton(label: s.title, onTap: onStart),
        const SizedBox(width: Insets.sm),
        HeaderIcon(
          s.completed ? Icons.edit_note : Icons.check_circle_outline,
          onTap: onLog,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: AppCard(
        padding: const EdgeInsets.all(Insets.md),
        child: largeText
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  leading,
                  const SizedBox(height: Insets.md),
                  actions,
                ],
              )
            : Row(
                children: [
                  Expanded(child: leading),
                  const SizedBox(width: Insets.sm),
                  actions,
                ],
              ),
      ),
    );
  }
}

class _CompletionDot extends StatelessWidget {
  final bool completed;
  const _CompletionDot({required this.completed});

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 15, color: Colors.white),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 2),
      ),
    );
  }
}

class _StartIconButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _StartIconButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Start $label',
      child: PressScale(
        onTap: onTap,
        haptic: AppHaptics.commit,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: AppAccessibility.minTouchTarget,
            child: Icon(Icons.play_arrow, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
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
