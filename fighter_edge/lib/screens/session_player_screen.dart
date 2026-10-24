import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/training_plan/domain/models/planned_session.dart';
import '../features/training_plan/domain/models/session_template.dart';
import '../features/training_plan/presentation/plan_controller.dart';
import '../features/training_plan/presentation/plan_labels.dart';
import '../l10n/gen/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_haptics.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../training/session/session_player.dart';
import '../widgets/glass_sheet.dart';
import '../widgets/glass_surface.dart';
import '../widgets/premium_effects.dart';

/// The plan's neutral timed blocks. The launch templates contain no coaching
/// cues; this screen never invents drills or a round structure.
class SessionPlayerScreen extends StatefulWidget {
  const SessionPlayerScreen({super.key, required this.session});

  final PlannedSession session;

  @override
  State<SessionPlayerScreen> createState() => _SessionPlayerScreenState();
}

class _SessionPlayerScreenState extends State<SessionPlayerScreen> {
  late final SessionPlayer _player;
  Timer? _repaint;

  @override
  void initState() {
    super.initState();
    _player = SessionPlayer(widget.session)..start();
    _repaint = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    AppHaptics.commit();
  }

  @override
  void dispose() {
    _repaint?.cancel();
    super.dispose();
  }

  static String _time(Duration value) {
    final seconds =
        (value.inMicroseconds + Duration.microsecondsPerSecond - 1) ~/
            Duration.microsecondsPerSecond;
    final minutes = seconds ~/ 60;
    return '${minutes.toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  String _stageLabel(SessionStage stage) {
    if (stage.isRest) return 'Rest';
    return switch (stage.kind) {
      BlockKind.warmUp => 'Warm-up',
      BlockKind.drillRounds => 'Round ${stage.round} of ${stage.rounds}',
      BlockKind.conditioning => 'Conditioning',
      BlockKind.strength => 'Strength',
      BlockKind.main => 'Session',
      BlockKind.coolDown => 'Cool-down',
    };
  }

  Future<void> _finish() async {
    _player.pause();
    setState(() {});
    if (!context.read<AppState>().requireWrite()) return;
    final rpe = await showGlassSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Session complete', style: AppType.largeTitle()),
            const SizedBox(height: Insets.sm),
            Text('How hard was it?', style: AppType.body()),
            const SizedBox(height: Insets.lg),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final value in [6, 7, 8, 9, 10])
                  SizedBox(
                    width: AppAccessibility.minTouchTarget,
                    height: AppAccessibility.minTouchTarget,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, value),
                      child: Text('$value', style: AppType.callout()),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            Text(
              '6 steady · 10 all out',
              style: AppType.subhead(color: AppColors.textSecondary),
            ),
            const SizedBox(height: Insets.xl),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: Text('Keep session open', style: AppType.callout()),
            ),
          ],
        ),
      ),
    );
    if (!mounted || rpe == null) return;
    final plan = context.read<PlanController>();
    plan.complete(
      widget.session,
      title: PlanLabels.title(L.of(context), widget.session),
      rpe: rpe,
    );
    AppHaptics.success();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _player.snapshot();
    final stage = snapshot.stage;
    final title = PlanLabels.title(L.of(context), widget.session);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BackdropGroup(
        child: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close session',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(AppIcons.x),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: AppType.micro(color: AppColors.textSecondary),
                        ),
                      ),
                      TextButton(
                        onPressed: _finish,
                        child: Text('Finish', style: AppType.callout()),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(Insets.xl),
                    children: [
                      Text(
                        stage == null ? 'Done' : _stageLabel(stage),
                        style: AppType.largeTitle(),
                      ),
                      const SizedBox(height: Insets.xl),
                      Center(
                        child: Semantics(
                          label: 'Time left ${_time(snapshot.remaining)}',
                          child: Text(
                            _time(snapshot.remaining),
                            style: AppType.heroNumeral(),
                            textScaler: AppAccessibility.heroNumeralScaler(
                              context,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: Insets.xl),
                      Text(
                        snapshot.isDone
                            ? 'Session timer finished'
                            : snapshot.isRunning
                                ? 'In progress'
                                : 'Paused',
                        textAlign: TextAlign.center,
                        style: AppType.micro(color: AppColors.emberSoft),
                      ),
                      const SizedBox(height: Insets.xxl),
                      Text('Coming up', style: AppType.title2()),
                      const SizedBox(height: Insets.sm),
                      for (var index = snapshot.stageIndex + 1;
                          index < _player.stages.length;
                          index++)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: Insets.sm,
                          ),
                          child: Text(
                            _stageLabel(_player.stages[index]),
                            style: AppType.callout(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      if (snapshot.stageIndex + 1 >= _player.stages.length)
                        Text(
                          'Finish and record your effort.',
                          style: AppType.callout(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                GlassSurface(
                  kind: GlassKind.nav,
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: snapshot.isDone
                              ? null
                              : () {
                                  _player.skipStage();
                                  setState(() {});
                                },
                          icon: const Icon(AppIcons.arrowRight),
                          label: const Text('Skip'),
                        ),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: snapshot.isDone
                                ? _finish
                                : () {
                                    snapshot.isRunning
                                        ? _player.pause()
                                        : _player.start();
                                    AppHaptics.selection();
                                    setState(() {});
                                  },
                            icon: Icon(
                              snapshot.isDone
                                  ? AppIcons.check
                                  : snapshot.isRunning
                                      ? AppIconsFill.pause
                                      : AppIconsFill.play,
                            ),
                            label: Text(
                              snapshot.isDone
                                  ? 'Finish'
                                  : snapshot.isRunning
                                      ? 'Pause'
                                      : 'Resume',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
