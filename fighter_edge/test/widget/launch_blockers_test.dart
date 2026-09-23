import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/presentation/screens/edge_fuel_coach_screen.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/screens/edge_fuel_setup_screen.dart';
import 'package:fighter_edge/screens/settings_screen.dart';
import 'package:fighter_edge/screens/weight_tracker_screen.dart';
import 'package:fighter_edge/widgets/filter_chips.dart';

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
    testWidgets('Weight tracker tab labels are never cut short at ${scale}x',
        (tester) async {
      phone(tester, textScale: scale);
      final repo = await makeRepo(signedIn: true, onboarded: true);
      await tester.pumpWidget(wrapApp(const WeightTrackerScreen(), repo: repo));
      await tester.pumpAndSettle();

      for (final label in ['Weight', 'Body Fat', 'Measurements']) {
        final text = find.text(label);
        expect(text, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(text);
        expect(paragraph.didExceedMaxLines, isFalse,
            reason: '"$label" is shown in full, not ellipsized');
      }
      // The test font (Ahem) draws every letter as a full square, far wider
      // than Inter, so the row overflows here even where it fits on a phone.
      // Either way the last tab can be reached, and once chosen it sits
      // fully on screen.
      await tester.ensureVisible(find.text('Measurements'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Measurements'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.descendant(
          of: find.byType(FilterChips), matching: find.text('Measurements')));
      expect(rect.right, lessThanOrEqualTo(390));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the AI Fighter Brief with no plan leads straight to setup',
      (tester) async {
    phone(tester);
    final repo = await makeRepo(signedIn: true, onboarded: true);
    await tester.pumpWidget(wrapApp(const EdgeFuelCoachScreen(), repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('No plan yet'), findsOneWidget);
    await tester.tap(find.text('START SETUP'));
    await tester.pumpAndSettle();
    expect(find.byType(EdgeFuelSetupScreen), findsOneWidget);
  });
}
