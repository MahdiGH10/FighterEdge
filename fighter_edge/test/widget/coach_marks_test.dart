import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/widgets/coach_marks.dart';

void main() {
  final first = GlobalKey();
  final second = GlobalKey();
  final missing = GlobalKey();

  Future<Future<bool>> startTour(
    WidgetTester tester,
    List<CoachMarkStep> steps,
  ) async {
    late BuildContext hostContext;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        hostContext = context;
        return Scaffold(
          body: Column(
            children: [
              SizedBox(key: first, width: 100, height: 60),
              const SizedBox(height: 300),
              SizedBox(key: second, width: 100, height: 60),
            ],
          ),
        );
      }),
    ));
    final result = showCoachMarks(hostContext, steps);
    await tester.pumpAndSettle();
    return result;
  }

  const a = 'First target';
  const b = 'Second target';

  testWidgets('walks the steps in order and reports completion',
      (tester) async {
    final result = await startTour(tester, [
      CoachMarkStep(target: first, title: a, body: 'One'),
      CoachMarkStep(target: second, title: b, body: 'Two'),
    ]);

    expect(find.text(a), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);

    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text(b), findsOneWidget);
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.text('Skip tour'), findsNothing); // last step: just "Got it"

    await tester.tap(find.text('GOT IT'));
    await tester.pumpAndSettle();
    expect(find.byType(CoachMarkLayer), findsNothing);
    expect(await result, isTrue);
  });

  testWidgets('skipping ends the tour and reports it', (tester) async {
    final result = await startTour(tester, [
      CoachMarkStep(target: first, title: a, body: 'One'),
      CoachMarkStep(target: second, title: b, body: 'Two'),
    ]);

    await tester.tap(find.text('Skip tour'));
    await tester.pumpAndSettle();
    expect(find.byType(CoachMarkLayer), findsNothing);
    expect(await result, isFalse);
  });

  testWidgets('skips a step whose target is not on screen', (tester) async {
    final result = await startTour(tester, [
      CoachMarkStep(target: missing, title: 'Nowhere', body: '—'),
      CoachMarkStep(target: second, title: b, body: 'Two'),
    ]);

    expect(find.text('Nowhere'), findsNothing);
    expect(find.text(b), findsOneWidget);
    await tester.tap(find.text('GOT IT'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });

  testWidgets('holds still under reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await startTour(tester, [
      CoachMarkStep(target: first, title: a, body: 'One'),
    ]);
    // One frame is enough when nothing animates.
    expect(find.text(a), findsOneWidget);
    await tester.tap(find.text('GOT IT'));
    await tester.pump();
    expect(find.byType(CoachMarkLayer), findsNothing);
  });
}
