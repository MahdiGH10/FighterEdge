import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/training/reaction/coach_voice.dart';
import 'package:fighter_edge/training/reaction/reaction_drill.dart';
import 'package:fighter_edge/training/reaction/reaction_drill_controller.dart';
import 'package:fighter_edge/training/reaction/reaction_timing.dart';

/// Records every line; "speaking" takes [lineTime] of fake time, or, when
/// [perSyllable] is set, that long per syllable (so long calls take longer).
class RecordingVoice implements CoachVoice {
  final Duration lineTime;
  final Duration? perSyllable;
  final DateTime Function()? now;
  final lines = <String>[];
  final starts = <DateTime>[];
  final ends = <DateTime>[];
  var stops = 0;
  RecordingVoice({this.lineTime = Duration.zero, this.perSyllable, this.now});

  DateTime _now() => now?.call() ?? DateTime(0);

  @override
  bool get isAvailable => true;
  @override
  Future<void> prepare() async {}
  @override
  Future<void> say(String line) async {
    final i = lines.length;
    lines.add(line);
    starts.add(_now());
    ends.add(_now());
    final took = perSyllable == null
        ? lineTime
        : perSyllable! * SpeechEstimate.syllables(line);
    if (took > Duration.zero) await Future<void>.delayed(took);
    ends[i] = _now();
  }

  @override
  Future<void> stop() async => stops++;
}

