import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../billing/subscription.dart';
import '../controllers/auth_controller.dart';
import '../data/mock_data.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/timer_style.dart';
import '../models/training_session.dart';
import '../routing/app_navigation.dart';
import '../routing/app_router.dart';
import '../state/app_state.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_haptics.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../training/corner_cues.dart';
import '../training/reaction/coach_voice.dart';
import '../training/round_timer/round_timer_engine.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/filter_chips.dart';
import '../widgets/premium_effects.dart';
import '../widgets/primary_button.dart';
import '../widgets/progress_ring.dart';
import '../widgets/stat_card.dart';
import 'paywall_screen.dart';

/// The round timer.
///
/// Time comes from [RoundTimerEngine], which derives the phase from elapsed
/// wall time. The periodic ticker only repaints, so the clock never drifts,
/// and after the app was locked or backgrounded it shows the true position
/// the moment it is seen again. While running, the screen is kept awake and
/// each phase change is called out loud (when a speech engine exists), felt
/// as a haptic, and announced to screen readers.
class RoundTimerScreen extends StatefulWidget {
  final TrainingSession? session;

  /// Tests may pin time. Null reads the zone's clock, which widget tests
  /// already fake.
  final Clock? clock;

  const RoundTimerScreen({super.key, this.session, this.clock});

  @override
  State<RoundTimerScreen> createState() => _RoundTimerScreenState();
}

