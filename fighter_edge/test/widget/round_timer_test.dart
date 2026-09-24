import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/screens/round_timer_screen.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:fighter_edge/training/reaction/coach_voice.dart';

import '../helpers/test_harness.dart';

/// A voice that is "heard": records every call instead of speaking.
class _RecordingVoice implements CoachVoice {
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

void main() {
  late DateTime now;
  late _RecordingVoice voice;

  Clock manualClock() => Clock(() => now);
  void advance(Duration d) => now = now.add(d);

  setUp(() {
    now = DateTime(2026, 9, 24, 18);
    voice = _RecordingVoice();
  });

  Future<AppState> pumpTimer(WidgetTester tester,
      {bool withSession = false}) async {
    final repo = await makeRepo(signedIn: true);
    final state = AppState();
    await tester.pumpWidget(wrapApp(
      RoundTimerScreen(
        clock: manualClock(),
        session:
            withSession ? state.sessions.firstWhere((s) => !s.completed) : null,
      ),
      repo: repo,
      state: state,
      coachVoice: voice,
    ));
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('shows the true position after the phone was locked (P-1)',
      (tester) async {
    await pumpTimer(tester);
    await tester.tap(find.text('START'));
    await tester.pump();

    // Locked for 13:20 with no frames at all, then unlocked.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    advance(const Duration(minutes: 13, seconds: 20));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('3 / 5'), findsOneWidget);
    expect(find.text('03:40'), findsOneWidget);
    expect(find.text('WORK'), findsOneWidget);
  });

  testWidgets('calls the round, the ten-second warning and the rest',
      (tester) async {
    await pumpTimer(tester);
    await tester.tap(find.text('START'));
    await tester.pump();
    expect(voice.lines, ['Round 1']);

    advance(const Duration(minutes: 4, seconds: 50));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(voice.lines.last, 'Ten seconds');

    advance(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(voice.lines.last, 'Rest');
    expect(find.text('REST'), findsOneWidget);
    expect(find.text('01:00'), findsWidgets);

    advance(const Duration(minutes: 1));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(voice.lines.last, 'Round 2');
    expect(find.text('2 / 5'), findsOneWidget);
    expect(voice.lines.where((l) => l == 'Ten seconds'), hasLength(1));
  });

  testWidgets('pausing freezes the clock however long it waits',
      (tester) async {
    await pumpTimer(tester);
    await tester.tap(find.text('START'));
    advance(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.tap(find.text('PAUSE'));
    await tester.pump();

    advance(const Duration(minutes: 20));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('04:30'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('a finished session is logged and says Time', (tester) async {
    final state = await pumpTimer(tester, withSession: true);
    final before = state.trainingLog.length;
    await tester.tap(find.text('START'));
    await tester.pump();

    advance(const Duration(hours: 1));
    await tester.pump(const Duration(milliseconds: 1100));

    expect(find.text('DONE'), findsOneWidget);
    expect(find.text('RESTART'), findsOneWidget);
    expect(voice.lines.last, 'Time');
    expect(state.trainingLog.length, before + 1);
  });

  testWidgets('switching style resets to the new format', (tester) async {
    await pumpTimer(tester);
    await tester.tap(find.text('START'));
    advance(const Duration(minutes: 2));
    await tester.pump(const Duration(milliseconds: 1100));

    await tester.tap(find.text('BJJ'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 6'), findsOneWidget);
    expect(find.text('05:00'), findsWidgets);
    expect(find.text('START'), findsOneWidget);
  });
}
