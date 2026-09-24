import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'coach_voice.dart';
import 'reaction_cue_generator.dart';
import 'reaction_drill.dart';

enum ReactionDrillPhase { ready, countdown, live, paused, finished }

/// Runs one reaction drill in real time: a short "get in stance" countdown,
/// then calls until the clock runs out.
///
/// Each call is spoken to completion and *then* its gap starts, so the
/// athlete's reaction time never depends on how long a line takes to say.
/// The drill clock, however, is the wall clock: a drill lasts its full
/// duration, and when time is up the call in progress is cut off.
class ReactionDrillController extends ChangeNotifier {
  final ReactionDrillSpec spec;
  final CoachVoice _voice;
  final Random Function() _randomFactory;
  final int countdownSeconds;

  static const _tick = Duration(milliseconds: 100);

  ReactionDrillController({
    required this.spec,
    required CoachVoice voice,
    Random Function()? randomFactory,
    this.countdownSeconds = 3,
  })  : _voice = voice,
        _randomFactory = randomFactory ?? Random.new {
    // Warm the engine while the athlete is still reading the screen.
    unawaited(_voice.prepare().then((_) {
      if (!_disposed) notifyListeners();
    }));
  }

  ReactionDrillPhase _phase = ReactionDrillPhase.ready;
  ReactionDrillPhase get phase => _phase;

  int _countdown = 0;

  /// Seconds left in the "get in stance" countdown.
  int get countdown => _countdown;

  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;
  Duration get remaining => spec.duration - _elapsed;
  double get progress =>
      (_elapsed.inMilliseconds / spec.duration.inMilliseconds).clamp(0, 1);

  ReactionCue? _cue;

  /// The call being made or just made; null before the first one.
  ReactionCue? get currentCue => _cue;

  int _calls = 0;
  int get calls => _calls;
  int _commands = 0;
  int get commands => _commands;

  bool get hasVoice => _voice.isAvailable;
  bool get isRunning =>
      _phase == ReactionDrillPhase.countdown ||
      _phase == ReactionDrillPhase.live;

  ReactionCueGenerator? _generator;

  // Bumped on every start/stop/finish; a loop that sees a different run id
  // after an await has been superseded and bails out.
  int _run = 0;
  Timer? _clock;
  Timer? _waitTimer;
  Completer<void>? _waitDone;
  bool _disposed = false;

  /// Starts a fresh run — from ready, finished, stopped or paused.
  Future<void> start() {
    if (isRunning) return Future.value();
    _halt();
    _generator = ReactionCueGenerator(spec, random: _randomFactory());
    _elapsed = Duration.zero;
    _cue = null;
    _calls = 0;
    _commands = 0;
    return _go();
  }

  /// Holds the drill where it is: the clock stops and the voice is cut off.
  void pause() {
    if (!isRunning) return;
    _halt();
    _phase = ReactionDrillPhase.paused;
    notifyListeners();
    unawaited(_voice.stop());
  }

  /// Picks a paused drill back up. The athlete has stepped out of stance, so
  /// it goes through the countdown again before the next call.
  Future<void> resume() {
    if (_phase != ReactionDrillPhase.paused) return Future.value();
    return _go();
  }

  /// The countdown, then calls until the clock runs out, continuing from
  /// [_elapsed] with the run's own generator.
  Future<void> _go() async {
    final run = ++_run;
    final generator = _generator!;
    _cue = null;
    _phase = ReactionDrillPhase.countdown;
    _countdown = countdownSeconds;
    notifyListeners();

    unawaited(_voice.say('Get ready!'));
    while (_countdown > 0) {
      await _wait(const Duration(seconds: 1));
      if (run != _run) return;
      _countdown--;
      notifyListeners();
    }

    _phase = ReactionDrillPhase.live;
    notifyListeners();
    final from = _elapsed;
    _clock = Timer.periodic(_tick, (timer) {
      _elapsed = from + _tick * timer.tick;
      if (_elapsed >= spec.duration) {
        _finish();
      } else {
        notifyListeners();
      }
    });

    while (run == _run) {
      final cue = generator.next();
      _cue = cue;
      _calls++;
      _commands += cue.commands.length;
      notifyListeners();
      await _voice.say(cue.spoken);
      if (run != _run) return;
      await _wait(cue.gapAfter);
    }
  }

  /// Ends the drill early and returns to the start screen state. [elapsed]
  /// and [calls] keep what the stopped run reached, until the next start.
  void stop() {
    if (!isRunning && _phase != ReactionDrillPhase.paused) return;
    _halt();
    _phase = ReactionDrillPhase.ready;
    _cue = null;
    notifyListeners();
    unawaited(_voice.stop());
  }

  void _finish() {
    _halt();
    _elapsed = spec.duration;
    _phase = ReactionDrillPhase.finished;
    notifyListeners();
    unawaited(_voice.stop().then((_) => _voice.say('Time!')));
  }

  void _halt() {
    _run++;
    _clock?.cancel();
    _clock = null;
    _waitTimer?.cancel();
    _waitTimer = null;
    final done = _waitDone;
    if (done != null && !done.isCompleted) done.complete();
  }

  /// A delay [_halt] can cut short, so a stopped drill leaves no timer
  /// running behind it.
  Future<void> _wait(Duration duration) {
    final done = _waitDone = Completer<void>();
    _waitTimer = Timer(duration, () {
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _halt();
    unawaited(_voice.stop());
    super.dispose();
  }
}
