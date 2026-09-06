import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/training_session.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/filter_chips.dart';
import '../widgets/stat_card.dart';
import 'round_timer_screen.dart';

class TrainingCampScreen extends StatefulWidget {
  const TrainingCampScreen({super.key});

  @override
  State<TrainingCampScreen> createState() => _TrainingCampScreenState();
}

class _TrainingCampScreenState extends State<TrainingCampScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppHeader(
              title: 'Training Camp',
              showBack: false,
              actions: [HeaderIcon(Icons.calendar_month, onTap: () {})],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: FilterChips(
                options: const ['Week', 'Month', 'Plan'],
                selectedIndex: _tab,
                onSelected: (i) => setState(() => _tab = i),
                scrollable: false,
              ),
            ),
            const SizedBox(height: Insets.lg),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  _WeekView(),
                  _HistoryView(),
                  _PlaceholderView('Full fight-camp plan coming soon'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('WEEK 4', style: AppTheme.display(20)),
            const SizedBox(width: Insets.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('PEAK',
                  style: AppTheme.body(11,
                      weight: FontWeight.w700, color: AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('May 20 – May 26',
            style: AppTheme.body(12,
                weight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: Insets.lg),
        for (final s in state.sessions)
          _SessionRow(
            s,
            onStart: () => Navigator.of(context).push(MaterialPageRoute(
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
          title: Text('Log ${session.title}', style: AppTheme.display(18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('RPE $rpe / 10',
                  style: AppTheme.body(13,
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
                style: AppTheme.body(14),
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
                  style: AppTheme.body(14, color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, (rpe: rpe, note: note.text)),
              child: Text('Save',
                  style: AppTheme.body(14,
                      weight: FontWeight.w700, color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
    note.dispose();
    if (result == null) return;
    state.completeSession(session, rpe: result.rpe, note: result.note);
  }
}

class _SessionRow extends StatelessWidget {
  final TrainingSession s;
  final VoidCallback onStart;
  final VoidCallback onLog;
  const _SessionRow(this.s, {required this.onStart, required this.onLog});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: AppCard(
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            SizedBox(
              width: 38,
              child: Text(s.day.toUpperCase(),
                  style: AppTheme.body(12,
                      weight: FontWeight.w700, color: AppColors.textMuted)),
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
                  color: s.completed
                      ? AppColors.primary
                      : AppColors.textSecondary),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(14, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(s.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(12,
                          weight: FontWeight.w500,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
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
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox.square(
            dimension: 40,
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
      children: [
        Text('SESSION HISTORY', style: AppTheme.display(20)),
        const SizedBox(height: Insets.lg),
        for (final session in sessions) _HistoryRow(session),
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
                      style: AppTheme.body(14, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    completedAt == null
                        ? 'Logged'
                        : DateFormat('MMM d, h:mm a').format(completedAt),
                    style: AppTheme.body(12, color: AppColors.textSecondary),
                  ),
                  if (session.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(session.note,
                        style:
                            AppTheme.body(12, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            Text('RPE ${session.rpe}',
                style: AppTheme.body(12,
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
            style: AppTheme.body(14,
                weight: FontWeight.w500, color: AppColors.textMuted)),
      ),
    );
  }
}