void main() {
  // 2 rounds of 1 minute with a minute between: the shortest real drill.
  final spec = ReactionDrillSpec.of(
      ReactionDiscipline.grappling, ReactionLevel.beginner);

  // testWidgets runs in fake time, so a multi-minute drill takes no real time
  // and every timer is checked for leaks at the end.
  testWidgets('counts down, calls, rests, calls again, then says "Time!"',
      (tester) async {
    final voice = RecordingVoice();
    final drill = ReactionDrillController(
      spec: spec,
      voice: voice,
      randomFactory: () => Random(1),
    );
    drill.start();
    expect(drill.phase, ReactionDrillPhase.countdown);
    expect(drill.countdown, 3);
    expect(drill.round, 1);
    expect(voice.lines, ['Get ready!']);

    await tester.pump(const Duration(seconds: 3));
    expect(drill.phase, ReactionDrillPhase.live);
    expect(drill.calls, 1, reason: 'the first call comes straight away');

    await tester.pump(const Duration(seconds: 30));
    expect(drill.phase, ReactionDrillPhase.live);
    // A wrestling call plus its gap is several seconds on Beginner.
    expect(drill.calls, inInclusiveRange(3, 12));

    // Round 1 ends at 1:03; the coach says Rest and the rest begins.
    await tester.pump(const Duration(seconds: 30)); // t = 63.0
    await tester.pump(const Duration(milliseconds: 100));
    expect(drill.phase, ReactionDrillPhase.rest);
    expect(drill.isResting, isTrue);
    expect(drill.round, 2, reason: 'rest shows the round that is coming');
    expect(drill.remaining.inSeconds, inInclusiveRange(55, 60));
    final callsInRound1 = drill.calls;
    expect(voice.lines.last, 'Rest');

    // Nothing is called while resting.
    await tester.pump(const Duration(seconds: 50)); // t = 113
    expect(drill.phase, ReactionDrillPhase.rest);
    expect(drill.calls, callsInRound1);

    // The last three seconds of the minute are the countdown in.
    await tester.pump(const Duration(seconds: 8)); // t = 121
    expect(drill.phase, ReactionDrillPhase.countdown);
    expect(drill.countdown, inInclusiveRange(1, 3));
    expect(voice.lines.last, 'Get ready!');
    expect(drill.remaining, spec.roundDuration, reason: 'a fresh round clock');

    await tester.pump(const Duration(seconds: 3)); // t = 124
    expect(drill.phase, ReactionDrillPhase.live);
    expect(drill.round, 2);
    expect(drill.calls, callsInRound1 + 1);

    await tester.pump(const Duration(seconds: 58)); // t = 182
    expect(drill.phase, ReactionDrillPhase.live);
    await tester.pump(const Duration(seconds: 2)); // t = 184
    expect(drill.phase, ReactionDrillPhase.finished);
    expect(drill.remaining, Duration.zero);
    expect(drill.workElapsed, spec.workDuration);
    await tester.pump();
    expect(voice.lines.last, 'Time!');
    expect(voice.lines.where((l) => l == 'Rest'), hasLength(1));
    expect(voice.lines.where((l) => l == 'Get ready!'), hasLength(2));
    expect(voice.lines.length, drill.calls + 4);

    drill.dispose();
  });

  testWidgets('the rest is as long as the spec says, countdown included',
      (tester) async {
    final voice = RecordingVoice(now: () => tester.binding.clock.now());
    final drill = ReactionDrillController(
      spec: spec,
      voice: voice,
      randomFactory: () => Random(2),
    );
    drill.start();
    await tester.pump(const Duration(seconds: 3) + spec.roundDuration);
    await tester.pump(const Duration(milliseconds: 150));
    final i = voice.lines.indexOf('Rest');
    expect(i, greaterThan(0));
    final restStart = voice.starts[i];

    await tester.pump(spec.restDuration + const Duration(seconds: 3));
    expect(voice.lines[i + 1], 'Get ready!');
    // The first call of round 2 follows "Get ready!" in the line log.
    final nextCall = voice.starts[i + 2];
    final gap = nextCall.difference(restStart);
    // Round clock stops on a 100 ms tick, so allow a tick either way.
    expect(gap.inMilliseconds, inInclusiveRange(59900, 60300));
    drill.dispose();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the reaction gap starts after the voice finishes',
      (tester) async {
    final voice = RecordingVoice(
      perSyllable: const Duration(milliseconds: 300),
      now: () => tester.binding.clock.now(),
    );
    const level = ReactionLevel.intermediate;
    final mma = ReactionDrillSpec.of(ReactionDiscipline.mma, level);
    final drill = ReactionDrillController(
      spec: mma,
      voice: voice,
      countdownSeconds: 0,
      randomFactory: () => Random(3),
    );
    drill.start();
    await tester.pump(const Duration(seconds: 100));

    final commands = {
      for (final c in ReactionDiscipline.mma.commands) c.spoken: c,
    };
    ReactionCommand parse(String line) =>
        commands[line.substring(0, line.length - 1)]!;

    final calls = [
      for (var i = 0; i < voice.lines.length; i++)
        if (voice.lines[i] != 'Get ready!') i,
    ];
    expect(calls.length, greaterThan(8));
    final speechTimes = <int>{};
    for (var k = 0; k + 1 < calls.length; k++) {
      final a = calls[k];
      final b = calls[k + 1];
      final took = voice.ends[a].difference(voice.starts[a]);
      speechTimes.add(took.inMilliseconds);
      final silence = voice.starts[b].difference(voice.ends[a]);
      final floor = ReactionTiming.floorMs(parse(voice.lines[a]), level);
      expect(silence.inMilliseconds, greaterThanOrEqualTo(floor),
          reason:
              'after ${voice.lines[a]}, which took ${took.inMilliseconds} ms');
    }
    expect(speechTimes.length, greaterThan(1),
        reason: 'the fake voice takes different times for different calls');
    drill.dispose();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('no call is started that cannot finish before its round ends',
      (tester) async {
    // The hardest drill: the fastest pace, rolls included.
    final hard = ReactionDrillSpec.of(
        ReactionDiscipline.mma, ReactionLevel.advancedPlus);
    final voice = RecordingVoice(
      perSyllable: const Duration(milliseconds: 190),
      now: () => tester.binding.clock.now(),
    );
    final drill = ReactionDrillController(
      spec: hard,
      voice: voice,
      randomFactory: () => Random(4),
    );
    final began = tester.binding.clock.now();
    drill.start();
    await tester.pump(hard.totalDuration + const Duration(seconds: 12));
    expect(drill.phase, ReactionDrillPhase.finished);

    final commands = {
      for (final c in ReactionDiscipline.mma.commands) c.spoken: c,
    };
    // Round r starts after the 3 s countdown (or the rest) and ends one round
    // later.
    final roundEnds = [
      for (var r = 0; r < hard.rounds; r++)
        began.add(const Duration(seconds: 3) +
            hard.roundDuration * (r + 1) +
            hard.restDuration * r),
    ];
    var checked = 0;
    for (var i = 0; i < voice.lines.length; i++) {
      final line = voice.lines[i];
      if (line == 'Get ready!' || line == 'Rest' || line == 'Time!') continue;
      final move = commands[line.substring(0, line.length - 1)]!;
      final start = voice.starts[i];
      final end = roundEnds.firstWhere((e) => !start.isAfter(e));
      final need = SpeechEstimate.expected(line) +
          Duration(milliseconds: ReactionTiming.floorMs(move, hard.level));
      // The round clock ticks every 100 ms, so allow one tick of slack.
      expect(
          start.add(need).isAfter(end.add(const Duration(milliseconds: 100))),
          isFalse,
          reason: '"$line" started with '
              '${end.difference(start).inMilliseconds} ms left');
      checked++;
    }
    expect(checked, greaterThan(30));
    drill.dispose();
  });

  testWidgets('stop ends the drill and leaves nothing running', (tester) async {
    final voice = RecordingVoice();
    final drill = ReactionDrillController(spec: spec, voice: voice);
    drill.start();
    await tester.pump(const Duration(seconds: 6));
    drill.stop();
    final calls = voice.lines.length;
    expect(drill.phase, ReactionDrillPhase.ready);
    expect(drill.currentCue, isNull);
    expect(voice.stops, 1);

    await tester.pump(const Duration(seconds: 200));
    expect(voice.lines.length, calls, reason: 'no calls after stopping');

    // And it starts clean again.
    drill.start();
    expect(drill.phase, ReactionDrillPhase.countdown);
    expect(drill.calls, 0);
    expect(drill.round, 1);
    drill.dispose();
  });

  testWidgets('stopping in a rest leaves nothing running either',
      (tester) async {
    final voice = RecordingVoice();
    final drill = ReactionDrillController(spec: spec, voice: voice);
    drill.start();
    await tester.pump(const Duration(seconds: 3 + 60 + 10));
    expect(drill.phase, ReactionDrillPhase.rest);
    drill.stop();
    expect(drill.phase, ReactionDrillPhase.ready);
    final lines = voice.lines.length;
    await tester.pump(const Duration(minutes: 5));
    expect(voice.lines.length, lines);
    drill.start();
    expect(drill.round, 1);
    expect(drill.isResting, isFalse);
    drill.dispose();
  });

  testWidgets('a new run is shuffled differently', (tester) async {
    final seeds = [1, 2].iterator;
    final voice = RecordingVoice();
    final drill = ReactionDrillController(
      spec: spec,
      voice: voice,
      countdownSeconds: 0,
      randomFactory: () => Random((seeds..moveNext()).current),
    );
    drill.start();
    await tester.pump(const Duration(seconds: 50));
    final first = voice.lines.skip(1).take(7).toList();
    drill.stop();
    voice.lines.clear();
    drill.start();
    await tester.pump(const Duration(seconds: 50));
    final second = voice.lines.skip(1).take(7).toList();
    expect(second, isNot(first));
    drill.dispose();
  });

  testWidgets('pause holds the clock and the calls; resume picks them up',
      (tester) async {
    final voice = RecordingVoice();
    final drill = ReactionDrillController(
      spec: spec,
      voice: voice,
      randomFactory: () => Random(1),
    );
    drill.start();
    await tester.pump(const Duration(seconds: 3 + 10)); // 10 s into round 1
    final elapsed = drill.elapsed;
    final calls = drill.calls;
    final stops = voice.stops;

    drill.pause();
    expect(drill.phase, ReactionDrillPhase.paused);
    expect(drill.isRunning, isFalse);
    expect(voice.stops, stops + 1, reason: 'a call in progress is cut off');

    await tester.pump(const Duration(minutes: 5));
    expect(drill.elapsed, elapsed, reason: 'the clock does not run');
    expect(drill.calls, calls, reason: 'no calls while paused');

    // Back into stance first (a short 2 s countdown, not the full 3 s), then
    // the drill carries on where it was.
    drill.resume();
    expect(drill.phase, ReactionDrillPhase.countdown);
    expect(drill.countdown, 2);
    expect(voice.lines.last, 'Get ready!');
    await tester.pump(const Duration(seconds: 1));
    expect(drill.phase, ReactionDrillPhase.countdown);
    await tester.pump(const Duration(seconds: 1));
    expect(drill.phase, ReactionDrillPhase.live);
    expect(drill.calls, calls + 1);

    // Only the 50 s that were left of round 1 remain.
    await tester.pump(const Duration(seconds: 49));
    expect(drill.phase, ReactionDrillPhase.live);
    expect(drill.round, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(drill.phase, ReactionDrillPhase.rest);
    drill.dispose();
  });

  testWidgets('the very first start keeps the full 3 s countdown',
      (tester) async {
    final drill = ReactionDrillController(spec: spec, voice: RecordingVoice());
    drill.start();
    expect(drill.countdown, 3);
    await tester.pump(const Duration(seconds: 2));
    expect(drill.phase, ReactionDrillPhase.countdown);
    await tester.pump(const Duration(seconds: 1));
    expect(drill.phase, ReactionDrillPhase.live);
    drill.dispose();
  });

  testWidgets('pausing in a rest keeps the rest, resume carries on resting',
      (tester) async {
    final voice = RecordingVoice();
    final drill = ReactionDrillController(
      spec: spec,
      voice: voice,
      randomFactory: () => Random(1),
    );
    drill.start();
    await tester.pump(const Duration(seconds: 3 + 60 + 20)); // 20 s into rest
    expect(drill.phase, ReactionDrillPhase.rest);
    final left = drill.remaining;
    expect(left.inSeconds, inInclusiveRange(35, 40));

    drill.pause();
    expect(drill.phase, ReactionDrillPhase.paused);
    await tester.pump(const Duration(minutes: 3));
    expect(drill.remaining, left, reason: 'the rest clock waits too');
    expect(drill.round, 2);

    drill.resume();
    expect(drill.phase, ReactionDrillPhase.rest,
        reason: 'no new countdown yet');
    await tester.pump(
        left - const Duration(seconds: 3) + const Duration(milliseconds: 100));
    expect(drill.phase, ReactionDrillPhase.countdown);
    expect(drill.countdown, inInclusiveRange(2, 3));
    await tester.pump(const Duration(seconds: 3));
    expect(drill.phase, ReactionDrillPhase.live);
    expect(drill.round, 2);
    drill.dispose();
  });

  testWidgets('pause and resume are no-ops when they make no sense',
      (tester) async {
    final drill = ReactionDrillController(spec: spec, voice: RecordingVoice());
    drill.pause();
    expect(drill.phase, ReactionDrillPhase.ready);
    drill.resume();
    expect(drill.phase, ReactionDrillPhase.ready);

    drill.start();
    await tester.pump(const Duration(seconds: 1));
    drill.resume(); // not paused
    expect(drill.phase, ReactionDrillPhase.countdown);
    drill.dispose();
  });

  testWidgets('a paused drill can be stopped, and remembers how far it got',
      (tester) async {
    final drill = ReactionDrillController(
      spec: spec,
      voice: RecordingVoice(),
      randomFactory: () => Random(1),
    );
    drill.start();
    await tester.pump(const Duration(seconds: 3 + 12));
    drill.pause();
    final calls = drill.calls;
    drill.stop();
    expect(drill.phase, ReactionDrillPhase.ready);
    expect(drill.calls, calls);
    expect(drill.elapsed.inSeconds, 12);
    expect(drill.workElapsed.inSeconds, 12);

    // Starting again is a fresh run.
    drill.start();
    expect(drill.calls, 0);
    expect(drill.elapsed, Duration.zero);
    expect(drill.workElapsed, Duration.zero);
    await tester.pump(const Duration(seconds: 1));
    drill.dispose();
  });
}
