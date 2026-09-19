import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/widgets/pro_lock.dart';

import '../helpers/test_harness.dart';

void main() {
  const gated = ProGate(
    feature: Feature.cornerCoach,
    child: Text('SECRET CONTENT'),
  );

  testWidgets('free users see the Pro lock, not the content', (tester) async {
    final repo = await makeRepo(signedIn: true, plan: Plan.free);
    await tester.pumpWidget(wrapApp(const Scaffold(body: gated), repo: repo));
    await tester.pump();

    expect(find.text('SECRET CONTENT'), findsNothing);
    expect(find.text('Corner Cues is Pro'), findsOneWidget);
    expect(find.text('UNLOCK WITH PRO'), findsOneWidget); // button upper-cases
  });

  testWidgets('Pro users see the gated content', (tester) async {
    final repo = await makeRepo(signedIn: true, plan: Plan.pro);
    await tester.pumpWidget(wrapApp(const Scaffold(body: gated), repo: repo));
    await tester.pump();

    expect(find.text('SECRET CONTENT'), findsOneWidget);
    expect(find.text('Corner Cues is Pro'), findsNothing);
  });
}
