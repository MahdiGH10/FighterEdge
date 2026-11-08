import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/screens/onboarding/onboarding_widgets.dart';

import '../helpers/test_harness.dart';

void main() {
  // The longest German goal choice in onboarding.
  const long = 'Struktur fürs Trainingscamp aufbauen';

  for (final scale in [1.0, 2.0]) {
    testWidgets('a long choice wraps instead of being cut off at $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(
        MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 568),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ChoiceWrap(
                values: const [long, 'Kurz'],
                selected: 'Kurz',
                onSelected: (_) {},
              ),
            ),
          ),
        ),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      final longPara = tester.renderObject<RenderParagraph>(find.text(long));
      final shortPara = tester.renderObject<RenderParagraph>(find.text('Kurz'));
      // The long answer needs more than one line, and gets them.
      expect(longPara.size.height, greaterThan(shortPara.size.height * 1.5));
      expect(
          longPara.size.width,
          lessThanOrEqualTo(
              tester.getSize(find.byType(ChoiceChip).first).width));
      expect(longPara.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the selected choice shows a check mark', (tester) async {
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(wrapApp(
      Scaffold(
        body: ChoiceWrap(
          values: const ['A', 'B'],
          selected: 'B',
          onSelected: (_) {},
        ),
      ),
      repo: repo,
    ));
    await tester.pumpAndSettle();
    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
    expect(chips.every((c) => c.showCheckmark == true), isTrue);
  });
}
