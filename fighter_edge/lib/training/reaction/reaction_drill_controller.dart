import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'coach_voice.dart';
import 'reaction_cue_generator.dart';
import 'reaction_drill.dart';
import 'reaction_timing.dart';

enum ReactionDrillPhase { ready, countdown, live, rest, paused, finished }

/// Runs one reaction drill in real time: a short "get in stance" countdown,
/// then calls until the round's clock runs out, a timed rest, and the next
/// round, until the last one ends.
///
/// Each call is spoken to completion and *then* its gap starts, so the
/// athlete's reaction time never depends on how long a line takes to say.
/// The round clock, however, is the wall clock: a round lasts its full
/// duration, and when time is up the call in progress is cut off. A call
/// that could not finish before the round ends (its speech plus the least
/// time the athlete needs) is not started.
class ReactionDrillController extends ChangeNotifier {
  final ReactionDrillSpec spec;
  final CoachVoice _voice;
  final Random Function() _randomFactory;
  final int countdownSeconds;

  /// After a pause the athlete is only a step out of stance, so the countdown
  /// back in is shorter than the one that starts a drill or a round.
  static const resumeCountdownSeconds = 2;

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

  /// Work time elapsed in the current round.
  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  Duration _completedWork = Duration.zero;

  /// Work time over the whole drill so far, rests excluded.
  Duration get workElapsed => _completedWork + _elapsed;

  int _round = 1;

  /// The round being played (1-based). During a rest it is the next one.
  int get round => _round;
  int get rounds => spec.rounds;

  Duration _restLeft = Duration.zero;

  /// Whether the drill is in (or paused in) the rest between rounds.
  bool get isResting => _restLeft > Duration.zero;

  /// Time left on the clock the athlete sees: the rest while resting,
  /// otherwise the round.
  Duration get remaining =>
      isResting ? _restLeft : spec.roundDuration - _elapsed;

  double get progress => isResting
      ? (1 - _restLeft.inMilliseconds / spec.restDuration.inMilliseconds)
          .clamp(0, 1)
      : (_elapsed.inMilliseconds / spec.roundDuration.inMilliseconds)
          .clamp(0, 1);

  ReactionCue? _cue;

  /// The call being made or just made; null before the first one.
  ReactionCue? get currentCue => _cue;

  int _calls = 0;
  int get calls => _calls;

  bool get hasVoice => _voice.isAvailable;
  bool get isRunning =>
      _phase == ReactionDrillPhase.countdown ||
      _phase == ReactionDrillPhase.live ||
      _phase == ReactionDrillPhase.rest;

  ReactionCueGenerator? _generator;

  /// A call dealt too late in a round to say. It opens the next round, so the
  /// move the athlete last heard can never be repeated right after the break.
  ReactionCue? _unsaid;

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
    _unsaid = null;
    _elapsed = Duration.zero;
    _completedWork = Duration.zero;
    _round = 1;
    _restLeft = Duration.zero;
    _cue = null;
    _calls = 0;
    return _go(countdownSeconds);
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
  /// it goes through a short countdown again before the next call. A drill
  /// paused in a rest carries on resting first.
  Future<void> resume() {
    if (_phase != ReactionDrillPhase.paused) return Future.value();
    return _go(min(countdownSeconds, resumeCountdownSeconds));
  }

  /// Any rest still owed, the countdown, then calls until the round's clock
  /// runs out, continuing from [_elapsed] with the run's own generator.
  Future<void> _go(int countdownFrom) async {
    final run = ++_run;
    final generator = _generator!;

    if (isResting) {
      if (!await _rest(run)) return;
      // A rest ends with a full countdown into the next round.
      countdownFrom = countdownSeconds;
    }

    _cue = null;
    _phase = ReactionDrillPhase.countdown;
    _countdown = countdownFrom;
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
      if (_elapsed >= spec.roundDuration) {
        _endRound();
      } else {
        notifyListeners();
      }
    });

    while (run == _run) {
      final cue = _unsaid ?? generator.next();
      _unsaid = null;
      final left = spec.roundDuration - _elapsed;
      if (SpeechEstimate.expected(cue.spoken) + cue.minGap > left) {
        // Too late in the round to say this and give the athlete time to do
        // it. Keep it for the next round and stay quiet until this one ends.
        _unsaid = cue;
        await _wait(left > _tick ? left : _tick);
        continue;
      }
      _cue = cue;
      _calls++;
      notifyListeners();
      await _voice.say(cue.spoken);
      if (run != _run) return;
      await _wait(cue.gapAfter);
    }
  }

  /// Counts the rest down to the countdown that opens the next round.
  /// Returns false if the run was superseded.
  Future<bool> _rest(int run) async {
    _cue = null;
    _phase = ReactionDrillPhase.rest;
    notifyListeners();
    final lead = Duration(seconds: countdownSeconds);
    while (_restLeft > lead) {
      final step = _restLeft - lead < const Duration(seconds: 1)
          ? _restLeft - lead
          : const Duration(seconds: 1);
      await _wait(step);
      if (run != _run) return false;
      _restLeft -= step;
      notifyListeners();
    }
    _restLeft = Duration.zero;
    return true;
  }

  /// A round is over: the last one ends the drill, any other starts the rest.
  void _endRound() {
    if (_round >= spec.rounds) {
      _finish();
      return;
    }
    _halt();
    _completedWork += spec.roundDuration;
    _round++;
    _elapsed = Duration.zero;
    _restLeft = spec.restDuration;
    unawaited(_voice.stop().then((_) => _voice.say('Rest')));
    unawaited(_go(countdownSeconds));
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
    _elapsed = spec.roundDuration;
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
