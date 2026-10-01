import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fighter_edge/screens/dashboard_screen.dart';
import 'package:fighter_edge/screens/nutrition_screen.dart';
import 'package:fighter_edge/screens/settings_screen.dart';
import 'package:fighter_edge/widgets/primary_button.dart';

import '../helpers/test_harness.dart';

void main() {
  for (final large in [false, true]) {
    testWidgets('privacy action does not absorb switches, large=$large',
        (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();

      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(
        MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 844),
            devicePixelRatio: 1,
            textScaler: TextScaler.linear(large ? 2 : 1),
            highContrast: large,
            disableAnimations: true,
          ),
          child: const SettingsScreen(),
        ),
        repo: repo,
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Health data'), 250);
      await Scrollable.ensureVisible(tester.element(find.text('Health data')),
          alignment: .1);
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.text('Health data'));
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.label, startsWith('Health data'));
      expect(data.label, isNot(contains('AI coach')));
      expect(data.label, isNot(contains('Usage analytics')));
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      final values = tester
          .widgetList<Switch>(find.byType(Switch))
          .map((widget) => widget.value)
          .toList();
      tester.binding.renderViews.first.owner!.semanticsOwner!
          .performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.text('Withdraw consent?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widgetList<Switch>(find.byType(Switch))
              .map((widget) => widget.value)
              .toList(),
          values);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('Fuel heading and add action have separate names',
      (tester) async {
    final semantics = tester.ensureSemantics();

    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(wrapApp(const NutritionScreen(), repo: repo));
    await tester.pumpAndSettle();
    final heading = tester.getSemantics(find.text('NUTRITION'));
    expect(heading.getSemanticsData().label, 'NUTRITION');
    expect(heading.getSemanticsData().flagsCollection.isHeader, isTrue);
    final action = tester.getSemantics(find.bySemanticsLabel('Add food'));
    expect(action.getSemanticsData().flagsCollection.isButton, isTrue);
    tester.binding.renderViews.first.owner!.semanticsOwner!
        .performAction(action.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(find.text('Add to Today'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Home brief heading and action stay independent', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    final repo = await makeRepo(signedIn: true, onboarded: true);
    await tester
        .pumpWidget(wrapApp(DashboardScreen(onNavigate: (_) {}), repo: repo));
    await tester.pumpAndSettle();
    expect(
        tester.getSemantics(find.text('Corner Brief')).getSemanticsData().label,
        'Corner Brief');
    final action = tester.getSemantics(find.text('Unlock the full brief'));
    expect(action.getSemanticsData().label, 'Unlock the full brief');
    expect(action.getSemanticsData().flagsCollection.isButton, isTrue);
    semantics.dispose();
  });

  testWidgets('disabled custom buttons keep their name and no tap action',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Column(
      children: [
        Text('Explanation'),
        PrimaryButton('Continue'),
        GhostButton('Refresh')
      ],
    ))));
    for (final label in ['Continue', 'Refresh']) {
      final data = tester.getSemantics(find.text(label)).getSemanticsData();
      expect(data.label, label);
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
    }
    semantics.dispose();
  });
}
