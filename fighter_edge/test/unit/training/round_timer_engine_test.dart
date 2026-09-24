import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/training/round_timer/round_timer_engine.dart';

/// A clock the test moves by hand. Jumping it without any ticks is exactly
/// what a locked phone looks like to the engine.
class _ManualClock {
  DateTime now = DateTime(2026, 9, 24, 18);
  Clock get clock => Clock(() => now);
  void advance(Duration d) => now = now.add(d);
}

void main() {
  late _ManualClock time;

  RoundTimerEngine mma() => RoundTimerEngine(
        rounds: 5,
        work: const Duration(minutes: 5),
        rest: const Duration(minutes: 1),
        clock: time.clock,
      );

  setUp(() => time = _ManualClock());

  test('starts on round 1 of work showing the full round', () {
    final s = mma().snapshot();
    expect(s.phase, RoundPhase.work);
    expect(s.round, 1);
    expect(s.displaySeconds, 300);
    expect(s.progress, 0);
  });

  test('total length has no rest after the final round', () {
    expect(mma().totalLength, const Duration(minutes: 5 * 5 + 4));
  });

  test('does not move until started', () {
    final engine = mma();
    time.advance(const Duration(minutes: 3));
    expect(engine.snapshot().displaySeconds, 300);
    expect(engine.isRunning, isFalse);
  });

  group('boundaries (audit P-2: no extra second on 00:00)', () {
    test('the last moment of a round still reads 00:01', () {
      final engine = mma()..start();
      time.advance(
          const Duration(minutes: 5) - const Duration(milliseconds: 1));
      final s = engine.snapshot();
      expect(s.phase, RoundPhase.work);
      expect(s.displaySeconds, 1);
    });

    test('rest begins exactly when the round ends', () {
      final engine = mma()..start();
      time.advance(const Duration(minutes: 5));
      final s = engine.snapshot();
      expect(s.phase, RoundPhase.rest);
      expect(s.round, 1);
      expect(s.displaySeconds, 60);
    });

    test('round 2 begins exactly when the rest ends', () {
      final engine = mma()..start();
      time.advance(const Duration(minutes: 6));
      final s = engine.snapshot();
      expect(s.phase, RoundPhase.work);
      expect(s.round, 2);
      expect(s.displaySeconds, 300);
    });

    test('the session ends exactly at its total length', () {
      final engine = mma()..start();
      time.advance(engine.totalLength - const Duration(milliseconds: 1));
      expect(engine.snapshot().phase, RoundPhase.work);
      expect(engine.snapshot().round, 5);
      time.advance(const Duration(milliseconds: 1));
      expect(engine.snapshot().phase, RoundPhase.done);
      expect(engine.isDone, isTrue);
      expect(engine.isRunning, isFalse);
    });
  });

  group('wall-clock anchoring (audit P-1)', () {
    test('a locked phone skips no time: the position is exact on return', () {
      final engine = mma()..start();
      // 13 min 20 s with no ticks at all: round 3, 1:20 into the work.
      time.advance(const Duration(minutes: 13, seconds: 20));
      final s = engine.snapshot();
      expect(s.phase, RoundPhase.work);
      expect(s.round, 3);
      expect(s.displaySeconds, 220);
    });

    test('a gap longer than the session lands on done, not past it', () {
      final engine = mma()..start();
      time.advance(const Duration(hours: 2));
      expect(engine.snapshot().phase, RoundPhase.done);
      expect(engine.elapsed, engine.totalLength);
    });

    test('a clock set backwards never rewinds the session', () {
      final engine = mma()..start();
      time.advance(const Duration(minutes: 2));
      engine.pause();
      engine.start();
      time.advance(const Duration(minutes: -10));
      expect(engine.elapsed, const Duration(minutes: 2));
    });
  });

  group('pause and resume', () {
    test('paused time does not count', () {
      final engine = mma()..start();
      time.advance(const Duration(seconds: 30));
      engine.pause();
      time.advance(const Duration(minutes: 10));
      expect(engine.snapshot().displaySeconds, 270);
      engine.start();
      time.advance(const Duration(seconds: 30));
      expect(engine.snapshot().displaySeconds, 240);
    });

    test('start and pause are idempotent', () {
      final engine = mma()..start();
      time.advance(const Duration(seconds: 10));
      engine.start();
      time.advance(const Duration(seconds: 10));
      engine
        ..pause()
        ..pause();
      expect(engine.elapsed, const Duration(seconds: 20));
    });

    test('reset returns to the top of round 1', () {
      final engine = mma()..start();
      time.advance(const Duration(minutes: 7));
      engine.reset();
      expect(engine.hasStarted, isFalse);
      expect(engine.snapshot().round, 1);
      expect(engine.snapshot().displaySeconds, 300);
    });

    test('a finished session cannot be restarted without a reset', () {
      final engine = mma()..start();
      time.advance(const Duration(hours: 1));
      engine.pause();
      engine.start();
      expect(engine.isRunning, isFalse);
    });
  });

  test('progress runs 0 to 1 across a phase', () {
    final engine = mma()..start();
    time.advance(const Duration(seconds: 150));
    expect(engine.snapshot().progress, closeTo(0.5, 1e-9));
  });

  test('a single round has no rest at all', () {
    final engine = RoundTimerEngine(
      rounds: 1,
      work: const Duration(minutes: 3),
      rest: const Duration(minutes: 1),
      clock: time.clock,
    )..start();
    time.advance(const Duration(minutes: 3));
    expect(engine.snapshot().phase, RoundPhase.done);
  });

  test('zero-length rests go straight to the next round', () {
    final engine = RoundTimerEngine(
      rounds: 3,
      work: const Duration(minutes: 1),
      rest: Duration.zero,
      clock: time.clock,
    )..start();
    time.advance(const Duration(minutes: 1));
    final s = engine.snapshot();
    expect(s.phase, RoundPhase.work);
    expect(s.round, 2);
  });
}
