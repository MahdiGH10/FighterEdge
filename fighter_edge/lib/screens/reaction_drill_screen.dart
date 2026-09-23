import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n/gen/app_localizations.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_haptics.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../training/reaction/coach_voice.dart';
import '../training/reaction/reaction_drill.dart';
import '../training/reaction/reaction_drill_controller.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';
import 'reaction_drill_picker.dart';

/// A running reaction drill. Opens straight into the "get in stance"
/// countdown: the athlete already chose the drill, so one tap starts it.
///
/// Everything on this screen is read from the floor, two or three metres
/// away, while moving — so it is sized and paced for a glance, not for reading.
class ReactionDrillScreen extends StatefulWidget {
  final ReactionDrillSpec spec;

  /// Tests pass a seeded source; the app uses a fresh [Random] every run.
  final Random Function()? randomFactory;
  final int countdownSeconds;

  const ReactionDrillScreen({
    super.key,
    required this.spec,
    this.randomFactory,
    this.countdownSeconds = 3,
  });

  @override
  State<ReactionDrillScreen> createState() => _ReactionDrillScreenState();
}

class _ReactionDrillScreenState extends State<ReactionDrillScreen>
    with WidgetsBindingObserver {
  late final ReactionDrillController _drill;
  var _lastPhase = ReactionDrillPhase.ready;

  @override
  void initState() {
    super.initState();
    _drill = ReactionDrillController(
      spec: widget.spec,
      voice: context.read<CoachVoice>(),
      randomFactory: widget.randomFactory,
      countdownSeconds: widget.countdownSeconds,
    )..addListener(_onDrillChanged);
    WidgetsBinding.instance.addObserver(this);
    // The phone is usually on the floor or a bench during a drill; it must
    // not lock mid-drill and take the on-screen calls with it.
    _keepAwake(true);
    unawaited(_drill.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A phone call or a switch to the music app must not let the drill run
    // on unseen and unheard. It waits, paused, for the athlete to come back.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _drill.pause();
    }
  }

  void _onDrillChanged() {
    final phase = _drill.phase;
    if (phase != _lastPhase && phase == ReactionDrillPhase.finished) {
      AppHaptics.success();
    }
    _lastPhase = phase;
    setState(() {});
  }

  void _keepAwake(bool on) {
    // No wakelock on a platform (or in tests) only costs the screen staying
    // on; never worth an error.
    unawaited((on ? WakelockPlus.enable() : WakelockPlus.disable())
        .catchError((Object _) {}));
  }

  bool get _inProgress =>
      _drill.isRunning || _drill.phase == ReactionDrillPhase.paused;

  /// Back mid-drill holds the drill and asks, instead of silently throwing
  /// the run away.
  Future<void> _confirmLeave() async {
    _drill.pause();
    final l = L.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l.reactionLeaveTitle),
        content: Text(l.reactionLeaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.reactionLeaveStay),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.reactionLeaveConfirm),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (leave == true) {
      Navigator.of(context).pop();
    } else {
      unawaited(_drill.resume());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keepAwake(false);
    _drill
      ..removeListener(_onDrillChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final spec = widget.spec;
    return PopScope(
      canPop: !_inProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: ScreenScaffold(
        title:
            '${reactionDisciplineLabel(l, spec.discipline)} · ${reactionLevelLabel(l, spec.level)}',
        showBack: true,
        body: Padding(
          padding:
              const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Clock(drill: _drill),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.lg),
                  child: Center(child: _Stage(drill: _drill)),
                ),
              ),
              if (!_drill.hasVoice) ...[
                Text(
                  l.reactionNoVoice,
                  textAlign: TextAlign.center,
                  style: AppType.subhead(
                      color: AppAccessibility.textSecondary(context)),
                ),
                const SizedBox(height: Insets.md),
              ],
              _Actions(drill: _drill),
            ],
          ),
        ),
      ),
    );
  }
}

class _Clock extends StatelessWidget {
  final ReactionDrillController drill;
  const _Clock({required this.drill});

