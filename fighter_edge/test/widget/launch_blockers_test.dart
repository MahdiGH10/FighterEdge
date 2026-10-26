import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/screens/settings_screen.dart';
import 'package:fighter_edge/screens/weight_tracker_screen.dart';

import '../helpers/test_harness.dart';

/// Guards the launch blockers found in the 2026-09-23 screen review: nothing
/// unfinished or internal may be visible to an athlete.
void main() {
  void phone(WidgetTester tester, {double textScale = 1}) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
  }

  testWidgets('Settings shows the safety note without internal to-dos',
      (tester) async {
    phone(tester);
    final repo = await makeRepo(signedIn: true, onboarded: true);
    await tester.pumpWidget(wrapApp(const SettingsScreen(), repo: repo));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('does not replace a coach'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('does not replace a coach'), findsOneWidget);
    expect(find.textContaining('before public launch'), findsNothing);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('Weight tracker shows only shipped controls at ${scale}x',
        (tester) async {
      phone(tester, textScale: scale);
      final repo = await makeRepo(signedIn: true, onboarded: true);
      await tester.pumpWidget(wrapApp(const WeightTrackerScreen(), repo: repo));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Add weigh-in'), findsOneWidget);
      expect(find.text('Body Fat'), findsNothing);
      expect(find.text('Measurements'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
