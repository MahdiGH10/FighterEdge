import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/features/training_plan/domain/models/intensity.dart';
import 'package:fighter_edge/features/training_plan/domain/models/planned_block.dart';
import 'package:fighter_edge/features/training_plan/domain/models/planned_session.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_kind.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_template.dart';
import 'package:fighter_edge/screens/session_player_screen.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  final session = PlannedSession(
    id: '2026-10-23.skill',
    date: DateTime(2026, 10, 23),
    kind: SessionKind.skill,
    intensity: Intensity.moderate,
    titleKey: 'skill',
    estimatedMinutes: 45,
    blocks: const [PlannedBlock(kind: BlockKind.main, minutes: 45)],
  );

  testWidgets('neutral session player fits a small phone at 200% text',
      (tester) async {
    final repo = await makeRepo(signedIn: true);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester
        .pumpWidget(wrapApp(SessionPlayerScreen(session: session), repo: repo));
    await tester.pump();

    expect(find.text('Session'), findsWidgets);
    expect(find.text('Pause'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('read-only session cannot save an effort', (tester) async {
    final repo = await makeRepo(signedIn: true);
    final state = AppState()..accessSource = () => const AccessState.readOnly();
    var blocked = false;
    state.onWriteBlocked = () => blocked = true;
    await tester.pumpWidget(wrapApp(SessionPlayerScreen(session: session),
        repo: repo, state: state));
    await tester.pump();

    await tester.tap(find.text('Finish').first);
    await tester.pump();
    expect(blocked, isTrue);
    expect(find.text('How hard was it?'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
