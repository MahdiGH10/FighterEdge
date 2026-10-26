import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/training/reaction/coach_voice.dart';
import 'package:fighter_edge/training/reaction/reaction_drill.dart';
import 'package:fighter_edge/training/reaction/reaction_drill_controller.dart';
import 'package:fighter_edge/training/reaction/reaction_timing.dart';

/// Black-box conformance: every drill is run end to end and judged only by
/// what an athlete would hear — which lines were spoken, and when — against
/// the numbers in the product brief. The brief's numbers are written out
/// again below, on purpose: nothing here reads the app's timing tables, so a
/// typo in one of them cannot hide behind a test that reads the same typo.

/// A voice that takes realistic time to speak (the speech estimate: 190 ms a
/// syllable plus a quarter second), can be cut off like a real engine, and logs each line in
/// the order it started. Long calls take longer to say than short ones.
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
    final done = _speaking = Completer<void>();
    final timer = Timer(SpeechEstimate.expected(line), () {
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    timer.cancel();
    heard[index] = (line: line, start: start, end: now());
  }
}

/// What the brief promises for one level.
class _Level {
  final int marginMs;
  final double speed;
  final double jitter;
  final int workMinutes;

  /// Wrestling only: extra seconds every `calls` calls, or null for none.
  final (int, int, int)? blockRest;
  const _Level(
      this.marginMs, this.speed, this.jitter, this.workMinutes, this.blockRest);
}

const _brief = {
  ReactionLevel.beginner: _Level(1500, 1.3, 0.25, 1, (3, 4, 3000)),
  ReactionLevel.intermediate: _Level(1100, 1.15, 0.25, 2, (4, 5, 2500)),
  ReactionLevel.advanced: _Level(800, 1.0, 0.30, 3, (5, 6, 2000)),
  ReactionLevel.advancedPlus: _Level(600, 0.9, 0.35, 3, null),
};

/// Combo cost of each spoken call, in ms, from the brief.
const _cost = {
  'Jab': 300, 'Cross': 400, 'Hook': 450, 'Back hook': 450, //
  'Uppercut': 450, 'Lead uppercut': 450,
  'Teep': 800, 'Low kick': 900, 'Middle kick': 1100, 'High kick': 1250,
  'Slip left': 400, 'Slip right': 400,
  'Step left': 400, 'Step right': 400, 'Step back': 400, 'Step in': 400,
  'Pivot left': 500, 'Pivot right': 500,
  'Level change': 600, 'Kick check': 600, 'Down block': 700, 'Jump': 700,
  'Sprawl': 1300, 'Shoot': 1800, 'Front roll': 2500, 'Cartwheel': 2500,
  'Back roll': 3000,
  'Level change front roll': 3100, 'Level change back roll': 3600,
};

const _kicks = {'Teep', 'Low kick', 'Middle kick', 'High kick'};
const _grapplingCalls = {
  'Sprawl', 'Shoot', 'Front roll', 'Cartwheel', 'Back roll', //
  'Level change front roll', 'Level change back roll',
};

/// The brief's finish cost: 300 ms after a punch or footwork, 500 ms after a
/// kick, 500 ms after a grappling move.
int _finish(String last) =>
    (_kicks.contains(last) || _grapplingCalls.contains(last)) ? 500 : 300;

