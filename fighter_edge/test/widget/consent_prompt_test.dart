import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/privacy/consent.dart';
import 'package:fighter_edge/screens/settings_screen.dart';
import 'package:fighter_edge/widgets/stat_card.dart';

import '../helpers/test_harness.dart';

void main() {
  Future<ConsentController> undecided() async {
    final consent = ConsentController();
    await consent.load();
    return consent;
  }

  testWidgets('asks once on first entry, and declining is one tap',
      (tester) async {
    final repo =
        await makeRepo(signedIn: true, onboarded: true); // resets prefs
    final consent = await undecided();
    await tester.pumpWidget(FighterEdgeApp(authRepo: repo, consent: consent));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('consent-sheet')), findsOneWidget);
    await tester.tap(find.text("DON'T ALLOW"));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('consent-sheet')), findsNothing);
    expect(consent.needsDecision, isFalse);
    expect(consent.analyticsAllowed, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('privacy.consentDecided'), isTrue);
  });

  testWidgets('allowing enables both purposes', (tester) async {
    final repo = await makeRepo(signedIn: true, onboarded: true);
    final consent = await undecided();
    await tester.pumpWidget(FighterEdgeApp(authRepo: repo, consent: consent));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ALLOW'));
    await tester.pumpAndSettle();
    expect(consent.analyticsAllowed, isTrue);
    expect(consent.crashReportsAllowed, isTrue);
  });

  testWidgets('no prompt once decided', (tester) async {
    final repo = await makeRepo(signedIn: true, onboarded: true);
    final consent = ConsentController.decided(ConsentChoices.none);
    await tester.pumpWidget(FighterEdgeApp(authRepo: repo, consent: consent));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('consent-sheet')), findsNothing);
  });

  testWidgets('Settings can change each choice later', (tester) async {
    final repo = await makeRepo(signedIn: true);
    final consent = ConsentController.decided(ConsentChoices.none);
    await tester.pumpWidget(
        wrapApp(const SettingsScreen(), repo: repo, consent: consent));
    await tester.pumpAndSettle();

    final analytics = find.text('Usage analytics');
    await tester.scrollUntilVisible(analytics, 200,
        scrollable: find.byType(Scrollable).first);
    final toggle = find.descendant(
      of: find.ancestor(of: analytics, matching: find.byType(AppCard)),
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(consent.analyticsAllowed, isTrue);
    expect(consent.crashReportsAllowed, isFalse);
  });
}
