import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/screens/settings_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('switching the language changes the app, and it sticks',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(wrapApp(const SettingsScreen(), repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch').last);
    await tester.pumpAndSettle();

    expect(find.text('EINSTELLUNGEN'), findsOneWidget);
    expect(find.text('Sprache'), findsOneWidget);
    expect(find.textContaining('KI-Fighter-Brief'), findsOneWidget);

    // Back to English from the German screen.
    await tester.tap(find.text('Sprache'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);
  });
}
