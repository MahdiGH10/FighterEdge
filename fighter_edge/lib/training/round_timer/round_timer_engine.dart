import 'package:clock/clock.dart';

/// Where a round-timer session is.
enum RoundPhase { work, rest, done }

/// What the timer shows at one instant. Derived entirely from elapsed time,
/// so it can be recomputed at any moment, however long the app was away.
class RoundTimerSnapshot {
  final RoundPhase phase;

  /// 1-based. During a rest it is the round that just ended.
  final int round;
  final int totalRounds;

  /// Time left in the current phase. Zero once [phase] is [RoundPhase.done].
  final Duration remaining;

  /// Full length of the current phase, for progress rings.
  final Duration phaseLength;

  const RoundTimerSnapshot({
    required this.phase,
    required this.round,
    required this.totalRounds,
    required this.remaining,
    required this.phaseLength,
  });

  /// Whole seconds to display, rounded up: a fresh 5:00 round reads 05:00,
  /// its last moment reads 00:01, and it never sits on 00:00 while the
  /// phase is still running.
  int get displaySeconds {
    final micros = remaining.inMicroseconds;
    if (micros <= 0) return 0;
    return (micros + Duration.microsecondsPerSecond - 1) ~/
        Duration.microsecondsPerSecond;
  }

  /// 0 at the start of the phase, 1 at its end.
  double get progress {
    if (phaseLength <= Duration.zero) return phase == RoundPhase.done ? 1 : 0;
    final done = 1 - remaining.inMicroseconds / phaseLength.inMicroseconds;
    return done.clamp(0.0, 1.0);
  }

  bool get isFinalRound => round >= totalRounds;

  /// Same phase and round: nothing a fighter needs to be told about changed.
  bool sameStageAs(RoundTimerSnapshot other) =>
      phase == other.phase && round == other.round;
}

/// A rounds-and-rests clock anchored to wall time instead of counted ticks.
///
/// The old screen decremented a counter once per `Timer.periodic` tick.
/// Timers drift, and they stop entirely while the OS suspends a locked or
/// backgrounded app, so a 5:00 round could run for many minutes (audit
/// P-1). Here the only state is when the current run started and how much
/// was banked before it; every read derives the phase from elapsed wall
/// time. Ticks only repaint, and a resume after any gap shows the true
/// position at once.
///
/// Pure Dart and clock-injected, so it is tested without a widget tree.
class RoundTimerEngine {
  RoundTimerEngine({
    required this.rounds,
    required this.work,
    required this.rest,
    Clock? clock,
  })  : assert(rounds > 0),
        assert(work > Duration.zero),
        assert(rest >= Duration.zero),
        _clockOverride = clock;

  final int rounds;
  final Duration work;
  final Duration rest;

  /// Null means the zone's [clock], read on every call rather than
  /// captured, so fake time in tests (and `withClock`) drives the engine.
  final Clock? _clockOverride;

  DateTime _now() => (_clockOverride ?? clock).now();

  DateTime? _runningSince;
  Duration _banked = Duration.zero;

  /// Work plus every rest between rounds. No rest after the final round.
  Duration get totalLength => work * rounds + rest * (rounds - 1);

  bool get isRunning => _runningSince != null && !isDone;

  bool get isDone => elapsed >= totalLength;

  bool get hasStarted => elapsed > Duration.zero || _runningSince != null;

  Duration get elapsed {
    final since = _runningSince;
    final live = since == null ? Duration.zero : _now().difference(since);
    // A clock set backwards must not rewind the session.
    final total = _banked + (live.isNegative ? Duration.zero : live);
    return total > totalLength ? totalLength : total;
  }

  void start() {
    if (_runningSince != null || isDone) return;
    _runningSince = _now();
  }

  void pause() {
    if (_runningSince == null) return;
    _banked = elapsed;
    _runningSince = null;
  }

  void reset() {
    _runningSince = null;
    _banked = Duration.zero;
  }

  RoundTimerSnapshot snapshot() => snapshotAt(elapsed);

  /// The timer's state [at] a given elapsed time from the session start.
  RoundTimerSnapshot snapshotAt(Duration at) {
    if (at >= totalLength) {
      return RoundTimerSnapshot(
        phase: RoundPhase.done,
        round: rounds,
        totalRounds: rounds,
        remaining: Duration.zero,
        phaseLength: Duration.zero,
      );
    }
    final t = at.isNegative ? Duration.zero : at;
    final cycle = work + rest;
    final index = t.inMicroseconds ~/ cycle.inMicroseconds;
    final within = t - cycle * index;
    if (within < work) {
      return RoundTimerSnapshot(
        phase: RoundPhase.work,
        round: index + 1,
        totalRounds: rounds,
        remaining: work - within,
        phaseLength: work,
      );
    }
    return RoundTimerSnapshot(
      phase: RoundPhase.rest,
      round: index + 1,
      totalRounds: rounds,
      remaining: cycle - within,
      phaseLength: rest,
    );
  }
}