void main() {
  for (final discipline in ReactionDiscipline.values) {
    for (final level in ReactionLevel.values) {
      final brief = _brief[level]!;
      final grappling = discipline == ReactionDiscipline.grappling;
      final rounds = grappling ? 2 : 3;
      final work = Duration(minutes: brief.workMinutes);
      const rest = Duration(minutes: 1);
      const countdown = Duration(seconds: 3);

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

        // Just before the last round ends it is still live; just after, over.
        final overAt = countdown + work * rounds + rest * (rounds - 1);
        await tester.pump(overAt - const Duration(milliseconds: 200));
        expect(drill.phase, ReactionDrillPhase.live,
            reason: 'still running before the last bell');
        await tester.pump(const Duration(milliseconds: 400));
        expect(drill.phase, ReactionDrillPhase.finished);
        await tester.pump(const Duration(seconds: 5)); // let "Time!" finish

        // The coach announces the structure: Get ready, (Rest, Get ready)
        // between rounds, and Time at the end.
        final lines = voice.heard.map((h) => h.line).toList();
        final announcements = lines
            .where((l) => const {'Get ready!', 'Rest', 'Time!'}.contains(l))
            .toList();
        expect(announcements, [
          'Get ready!',
          for (var r = 1; r < rounds; r++) ...['Rest', 'Get ready!'],
          'Time!',
        ]);
        expect(lines.first, 'Get ready!');
        expect(lines.last, 'Time!');

        // Split the calls by round, by when each started.
        List<({String line, DateTime start, DateTime end})> inRound(int r) {
          final from = began.add(
              countdown + (work + rest) * r - const Duration(milliseconds: 1));
          final to = from.add(work + const Duration(milliseconds: 100));
          return [
            for (final h in voice.heard)
              if (!const {'Get ready!', 'Rest', 'Time!'}.contains(h.line) &&
                  h.start.isAfter(from) &&
                  !h.start.isAfter(to))
                h,
          ];
        }

        final callsByRound = [for (var r = 0; r < rounds; r++) inRound(r)];
        final allCalls = [for (final c in callsByRound) ...c];
        final spokenCalls = voice.heard
            .where(
                (h) => !const {'Get ready!', 'Rest', 'Time!'}.contains(h.line))
            .toList();
        expect(allCalls.length, spokenCalls.length,
            reason: 'every call falls inside a round, none in a rest');

        final vocabulary = {for (final c in discipline.commands) c.spoken};
        final heardMoves = <String>[];
        for (var r = 0; r < rounds; r++) {
          final calls = callsByRound[r];
          expect(calls, isNotEmpty, reason: 'round ${r + 1} has calls');

          // Each round opens on its own countdown: the first call is on the
          // bell, after a 3 s countdown that follows the rest.
          final roundStart = began.add(countdown + (work + rest) * r);
          expect(calls.first.start.difference(roundStart).inMilliseconds,
              inInclusiveRange(0, 100),
              reason: 'round ${r + 1} starts on time');
          final roundEnd = roundStart.add(work);

          for (var i = 0; i < calls.length; i++) {
            final call = calls[i];
            expect(call.line, endsWith('!'));
            // One move per call, said on its own.
            final move = call.line.substring(0, call.line.length - 1);
            expect(vocabulary, contains(move),
                reason: '"$move" is not on the list');
            expect(_cost, contains(move),
                reason: '"$move" has no cost in the brief');
            heardMoves.add(move);

            final movement = brief.speed * (_cost[move]! + _finish(move));

            // No call overruns its round: it is said and the athlete has at
            // least the time the movement itself takes before the bell.
            expect(
                call.end
                    .add(Duration(milliseconds: movement.round() + 300))
                    .difference(roundEnd)
                    .inMilliseconds,
                lessThanOrEqualTo(100),
                reason: '"${call.line}" overruns round ${r + 1}');

            if (i + 1 == calls.length) continue;
            // The silence after a call (the athlete's time) is the movement
            // plus a jittered reaction time, never below movement + 300 ms.
            final silence =
                calls[i + 1].start.difference(call.end).inMilliseconds;
            final reaction = brief.marginMs;
            final lo =
                max(movement + 300, movement + reaction * (1 - brief.jitter));
            // Up to +2 s breather on top; wrestling may add a block rest.
            final extra = (brief.blockRest?.$3 ?? 0) + 2000;
            final hi = movement + reaction * (1 + brief.jitter) + extra;
            expect(silence, inInclusiveRange(lo.floor() - 1, hi.ceil() + 1),
                reason: 'after "${call.line}"');
          }
        }

        // Never the same move twice in a row.
        for (var i = 1; i < heardMoves.length; i++) {
          expect(heardMoves[i], isNot(heardMoves[i - 1]));
        }

        // A long drill covers its whole list.
        if (heardMoves.length >= discipline.commands.length * 2) {
          expect(heardMoves.toSet().length, discipline.commands.length,
              reason: 'every move comes up within a pass of the deck');
        }

        drill.dispose();
      });
    }
  }

  testWidgets('two runs of the same drill are called in a different order',
      (tester) async {
    final spec = ReactionDrillSpec.of(
        ReactionDiscipline.grappling, ReactionLevel.beginner);
    Future<List<String>> run() async {
      final voice = _EarVoice(() => tester.binding.clock.now());
      final drill = ReactionDrillController(spec: spec, voice: voice);
      drill.start();
      await tester.pump(const Duration(seconds: 60));
      drill.dispose();
      return voice.heard.map((h) => h.line).skip(1).take(7).toList();
    }

    final orders = {for (var i = 0; i < 5; i++) (await run()).join(' ')};
    expect(orders.length, greaterThan(1));
  });
}