  @override
  Widget build(BuildContext context) {
    // Ready means the next tap starts a fresh run, whatever the last one
    // reached — so the clock shows the full drill.
    final fresh = drill.phase == ReactionDrillPhase.ready;
    final remaining = fresh ? drill.spec.duration : _remainingOnClock(drill);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          formatDrillClock(remaining),
          textAlign: TextAlign.center,
          style: AppType.title1(color: AppAccessibility.textSecondary(context)),
        ),
        const SizedBox(height: Insets.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.chip),
          child: LinearProgressIndicator(
            value: fresh ? 0 : drill.progress,
            minHeight: Insets.xs,
            color: AppColors.primary,
            backgroundColor: AppColors.track,
          ),
        ),
      ],
    );
  }
}

/// Time left as the clock shows it: rounded up, so it reads 0:30 at the start
/// rather than 0:29 — and anything else quoting it agrees with the clock.
Duration _remainingOnClock(ReactionDrillController drill) =>
    Duration(seconds: (drill.remaining.inMilliseconds / 1000).ceil());

/// The middle of the screen: countdown, the call, or the result.
class _Stage extends StatelessWidget {
  final ReactionDrillController drill;
  const _Stage({required this.drill});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final secondary = AppAccessibility.textSecondary(context);
    final Widget child = switch (drill.phase) {
      ReactionDrillPhase.ready => Column(
          key: const ValueKey('ready'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.reactionHeadline.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppType.title1(),
            ),
            // A stopped run says how far it got, so "ready" after Stop is
            // not mistaken for a drill that never started.
            if (drill.calls > 0) ...[
              const SizedBox(height: Insets.sm),
              Text(
                l.reactionStopped(formatDrillClock(drill.elapsed), drill.calls),
                textAlign: TextAlign.center,
                style: AppType.headline(color: secondary),
              ),
            ],
          ],
        ),
      ReactionDrillPhase.countdown => Column(
          key: ValueKey('countdown-${drill.countdown}'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${drill.countdown}',
                  textScaler: AppAccessibility.heroNumeralScaler(context),
                  style: AppType.stageNumeral(),
                ),
              ),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              l.reactionGetInStance,
              textAlign: TextAlign.center,
              style: AppType.title2(
                  color: AppAccessibility.accentText(context), spacing: 3),
            ),
          ],
        ),
      ReactionDrillPhase.live => _Call(
          key: ValueKey('call-${drill.calls}'),
          cue: drill.currentCue,
          number: drill.calls,
        ),
      ReactionDrillPhase.paused => Column(
          key: const ValueKey('paused'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.reactionPaused, style: AppType.display()),
            const SizedBox(height: Insets.xs),
            Text(
              l.reactionTimeLeft(formatDrillClock(_remainingOnClock(drill))),
              textAlign: TextAlign.center,
              style: AppType.headline(color: secondary),
            ),
          ],
        ),
      ReactionDrillPhase.finished => _Finished(drill: drill),
    };
    // Phase changes cross-fade quickly; within a live drill each call is a
    // new key, so the fade doubles as the "new call" signal.
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : MotionTokens.fast,
      child: child,
    );
  }
}

/// One call, as big as the screen allows. A seven-move sequence gets the same
/// type as a single move and only shrinks if it truly does not fit — the
/// hardest levels are where the athlete most needs to read it from the floor.
class _Call extends StatelessWidget {
  final ReactionCue? cue;
  final int number;
  const _Call({super.key, required this.cue, required this.number});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final commands = cue?.commands ?? const [];
    final sequence = commands.length > 1;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Each line fits the width on its own, so one long move ("Level change
    // – front roll") shrinks alone instead of shrinking the whole call.
    Widget lines(Color color, double width) => SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < commands.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : Insets.xs),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _MoveLine(
                      label: commands[i].label,
                      // In a sequence, the order is part of the call.
                      step: sequence ? i + 1 : null,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
        );

