import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/screens/home_shell.dart';
import 'package:fighter_edge/screens/settings_screen.dart';
import 'package:fighter_edge/state/glass_policy_controller.dart';
import 'package:fighter_edge/theme/glass_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_harness.dart';

void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Settings has a Reduce transparency switch that is remembered',
      (tester) async {
    useTallScreen(tester);
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(wrapApp(const SettingsScreen(), repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Reduce transparency'), findsOneWidget);
    final controller = tester
        .element(find.byType(SettingsScreen))
        .read<GlassPolicyController>();
    expect(controller.reduceTransparency, isFalse);

    await tester.tap(find.descendant(
      of: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Reduce transparency'),
      matching: find.byType(Switch),
    ));
    await tester.pumpAndSettle();

    expect(controller.reduceTransparency, isTrue);
    expect(controller.policy.resolve(highContrast: false), GlassLevel.solid);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(GlassPolicyController.reduceTransparencyKey), isTrue);
  });

  testWidgets('the app-wide scope follows the controller', (tester) async {
    final controller = GlassPolicyController();
    await controller.load();
    GlassLevel? seen;
    await tester.pumpWidget(
      ChangeNotifierProvider<GlassPolicyController>.value(
        value: controller,
        child: GlassPolicyHost(
          child: Builder(builder: (context) {
            seen = GlassPolicy.of(context);
            return const SizedBox.shrink();
          }),
        ),
      ),
    );
    // No MediaQuery above: high contrast reads as off.
    expect(seen, GlassLevel.tinted);

    await controller.setReduceTransparency(true);
    await tester.pump();
    expect(seen, GlassLevel.solid);
  });

  testWidgets('the home shell shares one backdrop group and starts the probe',
      (tester) async {
    useTallScreen(tester);
    final repo = await makeRepo(signedIn: true, onboarded: true);
    await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
          of: find.byType(HomeShell), matching: find.byType(BackdropGroup)),
      findsOneWidget,
    );
    final controller =
        tester.element(find.byType(HomeShell)).read<GlassPolicyController>();
    expect(controller.isLoaded, isTrue);
    expect(controller.isProbing, isTrue,
        reason: 'the first glass screen starts the frame probe');
  });
}
