import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/screens/reaction_drill_picker.dart';
import 'package:fighter_edge/theme/app_theme.dart';
import 'package:fighter_edge/screens/reaction_drill_screen.dart';
import 'package:fighter_edge/training/reaction/reaction_cue_generator.dart';
import 'package:fighter_edge/training/reaction/reaction_drill.dart';

import '../helpers/test_harness.dart';
import 'large_text_test.dart' show expectNoFlutterException;

void _largeTextBoldHighContrastNoMotion(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2.0;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(
    boldText: true,
    highContrast: true,
    disableAnimations: true,
  );
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
}

void main() {
  testWidgets('the picker meets tap-target and label guidelines',
      (tester) async {
    final handle = tester.ensureSemantics();
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(wrapApp(
      const Scaffold(body: ReactionDrillPicker()),
      repo: repo,
    ));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  // Guards the shared FilterChips too: a selected chip's white label once
  // sat on AppColors.primary at 4.31:1, under AA's 4.5:1.
  testWidgets('the picker meets WCAG text contrast', (tester) async {
    final handle = tester.ensureSemantics();
    final repo = await makeRepo(signedIn: true);
    // Contrast is only meaningful against the app's real (dark) surfaces;
    // wrapApp's default Material theme is light.
    await tester.pumpWidget(wrapApp(
      Theme(
        data: AppTheme.dark(),
        child: const Scaffold(body: ReactionDrillPicker()),
      ),
      repo: repo,
    ));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('the picker survives 200% bold text in high contrast',
      (tester) async {
    _largeTextBoldHighContrastNoMotion(tester);
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(wrapApp(
      const Scaffold(body: ReactionDrillPicker()),
      repo: repo,
    ));
    await tester.pumpAndSettle();
    expectNoFlutterException(tester);

    for (final level in ['Beginner', 'Intermediate', 'Advanced', 'Advanced+']) {
      await tester.ensureVisible(find.text(level));
      await tester.tap(find.text(level));
      await tester.pumpAndSettle();
      expectNoFlutterException(tester);
    }
  });

  testWidgets(
      'a seven-move call fits the screen at 200% text, with reduced motion',
      (tester) async {
    _largeTextBoldHighContrastNoMotion(tester);
    final spec = ReactionDrillSpec.of(
        ReactionDiscipline.mma, ReactionLevel.advancedPlus);
    // Pick a seed whose drill really does call a 6–7 move sequence early.
    final seed = List.generate(200, (i) => i).firstWhere((s) {
      final g = ReactionCueGenerator(spec, random: Random(s));
      return g.next().commands.length == 7;
    });
    final handle = tester.ensureSemantics();
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(wrapApp(
      ReactionDrillScreen(spec: spec, randomFactory: () => Random(seed)),
      repo: repo,
    ));
    await tester.pump();
    expectNoFlutterException(tester);

    await tester.pump(const Duration(seconds: 3));
    // Reduced motion: the call is on screen on the very next frame, with no
    // cross-fade to wait through.
    await tester.pump();
    final first = ReactionCueGenerator(spec, random: Random(seed)).next();
    expect(first.commands, hasLength(7));
    for (final c in first.commands) {
      expect(findDrillMove(c.label), findsOneWidget);
    }
    expectNoFlutterException(tester);

    // The call is exposed to assistive tech as one spoken line.
    expect(find.bySemanticsLabel(first.spoken), findsOneWidget);

    // Every later call, to the end of the drill, still fits.
    for (var t = 0; t < 95; t++) {
      await tester.pump(const Duration(seconds: 1));
      expectNoFlutterException(tester);
    }
    expect(find.text('TIME'), findsOneWidget);
    handle.dispose();
  });
}
