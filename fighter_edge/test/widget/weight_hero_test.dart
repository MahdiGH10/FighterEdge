import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/screens/weight_tracker_screen.dart';
import 'package:fighter_edge/widgets/number_hero.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('the weight flies from the dashboard card to the tracker',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = await makeRepo(signedIn: true, onboarded: true);
    await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('WEIGHT'));
    await tester.pump(); // route starts
    await tester.pump(const Duration(milliseconds: 120)); // mid-flight
    // One flying copy of the number, no duplicate-tag failure.
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(find.byType(WeightTrackerScreen), findsOneWidget);
    expect(find.byType(NumberHero), findsOneWidget);

    // And back again.
    await tester.tap(find.byIcon(Icons.chevron_left)); // header back
    await tester.pumpAndSettle();
    expect(find.byType(WeightTrackerScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