class _RoundTimerScreenState extends State<RoundTimerScreen>
    with WidgetsBindingObserver {
  int _styleIndex = 1; // MMA
  late TimerStyle _style;
  late RoundTimerEngine _engine;
  late final ValueNotifier<RoundTimerSnapshot> _now;
  Timer? _ticker;

  /// The last phase/round the athlete was told about.
  late RoundTimerSnapshot _stage;
  int? _warnedRound;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _style = MockData.timerStyles[_styleIndex];
    _engine = _engineFor(_style);
    _stage = _engine.snapshot();
    _now = ValueNotifier(_stage);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _now.dispose();
    _keepAwake(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The session keeps running in wall time while the phone is locked or
    // another app is in front: a round does not pause because the screen
    // went dark. On return, re-read the engine so the clock is right at once.
    if (state == AppLifecycleState.resumed && _engine.hasStarted) {
      _refresh();
      _scheduleTick();
    }
  }

  RoundTimerEngine _engineFor(TimerStyle style) => RoundTimerEngine(
        rounds: style.rounds,
        work: Duration(seconds: style.workSeconds),
        rest: Duration(seconds: style.restSeconds),
        clock: widget.clock,
      );

  bool get _running => _engine.isRunning;
  bool get _done => _stage.phase == RoundPhase.done;

  void _selectStyle(int i) {
    _stopTicker();
    setState(() {
      _styleIndex = i;
      _style = MockData.timerStyles[i];
      _engine = _engineFor(_style);
      _stage = _engine.snapshot();
      _now.value = _stage;
      _warnedRound = null;
    });
  }

  void _toggle() {
    if (_done) {
      _reset();
      return;
    }
    if (_running) {
      _engine.pause();
      _stopTicker();
      setState(() {});
      return;
    }
    final firstStart = !_engine.hasStarted;
    _engine.start();
    _keepAwake(true);
    _scheduleTick();
    setState(() {});
    if (firstStart) _say(L.of(context).timerNextRound(1));
  }

  void _reset() {
    _stopTicker();
    _engine.reset();
    setState(() {
      _stage = _engine.snapshot();
      _now.value = _stage;
      _warnedRound = null;
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _keepAwake(false);
  }

  /// Wakes exactly when the displayed second next changes, computed from
  /// the engine rather than counted, so a late wake-up is corrected on the
  /// next one and the screen repaints once a second.
  void _scheduleTick() {
    _ticker?.cancel();
    if (!_engine.isRunning) return;
    final micros = _engine.snapshot().remaining.inMicroseconds %
        Duration.microsecondsPerSecond;
    // Dart timers never fire early, so waking on the boundary itself
    // already shows the new second.
    final wait = Duration(
      microseconds: micros == 0 ? Duration.microsecondsPerSecond : micros,
    );
    _ticker = Timer(wait, () {
      _refresh();
      _scheduleTick();
    });
  }

  void _refresh() {
    if (!mounted) return;
    final snapshot = _engine.snapshot();
    _now.value = snapshot;
    _maybeWarn(snapshot);
    if (!snapshot.sameStageAs(_stage)) _enterStage(snapshot);
  }

  /// "Ten seconds" once per work round, the way a corner calls it.
  void _maybeWarn(RoundTimerSnapshot s) {
    if (s.phase != RoundPhase.work || _warnedRound == s.round) return;
    if (s.displaySeconds > 10 || s.displaySeconds == 0) return;
    if (s.phaseLength <= const Duration(seconds: 10)) return;
    _warnedRound = s.round;
    _say(L.of(context).timerCallTenSeconds);
  }

  void _enterStage(RoundTimerSnapshot s) {
    final l = L.of(context);
    setState(() => _stage = s);
    switch (s.phase) {
      case RoundPhase.work:
        _buzz(AppHaptics.commit);
        _say(l.timerNextRound(s.round));
        _announce(l.timerAnnounceWork(s.round, s.totalRounds));
      case RoundPhase.rest:
        _buzz(AppHaptics.commit);
        _say(l.timerCallRest);
        _announce(l.timerAnnounceRest(s.round));
      case RoundPhase.done:
        _stopTicker();
        _buzz(AppHaptics.success);
        _say(l.timerCallTime);
        _announce(l.timerAnnounceDone);
        final session = widget.session;
        if (session != null) {
          context.read<AppState>().completeSession(
                session,
                rpe: 7,
                note: 'Completed from round timer',
              );
        }
    }
  }

  void _buzz(FutureOr<void> Function() pattern) {
    if (_optional<AppState>()?.timerHaptics ?? true) pattern();
  }

  void _say(String line) {
    final voice = _optional<CoachVoice>();
    if (voice != null && voice.isAvailable) unawaited(voice.say(line));
  }

  void _announce(String message) {
    unawaited(SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    ));
  }

  /// The timer is also opened from places (and tests) without every app
  /// provider above it; a missing one just means that cue is skipped.
  T? _optional<T>() {
    try {
      return Provider.of<T>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  void _keepAwake(bool on) {
    // A plugin missing on a platform (or in tests) only costs the screen
    // staying on; never worth an error.
    unawaited((on ? WakelockPlus.enable() : WakelockPlus.disable())
        .catchError((Object _) {}));
  }

  String _phaseLabel(L l, RoundPhase phase) => switch (phase) {
        RoundPhase.work => l.timerWork,
        RoundPhase.rest => l.timerRest,
        RoundPhase.done => l.timerDone,
      };

  String _nextLabel(L l, RoundTimerSnapshot s) => switch (s.phase) {
        RoundPhase.done => l.timerNextSessionComplete,
        RoundPhase.work =>
          s.isFinalRound ? l.timerNextFinalRound : l.timerNextRest,
        RoundPhase.rest => l.timerNextRound(s.round + 1),
      };

  int _nextSeconds(RoundTimerSnapshot s) => switch (s.phase) {
        RoundPhase.work => s.isFinalRound ? 0 : _style.restSeconds,
        RoundPhase.rest => _style.workSeconds,
        RoundPhase.done => 0,
      };

  Color _phaseColor(RoundPhase phase) =>
      phase == RoundPhase.rest ? AppColors.warning : AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final stage = _stage;
    final phaseLabel = _phaseLabel(l, stage.phase);
    final phaseColor = _phaseColor(stage.phase);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ScreenScaffold(
      title: l.timerTitle,
      showBack: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
        child: Column(
          children: [
            FilterChips(
              options: [for (final s in MockData.timerStyles) s.name],
              selectedIndex: _styleIndex,
              onSelected: _selectStyle,
              scrollable: false,
            ),
            const SizedBox(height: Insets.xxl),
            Text(l.timerRound,
                style: AppAccessibility.adjustStyle(
                  context,
                  AppType.subhead(
                      weight: FontWeight.w600,
                      color: AppAccessibility.textSecondary(context)),
                )),
            const SizedBox(height: Insets.xxs),
            Text('${stage.round} / ${stage.totalRounds}',
                style: AppType.title1()),
            const SizedBox(height: Insets.xl),
            // Only the ring and the clock repaint on every tick; the rest of
            // the screen rebuilds when the phase or round changes.
            RepaintBoundary(
              child: ValueListenableBuilder<RoundTimerSnapshot>(
                valueListenable: _now,
                builder: (context, now, _) {
                  final seconds = now.displaySeconds;
                  final urgent =
                      _running && now.phase == RoundPhase.work && seconds <= 10;
                  return TweenAnimationBuilder<double>(
                    key: ValueKey(urgent ? seconds : phaseLabel),
                    tween: Tween(begin: urgent ? 1.035 : 1.0, end: 1.0),
                    duration:
                        reduceMotion ? Duration.zero : MotionTokens.reveal,
                    curve: MotionTokens.settle,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: ProgressRing(
                      progress: now.progress,
                      size: 260,
                      strokeWidth: urgent ? 14 : 12,
                      color: phaseColor,
                      trackColor: urgent
                          ? AppColors.primarySoft.withValues(alpha: .35)
                          : AppColors.track,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Read on demand, not announced every second:
                          // phase changes are announced separately.
                          Semantics(
                            label: l.timerClockSemantics(
                                seconds ~/ 60, seconds % 60),
                            excludeSemantics: true,
                            child: Text(_fmt(seconds),
                                textScaler:
                                    AppAccessibility.heroNumeralScaler(context),
                                style: AppType.heroNumeral(
                                    color: AppColors.textPrimary)),
                          ),
                          const SizedBox(height: Insets.xs),
                          Text(phaseLabel,
                              style: AppType.title2(
                                  color: phaseColor, spacing: 3)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: Insets.xl),
            Text(l.timerNext(_nextLabel(l, stage)),
                style: AppAccessibility.adjustStyle(
                  context,
                  AppType.subhead(
                      weight: FontWeight.w500,
                      color: AppAccessibility.textSecondary(context)),
                )),
            const SizedBox(height: Insets.xxs),
            Text(_fmt(_nextSeconds(stage)), style: AppType.title1()),
            // The minute between rounds is when a corner talks. Keyed by
            // round so each rest's cue arrives fresh.
            if (stage.phase == RoundPhase.rest) ...[
              const SizedBox(height: Insets.xl),
              PremiumReveal(
                key: ValueKey('cue-${stage.round}'),
                child:
                    context.watch<AuthController>().allows(Feature.cornerCoach)
                        ? _CornerCueCard(
                            cue: CornerCues.forRest(
                              style: _style.name,
                              upcomingRound: stage.round + 1,
                              rounds: _style.rounds,
                            ),
                          )
                        : const _CornerCueTeaser(),
              ),
            ],
            const SizedBox(height: Insets.xxl),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    _done
                        ? l.timerRestart
                        : (_running ? l.timerPause : l.timerStart),
                    icon: _done
                        ? Icons.refresh
                        : (_running ? Icons.pause : Icons.play_arrow),
                    expand: true,
                    color: _running ? AppColors.primaryDark : AppColors.primary,
                    onPressed: _toggle,
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: GhostButton(l.timerReset,
                      icon: Icons.stop, expand: true, onPressed: _reset),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _CornerCueCard extends StatelessWidget {
  final CornerCue cue;
  const _CornerCueCard({required this.cue});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: AppCard(
        accent: AppColors.warning,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L.of(context).timerYourCorner,
              style: AppType.micro(
                weight: FontWeight.w800,
                color: AppAccessibility.textMuted(context),
                spacing: .8,
              ),
            ),
            const SizedBox(height: Insets.sm),
            Text(cue.tactical, style: AppType.headline()),
            const SizedBox(height: Insets.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.air_rounded,
                    size: IconSizes.inline,
                    color: AppAccessibility.textSecondary(context)),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    cue.recovery,
                    style: AppType.callout(
                        color: AppAccessibility.textSecondary(context)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What a free account sees in the rest instead of the cue: one quiet line,
/// never a blocking lock in the middle of a session.
class _CornerCueTeaser extends StatelessWidget {
  const _CornerCueTeaser();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => AppNavigation.push(
        context,
        AppRoutes.paywall,
        extra: const PaywallRouteArgs(
          highlight: Feature.cornerCoach,
          trigger: PaywallTrigger.cornerCoach,
        ),
        fallbackBuilder: (_) => const PaywallScreen(
          highlight: Feature.cornerCoach,
          trigger: PaywallTrigger.cornerCoach,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.record_voice_over,
              size: IconSizes.inline, color: AppColors.premium),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              L.of(context).timerCornerTeaser,
              style: AppType.subhead(
                  color: AppAccessibility.textSecondary(context)),
            ),
          ),
          Icon(Icons.chevron_right, color: AppAccessibility.textMuted(context)),
        ],
      ),
    );
  }
}
