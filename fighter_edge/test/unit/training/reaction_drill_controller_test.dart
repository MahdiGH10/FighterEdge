import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/training/reaction/coach_voice.dart';
import 'package:fighter_edge/training/reaction/reaction_drill.dart';
import 'package:fighter_edge/training/reaction/reaction_drill_controller.dart';

/// Records every line; "speaking" takes [lineTime] of fake time.
class RecordingVoice implements CoachVoice {
  final Duration lineTime;
  final lines = <String>[];
  var stops = 0;
  RecordingVoice({this.lineTime = Duration.zero});

  @override
  bool get isAvailable => true;
  @override
  Future<void> prepare() async {}
  @override
  Future<void> say(String line) async {
    lines.add(line);
    if (lineTime > Duration.zero) await Future<void>.delayed(lineTime);
  }

  @override
  Future<void> stop() async => stops++;
}

void main() {
  final spec = ReactionDrillSpec.of(
      ReactionDiscipline.grappling, ReactionLevel.beginner); // 30 s

  // testWidgets runs in fake time, so a 30-second drill takes no real time
  // and every timer is checked for leaks at the end.
  testWidgets('counts down, calls until time, then says "Time!"',
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
    expect(voice.lines, ['Get ready!']);

    await tester.pump(const Duration(seconds: 3));
    expect(drill.phase, ReactionDrillPhase.live);
    expect(drill.calls, 1, reason: 'the first call comes straight away');

    await tester.pump(const Duration(seconds: 15));
    expect(drill.phase, ReactionDrillPhase.live);
    final midway = drill.calls;
    // 1.0–1.5 s per call: 15 s holds 10–15 of them.
    expect(midway, inInclusiveRange(10, 16));

    await tester.pump(const Duration(seconds: 15));
    expect(drill.phase, ReactionDrillPhase.finished);
    expect(drill.remaining, Duration.zero);
    expect(drill.calls, inInclusiveRange(20, 31));
    expect(drill.commands, drill.calls, reason: 'wrestling: one move a call');
    await tester.pump();
    expect(voice.lines.last, 'Time!');
    expect(voice.lines.length, drill.calls + 2);

    drill.dispose();
  });

  testWidgets('the reaction gap starts after the voice finishes',
      (tester) async {
    final voice = RecordingVoice(lineTime: const Duration(seconds: 1));
    final drill = ReactionDrillController(
      spec: spec,
      voice: voice,
      countdownSeconds: 0,
      randomFactory: () => Random(1),
    );
    drill.start();
    await tester.pump(const Duration(milliseconds: 1900));
    // Call 1 takes a second to say, then the 1.0–1.5 s gap starts: the
    // second call cannot come before 2 s.
    expect(drill.calls, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(drill.calls, 2);
    drill.dispose();
    // Let the fake voice finish the line it was saying.
    await tester.pump(const Duration(seconds: 1));
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

    await tester.pump(const Duration(seconds: 60));
    expect(voice.lines.length, calls, reason: 'no calls after stopping');

    // And it starts clean again.
    drill.start();
    expect(drill.phase, ReactionDrillPhase.countdown);
    expect(drill.calls, 0);
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
    await tester.pump(const Duration(seconds: 31));
    final first = voice.lines.skip(1).take(7).toList();
    voice.lines.clear();
    drill.start();
    await tester.pump(const Duration(seconds: 31));
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
    await tester.pump(const Duration(seconds: 3 + 10)); // 10 s into the drill
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

    // Back into stance first, then the drill carries on where it was.
    drill.resume();
    expect(drill.phase, ReactionDrillPhase.countdown);
    expect(voice.lines.last, 'Get ready!');
    await tester.pump(const Duration(seconds: 3));
    expect(drill.phase, ReactionDrillPhase.live);
    expect(drill.calls, calls + 1);

    // Only the 20 s that were left remain.
    await tester.pump(const Duration(seconds: 19));
    expect(drill.phase, ReactionDrillPhase.live);
    await tester.pump(const Duration(seconds: 2));
    expect(drill.phase, ReactionDrillPhase.finished);
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

    // Starting again is a fresh run.
    drill.start();
    expect(drill.calls, 0);
    expect(drill.elapsed, Duration.zero);
    await tester.pump(const Duration(seconds: 1));
    drill.dispose();
  });
}
