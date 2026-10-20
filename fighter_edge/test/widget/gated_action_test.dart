import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/observability/telemetry.dart';
import 'package:fighter_edge/screens/paywall_screen.dart';
import 'package:fighter_edge/widgets/gated_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

Widget _button(void Function() onRan) => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: GatedAction.wrap(context, onRan),
            child: const Text('Log weight'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a read-only account sees the paywall instead of the action',
      (tester) async {
    final repo = await makeRepo(signedIn: true);
    final telemetry = MemoryTelemetry();
    var ran = 0;

    await tester.pumpWidget(
      wrapApp(_button(() => ran++), repo: repo, telemetry: telemetry),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log weight'));
    await tester.pumpAndSettle();

    expect(ran, 0);
    expect(find.byType(PaywallScreen), findsOneWidget);
    final viewed = telemetry.records
        .where((r) => r.event == TelemetryEvent.paywallViewed)
        .single;
    expect(viewed.parameters['trigger'], 'read_only');
  });

  testWidgets('a paid account just runs the action', (tester) async {
    final repo = await makeRepo(signedIn: true, plan: Plan.pro);
    var ran = 0;

    await tester.pumpWidget(wrapApp(_button(() => ran++), repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log weight'));
    await tester.pumpAndSettle();

    expect(ran, 1);
    expect(find.byType(PaywallScreen), findsNothing);
  });

  testWidgets('a trial account runs the action', (tester) async {
    final repo = await makeRepo(signedIn: true);
    await repo.debugSetPlan(
      Plan.pro,
      expiresAt: DateTime.now().add(const Duration(days: 5)),
      period: ProPeriod.trial,
    );
    var ran = 0;

    await tester.pumpWidget(wrapApp(_button(() => ran++), repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log weight'));
    await tester.pumpAndSettle();

    expect(ran, 1);
  });

  testWidgets('without an auth controller in the tree nothing is locked',
      (tester) async {
    var ran = 0;
    await tester.pumpWidget(MaterialApp(home: _button(() => ran++)));
    await tester.tap(find.text('Log weight'));
    expect(ran, 1);
  });
}