    return Semantics(
      label: cue?.spoken,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Two identical calls in a row still read as two calls.
          Text(
            l.reactionCallNumber(number),
            style: AppType.micro(color: AppAccessibility.textMuted(context)),
          ),
          const SizedBox(height: Insets.sm),
          Flexible(
            child: LayoutBuilder(
              // The whole call shrinks only if it is too tall for the screen.
              builder: (context, constraints) => FittedBox(
                fit: BoxFit.scaleDown,
                // A new call lands in the accent red and settles to white:
                // the change of colour is what a glance from the floor
                // catches.
                child: reduceMotion
                    ? lines(AppColors.textPrimary, constraints.maxWidth)
                    : TweenAnimationBuilder<Color?>(
                        tween: ColorTween(
                          begin: AppColors.accentText,
                          end: AppColors.textPrimary,
                        ),
                        duration: MotionTokens.reveal,
                        builder: (_, color, __) => lines(
                            color ?? AppColors.textPrimary,
                            constraints.maxWidth),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One move of a call. A compound move ("Level change – front roll") stays
/// on one line, its second half lighter, so it reads as one move, not two.
class _MoveLine extends StatelessWidget {
  final String label;
  final int? step;
  final Color color;
  const _MoveLine(
      {required this.label, required this.step, required this.color});

  @override
  Widget build(BuildContext context) {
    final style = AppType.display(color: color);
    final parts = label.toUpperCase().split(' – ');
    return Text.rich(
      TextSpan(
        children: [
          if (step != null)
            TextSpan(
              text: '$step  ',
              style: AppType.title1(color: AppAccessibility.textMuted(context)),
            ),
          TextSpan(text: parts.first),
          if (parts.length > 1)
            TextSpan(
              text: ' – ${parts.skip(1).join(' – ')}',
              style: style.copyWith(fontWeight: FontWeight.w400),
            ),
        ],
      ),
      textAlign: TextAlign.center,
      // Already scoreboard-sized and fitted to the screen; letting the
      // user's 200% text scale apply on top would only make short moves
      // balloon beside long ones that have to shrink back to fit.
      textScaler: AppAccessibility.heroNumeralScaler(context),
      style: style,
    );
  }
}

class _Finished extends StatelessWidget {
  final ReactionDrillController drill;
  const _Finished({required this.drill});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final spec = drill.spec;
    final next = spec.level.index + 1 < ReactionLevel.values.length
        ? ReactionLevel.values[spec.level.index + 1]
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.reactionTimeUp,
            style: AppType.display(color: AppColors.positive)),
        const SizedBox(height: Insets.xs),
        Text(
          l.reactionFinishedSummary(
              drill.calls, formatDrillClock(spec.duration)),
          textAlign: TextAlign.center,
          style:
              AppType.headline(color: AppAccessibility.textSecondary(context)),
        ),
        // Where to go from here: the natural next step is the next level.
        if (next != null) ...[
          const SizedBox(height: Insets.xs),
          Text(
            l.reactionNextLevel(reactionLevelLabel(l, next)),
            textAlign: TextAlign.center,
            style: AppType.callout(color: AppAccessibility.accentText(context)),
          ),
        ],
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  final ReactionDrillController drill;
  const _Actions({required this.drill});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return switch (drill.phase) {
      ReactionDrillPhase.countdown || ReactionDrillPhase.live => _Pair(
          first: GhostButton(
            l.reactionPause,
            icon: Icons.pause,
            expand: true,
            onPressed: drill.pause,
          ),
          second: GhostButton(
            l.reactionStop,
            icon: Icons.stop,
            expand: true,
            onPressed: drill.stop,
          ),
        ),
      ReactionDrillPhase.paused => _Pair(
          first: PrimaryButton(
            l.reactionResume,
            icon: Icons.play_arrow,
            expand: true,
            onPressed: drill.resume,
          ),
          second: GhostButton(
            l.reactionStop,
            icon: Icons.stop,
            expand: true,
            onPressed: drill.stop,
          ),
        ),
      ReactionDrillPhase.ready => PrimaryButton(
          l.reactionStart,
          icon: Icons.play_arrow,
          expand: true,
          onPressed: drill.start,
        ),
      ReactionDrillPhase.finished => _Pair(
          first: PrimaryButton(
            l.reactionAgain,
            icon: Icons.refresh,
            expand: true,
            onPressed: drill.start,
          ),
          second: GhostButton(
            l.reactionDone,
            expand: true,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
    };
  }
}

/// Two buttons side by side, stacked once large text would truncate them.
class _Pair extends StatelessWidget {
  final Widget first;
  final Widget second;
  const _Pair({required this.first, required this.second});

  @override
  Widget build(BuildContext context) {
    if (AppAccessibility.isLargeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [first, const SizedBox(height: Insets.sm), second],
      );
    }
    return Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: Insets.md),
        Expanded(child: second),
      ],
    );
  }
}
