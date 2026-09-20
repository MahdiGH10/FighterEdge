import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/screens/drill_library_screen.dart';
import 'package:fighter_edge/screens/paywall_screen.dart';
import 'package:fighter_edge/screens/round_timer_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  Future<void> pumpLibrary(WidgetTester tester, Plan plan) async {
    final repo = await makeRepo(signedIn: true, plan: plan);
    await tester.pumpWidget(wrapApp(
      const Scaffold(body: DrillLibraryScreen()),
      repo: repo,
    ));
    await tester.pumpAndSettle();
  }

  group('Drill library', () {
    testWidgets(
        'a starter drill opens with its full coaching, and progress '
        'sticks', (tester) async {
      await pumpLibrary(tester, Plan.free);

      await tester.tap(find.text('The Jab'));
      await tester.pumpAndSettle();
      expect(find.text('KEY POINTS'), findsOneWidget);
      expect(find.text('COMMON MISTAKES'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('HOW TO DRILL IT'), 200,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('HOW TO DRILL IT'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Drilled'), 200,
          scrollable: find.byType(Scrollable).last);
      await tester.ensureVisible(find.text('Drilled'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drilled'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10)); // dismiss the sheet
      await tester.pumpAndSettle();

      expect(find.text('Drilled'), findsOneWidget,
          reason: 'the card shows the saved progress');
    });

    testWidgets('a free account sees Pro drills locked, with a way in',
        (tester) async {
      await pumpLibrary(tester, Plan.free);

      await tester.scrollUntilVisible(find.text('The 1-2'), 200,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('The 1-2'));
      await tester.pumpAndSettle();
      expect(find.text('KEY POINTS'), findsNothing,
          reason: 'locked drills do not give away the content');
      expect(find.text('UNLOCK THE FULL LIBRARY'), findsOneWidget);
    });

    testWidgets('Pro opens every drill', (tester) async {
      await pumpLibrary(tester, Plan.pro);

      await tester.tap(find.text('The 1-2'));
      await tester.pumpAndSettle();
      expect(find.text('KEY POINTS'), findsOneWidget);
    });

    testWidgets('the Saved filter explains itself when empty', (tester) async {
      await pumpLibrary(tester, Plan.free);

      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();
      expect(find.text('No saved drills yet'), findsOneWidget);
    });

    testWidgets('a fighter can move from a system into a coach path',
        (tester) async {
      await pumpLibrary(tester, Plan.pro);

      expect(find.text('EXPLORE TECHNIQUE PATHS'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('training-system-striking')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('training-category-striking.punches')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('selected-technique-path')),
          findsOneWidget);
      expect(find.text('Striking / Punches'), findsOneWidget);
      expect(find.text('The Jab'), findsOneWidget);
      expect(find.text('Lead Hook'), findsOneWidget);
      expect(find.text('The Teep'), findsNothing);
    });

    testWidgets('the path rail survives 200 percent text', (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await pumpLibrary(tester, Plan.pro);
      await tester.tap(
        find.byKey(const ValueKey('training-system-striking')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Punches'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Round timer corner cues', () {
    Future<void> runToFirstRest(WidgetTester tester, Plan plan) async {
      final repo = await makeRepo(signedIn: true, plan: plan);
      await tester.pumpWidget(wrapApp(const RoundTimerScreen(), repo: repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Boxing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('START'));
      // Boxing preset: 3-minute rounds.
      for (var i = 0; i < 181; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();
    }

    testWidgets('Pro gets a corner cue on the rest', (tester) async {
      await runToFirstRest(tester, Plan.pro);
      expect(find.text('REST'), findsOneWidget);
      expect(find.text('YOUR CORNER'), findsOneWidget);
      expect(find.textContaining('Establish the jab'), findsOneWidget);
    });

    testWidgets('free sees a quiet teaser, not a lock', (tester) async {
      await runToFirstRest(tester, Plan.free);
      expect(find.text('YOUR CORNER'), findsNothing);
      expect(find.textContaining('Pro puts a corner in your rest'),
          findsOneWidget);
    });
  });

  testWidgets('the paywall only sells features that exist', (tester) async {
    final repo = await makeRepo(signedIn: true, plan: Plan.free);
    await tester.pumpWidget(wrapApp(const PaywallScreen(), repo: repo));
    await tester.pumpAndSettle();

    final seen = <String>{};
    for (var i = 0; i < 10; i++) {
      for (final feature in Feature.values) {
        if (find.text(feature.title).evaluate().isNotEmpty) {
          seen.add(feature.title);
        }
      }
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(seen, {for (final f in Feature.values) f.title});
    expect(find.text('All Timer Presets'), findsNothing);
    expect(find.text('Unlimited Weight History'), findsNothing);
    expect(find.text('Nutrition Analytics'), findsNothing);
  });
}
