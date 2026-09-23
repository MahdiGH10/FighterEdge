import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/screens/reaction_drill_screen.dart';
import 'package:fighter_edge/training/reaction/reaction_cue_generator.dart';
import 'package:fighter_edge/training/reaction/reaction_drill.dart';

import '../../helpers/test_harness.dart';

/// Performance guards for reaction drills. The bounds are deliberately
/// loose — this catches an accidental O(n²) or a runaway rebuild loop, not a
/// few milliseconds of noise. Measured numbers are printed for the report.
void main() {
  test('call generation is effectively free', () {
    for (final d in ReactionDiscipline.values) {
      final spec = ReactionDrillSpec.of(d, ReactionLevel.advancedPlus);
      final generator = ReactionCueGenerator(spec, random: Random(1));
      final watch = Stopwatch()..start();
      for (var i = 0; i < 100000; i++) {
        generator.next();
      }
      watch.stop();
      // ignore: avoid_print
      print('PERF generator ${d.name}: 100000 calls in '
          '${watch.elapsedMilliseconds} ms '
          '(${(watch.elapsedMicroseconds / 100000).toStringAsFixed(2)} µs/call)');
      // A whole 2.5-minute drill makes ~100 calls; 100k must stay far under
      // a second of work.
      expect(watch.elapsedMilliseconds, lessThan(2000));
    }
  });

  testWidgets('a full drill rebuilds the screen a bounded number of times',
      (tester) async {
    final spec = ReactionDrillSpec.of(
        ReactionDiscipline.grappling, ReactionLevel.advancedPlus); // 150 s
    final repo = await makeRepo(signedIn: true);
    var frames = 0;
    tester.binding.addPersistentFrameCallback((_) => frames++);
    await tester.pumpWidget(wrapApp(
      ReactionDrillScreen(spec: spec, randomFactory: () => Random(1)),
      repo: repo,
    ));

    final watch = Stopwatch()..start();
    // Pump every 16 ms like a real display, for the whole drill.
    const frame = Duration(milliseconds: 16);
    final total = const Duration(seconds: 3) + spec.duration;
    var pumped = Duration.zero;
    while (pumped < total + const Duration(seconds: 1)) {
      await tester.pump(frame);
      pumped += frame;
    }
    watch.stop();
    expect(find.text('TIME'), findsOneWidget);

    // The drill clock ticks 10×/s, and each new call's red-to-white flash
    // runs for ~23 frames — about 30/s on the fastest drill. Anything near
    // 60/s for the whole drill would mean something rebuilds every frame for
    // no reason.
    final seconds = total.inSeconds + 1;
    final perSecond = frames / seconds;
    // ignore: avoid_print
    print('PERF drill screen: $frames frames over $seconds s '
        '(${perSecond.toStringAsFixed(1)}/s); host build time '
        '${watch.elapsedMilliseconds} ms for ${pumped.inSeconds} s of drill');
    expect(perSecond, lessThan(45));
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving a drill releases every timer and listener',
      (tester) async {
    final spec = ReactionDrillSpec.of(
        ReactionDiscipline.striking, ReactionLevel.advanced);
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(wrapApp(
      ReactionDrillScreen(spec: spec, randomFactory: () => Random(1)),
      repo: repo,
    ));
    await tester.pump(const Duration(seconds: 20));
    // Replace the screen mid-drill; the test framework fails the test if
    // any timer is still pending afterwards.
    await tester.pumpWidget(wrapApp(const SizedBox(), repo: repo));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
  });
}
