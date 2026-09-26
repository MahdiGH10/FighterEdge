import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fighter_edge/screens/auth/auth_widgets.dart';
import 'package:fighter_edge/screens/settings_screen.dart';
import 'package:fighter_edge/theme/app_theme.dart';
import 'package:fighter_edge/widgets/grouped_list.dart';
import 'package:fighter_edge/widgets/primary_button.dart';
import '../helpers/test_harness.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'grouped Settings controls remain independent at 320px scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(
          MediaQuery(
              data: MediaQueryData(
                  size: const Size(320, 568),
                  textScaler: TextScaler.linear(scale)),
              child: const SettingsScreen()),
          repo: repo));
      await tester.pumpAndSettle();
      final units = find.descendant(
          of: find.ancestor(
              of: find.text('Metric units'), matching: find.byType(GroupedRow)),
          matching: find.byType(Switch));
      await tester.scrollUntilVisible(find.text('Metric units'), 200);
      await Scrollable.ensureVisible(tester.element(units), alignment: .5);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(units).value, isTrue);
      await tester.tap(units);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(units).value, isFalse);
      final haptics = find.descendant(
          of: find.ancestor(
              of: find.text('Timer haptics'),
              matching: find.byType(GroupedRow)),
          matching: find.byType(Switch));
      expect(tester.widget<Switch>(haptics).value, isTrue);
      await tester.scrollUntilVisible(find.text('Sign out'), 250);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('provider mark is bundled and long button labels wrap at 200%',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
              body: Padding(
                  padding: const EdgeInsets.all(Insets.lg),
                  child: Column(children: [
                    SocialButton(
                        google: true,
                        label: 'Continue with Google',
                        onPressed: () {}),
                    PrimaryButton('Open my training dashboard',
                        expand: true, onPressed: () {}),
                  ]))),
        )));
    await tester.pumpAndSettle();
    final asset = tester.widget<Image>(find.byType(Image)).image as AssetImage;
    expect(asset.assetName, 'assets/images/google_g.png');
    final paragraph = tester
        .renderObject<RenderParagraph>(find.text('Open my training dashboard'));
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.size.height, greaterThan(48));
    expect(tester.takeException(), isNull);
  });
}
