import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/training/reaction/coach_voice.dart';
import 'package:fighter_edge/training/reaction/reaction_drill.dart';
import 'package:fighter_edge/training/reaction/reaction_drill_controller.dart';

/// Black-box conformance: every drill is run end to end and judged only by
/// what an athlete would hear — which lines were spoken, and when — against
/// the numbers in the product brief. Nothing here reads the spec's internal
/// timing tables.

/// A voice that takes realistic time to speak (a quarter second per move
/// plus a breath), can be cut off like a real engine, and logs each line in
/// the order it started.
class _EarVoice implements CoachVoice {
  final DateTime Function() now;
  final heard = <({String line, DateTime start, DateTime end})>[];
  Completer<void>? _speaking;
  _EarVoice(this.now);

  @override
  bool get isAvailable => true;
  @override
  Future<void> prepare() async {}

  @override
  Future<void> stop() async {
    final speaking = _speaking;
    if (speaking != null && !speaking.isCompleted) speaking.complete();
  }

  @override
  Future<void> say(String line) async {
    final start = now();
    final index = heard.length;
    heard.add((line: line, start: start, end: start));
    final moves = line.split(', ').length;
    final done = _speaking = Completer<void>();
    final timer = Timer(Duration(milliseconds: 200 + 250 * moves), () {
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    timer.cancel();
    heard[index] = (line: line, start: start, end: now());
  }
}

/// What the brief promises for each drill, in athlete terms.
class _Brief {
  final int seconds;
  final int minMoves;
  final int maxMoves;

  /// Silence after a call of `n` moves must fall in this range (seconds).
  final (double, double) Function(int moves) silence;
  const _Brief(this.seconds, this.minMoves, this.maxMoves, this.silence);
}

// "About X s" is judged with ±0.2 s; "up to X s" is judged as a hard cap.
(double, double) _about(double s) => (s - 0.2, s + 0.2);

final _briefs = <(ReactionDiscipline, ReactionLevel), _Brief>{
  // Wrestling: one command per call.
  (ReactionDiscipline.grappling, ReactionLevel.beginner):
      _Brief(30, 1, 1, (_) => (0.0, 1.5)),
  (ReactionDiscipline.grappling, ReactionLevel.intermediate):
      _Brief(60, 1, 1, (_) => _about(1.0)),
  // ~0.9 s, plus ~1 s pause every 3–4 calls.
  (ReactionDiscipline.grappling, ReactionLevel.advanced):
      _Brief(120, 1, 1, (_) => (0.7, 0.9 + 1.0 + 0.2)),
  (ReactionDiscipline.grappling, ReactionLevel.advancedPlus):
      _Brief(150, 1, 1, (_) => _about(1.0)),
  for (final d in [ReactionDiscipline.striking, ReactionDiscipline.mma]) ...{
    (d, ReactionLevel.beginner): _Brief(30, 1, 2, (_) => (0.0, 1.5)),
    // ~1.5 s; after a 3–4 move sequence, 1–1.5 s more.
    (d, ReactionLevel.intermediate): _Brief(90, 1, 4,
        (n) => n >= 3 ? (1.5 - 0.2 + 1.0, 1.5 + 0.2 + 1.5) : _about(1.5)),
    // 2 → ~1 s, 3 → ~1.5 s, 4–5 → ~2 s, then ~1.5 s more.
    (d, ReactionLevel.advanced): _Brief(
        150,
        2,
        5,
        (n) => switch (n) {
              2 => _about(1.0),
              3 => _about(1.5),
              _ => (2.0 - 0.2 + 1.5 - 0.2, 2.0 + 0.2 + 1.5 + 0.2),
            }),
    // Up to 7 moves; after 6–7, about 3 s of pause (on top of the move time).
    (d, ReactionLevel.advancedPlus): _Brief(90, 1, 7,
        (n) => n >= 6 ? (3.0 - 0.3 + 2.3, 3.0 + 0.3 + 2.7) : (0.8, 2.2)),
  },
};

void main() {
  for (final MapEntry(key: (discipline, level), value: brief)
      in _briefs.entries) {
    testWidgets('${discipline.name} ${level.name} matches the brief',
        (tester) async {
      final voice = _EarVoice(() => tester.binding.clock.now());
      final drill = ReactionDrillController(
        spec: ReactionDrillSpec.of(discipline, level),
        voice: voice,
        countdownSeconds: 3,
      );
      final began = tester.binding.clock.now();
      drill.start();

      // Just before time is up it is still live; just after, it is over.
      await tester.pump(Duration(seconds: 3 + brief.seconds) -
          const Duration(milliseconds: 200));
      expect(drill.phase, ReactionDrillPhase.live,
          reason: 'still running before ${brief.seconds} s');
      await tester.pump(const Duration(milliseconds: 400));
      expect(drill.phase, ReactionDrillPhase.finished);
      await tester.pump(const Duration(seconds: 5)); // let "Time!" finish

      final lines = voice.heard.map((h) => h.line).toList();
      expect(lines.first, 'Get ready!');
      expect(lines.last, 'Time!');
      final calls = voice.heard.sublist(1, voice.heard.length - 1);
      expect(calls, isNotEmpty);

      // The first call comes when the countdown ends.
      final firstAt = calls.first.start.difference(began);
      expect(firstAt.inMilliseconds, inInclusiveRange(3000, 3100));

      // Only moves from this drill's list, in 1..max-move calls, spoken as
      // bare commands with no filler.
      final vocabulary = {for (final c in discipline.commands) c.spoken};
      final heardMoves = <String>[];
      for (final call in calls) {
        expect(call.line, endsWith('!'));
        final moves = call.line.substring(0, call.line.length - 1).split(', ');
        expect(moves.length, inInclusiveRange(brief.minMoves, brief.maxMoves),
            reason: call.line);
        for (final m in moves) {
          expect(vocabulary, contains(m), reason: '"$m" is not on the list');
        }
        heardMoves.addAll(moves);
      }

      // Never the same move twice in a row.
      for (var i = 1; i < heardMoves.length; i++) {
        expect(heardMoves[i], isNot(heardMoves[i - 1]));
      }

      // The silence after each call (the athlete's reaction time) matches
      // the brief for that call's length. The last call may be cut by time.
      for (var i = 0; i + 1 < calls.length; i++) {
        final silence =
            calls[i + 1].start.difference(calls[i].end).inMilliseconds / 1000;
        final moves = calls[i].line.split(', ').length;
        final (lo, hi) = brief.silence(moves);
        expect(silence, inInclusiveRange(lo, hi),
            reason: 'after "${calls[i].line}"');
      }

      // A short drill still covers most of its list; a long one covers all.
      final distinct = heardMoves.toSet().length;
      if (heardMoves.length >= discipline.commands.length) {
        expect(distinct, discipline.commands.length,
            reason: 'every move comes up within one pass of the deck');
      }

      drill.dispose();
    });
  }

  testWidgets('two runs of the same drill are called in a different order',
      (tester) async {
    final spec = ReactionDrillSpec.of(
        ReactionDiscipline.grappling, ReactionLevel.beginner);
    Future<List<String>> run() async {
      final voice = _EarVoice(() => tester.binding.clock.now());
      final drill = ReactionDrillController(spec: spec, voice: voice);
      drill.start();
      await tester.pump(const Duration(seconds: 40));
      drill.dispose();
      return voice.heard.map((h) => h.line).skip(1).take(7).toList();
    }

    final orders = {for (var i = 0; i < 5; i++) (await run()).join(' ')};
    expect(orders.length, greaterThan(1));
  });
}
