import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/screens/reaction_drill_picker.dart';
import 'package:fighter_edge/observability/telemetry.dart';
import 'package:fighter_edge/screens/reaction_drill_screen.dart';
import 'package:fighter_edge/screens/training_camp_screen.dart';
import 'package:fighter_edge/training/reaction/coach_voice.dart';
import 'package:fighter_edge/training/reaction/reaction_cue_generator.dart';
import 'package:fighter_edge/training/reaction/reaction_drill.dart';

import '../helpers/test_harness.dart';

/// Longer than the call cross-fade, so the previous call has fully left.
const _callSettle = Duration(milliseconds: 400);

void main() {
  testWidgets('Train > Reaction picks a drill and shows what it asks',
      (tester) async {
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(wrapApp(const TrainingCampScreen(), repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reaction'));
    await tester.pumpAndSettle();
    expect(find.byType(ReactionDrillPicker), findsOneWidget);
    expect(find.text('THE COACH CALLS IT. YOU REACT.'), findsOneWidget);
    // MMA beginner by default: 30 s, up to two moves, 24 commands.
    expect(find.text('0:30'), findsOneWidget);
    expect(find.text('1–2'), findsOneWidget);
    expect(find.text('IN THE MIX · 24'), findsOneWidget);

    await tester.tap(find.text('Wrestling'));
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.text('2:00'), findsOneWidget);
    expect(find.text('IN THE MIX · 7'), findsOneWidget);
    expect(find.textContaining('Cartwheel'), findsOneWidget);

    // Buttons render their label in capitals.
    await tester.scrollUntilVisible(
      find.text('START DRILL'),
      200,
      scrollable: find
          .descendant(
              of: find.byType(ReactionDrillPicker),
              matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('START DRILL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ReactionDrillScreen), findsOneWidget);
    expect(find.text('GET IN STANCE'), findsOneWidget);
    expect(find.text('WRESTLING · ADVANCED'), findsOneWidget);

    // Leaving mid-drill stops it cleanly.
    Navigator.of(tester.element(find.byType(ReactionDrillScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(ReactionDrillScreen), findsNothing);
  });

  testWidgets('the drill screen shows each call as it is made, then the result',
      (tester) async {
    final spec = ReactionDrillSpec.of(
        ReactionDiscipline.striking, ReactionLevel.beginner);
    final expected = ReactionCueGenerator(spec, random: Random(3));
    final repo = await makeRepo(signedIn: true);
    final telemetry = MemoryTelemetry();
    await tester.pumpWidget(wrapApp(
      ReactionDrillScreen(spec: spec, randomFactory: () => Random(3)),
      repo: repo,
      telemetry: telemetry,
    ));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    expect(find.text('0:30'), findsOneWidget);
    expect(find.text('STOP'), findsOneWidget);
    expect(find.text('No voice on this device. Follow the calls on screen.'),
        findsOneWidget,
        reason: 'the test harness has no speech engine, and says so');

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(_callSettle);
    final first = expected.next();
    for (final c in first.commands) {
      expect(findDrillMove(c.label), findsOneWidget);
    }

    await tester.pump(const Duration(seconds: 31));
    await tester.pump(_callSettle);
    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('GO AGAIN'), findsOneWidget);
    expect(telemetry.records, hasLength(1));
    expect(
        telemetry.records.single.event, TelemetryEvent.reactionDrillFinished);
    expect(telemetry.records.single.parameters,
        {'discipline': 'striking', 'level': 'beginner'});

    await tester.tap(find.text('GO AGAIN'));
    await tester.pump();
    expect(find.text('GET IN STANCE'), findsOneWidget);
    await tester.tap(find.text('STOP'));
    await tester.pump();
    expect(find.text('START DRILL'), findsOneWidget);
    expect(telemetry.records, hasLength(1),
        reason: 'stopping a restarted drill does not count as a finish');
  });

  final grapplingBeginner = ReactionDrillSpec.of(
      ReactionDiscipline.grappling, ReactionLevel.beginner); // 30 s

  Future<void> openDrill(WidgetTester tester) async {
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(wrapApp(
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ReactionDrillScreen(
                spec: grapplingBeginner,
                randomFactory: () => Random(1),
              ),
            )),
            child: const Text('open'),
          ),
        ),
      ),
      repo: repo,
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('pause and resume from the drill screen', (tester) async {
    await openDrill(tester);
    await tester.pump(const Duration(seconds: 3 + 10));
    await tester.tap(find.text('PAUSE'));
    await tester.pump(_callSettle);
    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('0:20 left'), findsOneWidget);
    expect(find.text('RESUME'), findsOneWidget);

    await tester.pump(const Duration(minutes: 1));
    expect(find.text('PAUSED'), findsOneWidget, reason: 'it waits');

    await tester.tap(find.text('RESUME'));
    await tester.pump(_callSettle);
    expect(find.text('GET IN STANCE'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(_callSettle);
    expect(find.text('CALL 1'), findsNothing,
        reason: 'the call count carries on from before the pause');
    await tester.pump(const Duration(seconds: 21));
    await tester.pump(_callSettle);
    expect(find.text('TIME'), findsOneWidget);
  });

  testWidgets('leaving the app pauses the drill', (tester) async {
    await openDrill(tester);
    await tester.pump(const Duration(seconds: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(_callSettle);
    expect(find.text('PAUSED'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('PAUSED'), findsOneWidget,
        reason: 'coming back does not restart the drill behind the athlete');
    await tester.tap(find.text('STOP'));
    await tester.pump(_callSettle);
  });

  testWidgets('back mid-drill asks first, and "keep going" carries on',
      (tester) async {
    await openDrill(tester);
    await tester.pump(const Duration(seconds: 5));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave the drill?'), findsOneWidget);
    expect(find.byType(ReactionDrillScreen), findsOneWidget);

    await tester.tap(find.text('Keep going'));
    await tester.pump(_callSettle);
    expect(find.text('GET IN STANCE'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.byType(ReactionDrillScreen), findsNothing);
  });

  testWidgets('stopping says how far the run got; finishing says what next',
      (tester) async {
    await openDrill(tester);
    await tester.pump(const Duration(seconds: 3 + 12));
    await tester.tap(find.text('STOP'));
    await tester.pump(_callSettle);
    expect(find.textContaining('Stopped at 0:12'), findsOneWidget);
    expect(find.text('0:30'), findsOneWidget, reason: 'ready for a full run');

    await tester.tap(find.text('START DRILL'));
    await tester.pump(const Duration(seconds: 3 + 31));
    await tester.pump(_callSettle);
    expect(find.textContaining(' in 0:30'), findsOneWidget);
    expect(find.text('Ready for Intermediate?'), findsOneWidget);

    // Nothing asks before leaving a finished drill.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ReactionDrillScreen), findsNothing);
  });

  testWidgets('"test voice" speaks a real call from the chosen level',
      (tester) async {
    final voice = _SpyVoice();
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(wrapApp(
      const Scaffold(body: ReactionDrillPicker()),
      repo: repo,
      coachVoice: voice,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wrestling'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TEST VOICE'));
    await tester.pumpAndSettle();
    expect(voice.lines, hasLength(1));
    final wrestling = {
      for (final c in ReactionDiscipline.grappling.commands) '${c.spoken}!'
    };
    expect(wrestling, contains(voice.lines.single));
  });

  testWidgets('"test voice" says so when the phone has no voice',
      (tester) async {
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(wrapApp(
      const Scaffold(body: ReactionDrillPicker()),
      repo: repo,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TEST VOICE'));
    await tester.pump();
    expect(find.text('No voice on this device. Follow the calls on screen.'),
        findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('the picker remembers the last drill chosen', (tester) async {
    final repo = await makeRepo(signedIn: true);
    Future<void> open() async {
      await tester.pumpWidget(wrapApp(
        const Scaffold(body: ReactionDrillPicker()),
        repo: repo,
      ));
      await tester.pumpAndSettle();
    }

    await open();
    await tester.tap(find.text('Striking'));
    await tester.tap(find.text('Advanced+'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await open();
    expect(find.text('1:30'), findsOneWidget, reason: 'striking advanced+');
    expect(find.text('IN THE MIX · 19'), findsOneWidget);
  });
}

class _SpyVoice implements CoachVoice {
  final lines = <String>[];
  @override
  bool get isAvailable => true;
  @override
  Future<void> prepare() async {}
  @override
  Future<void> say(String line) async => lines.add(line);
  @override
  Future<void> stop() async {}
}
