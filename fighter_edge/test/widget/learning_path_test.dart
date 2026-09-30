import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/screens/drill_library_screen.dart';
import 'package:fighter_edge/screens/paywall_screen.dart';
import 'package:fighter_edge/training/drills/drill.dart';
import 'package:fighter_edge/training/drills/drill_progress_store.dart';
import 'package:fighter_edge/theme/app_icons.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('first visit chooses a discipline and shows its first drill',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(
        wrapApp(const Scaffold(body: DrillLibraryScreen()), repo: repo));
    await tester.pumpAndSettle();
    expect(find.text('Choose a discipline'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('choose-path-bjj')));
    await tester.pumpAndSettle();
    expect(find.text('Shrimp (Hip Escape)'), findsOneWidget);
    expect(find.text('Learn: Shrimp (Hip Escape)'), findsOneWidget);
    expect(find.bySemanticsLabel('Learn: Shrimp (Hip Escape)'), findsOneWidget);
    expect(find.text('0 of 4 drills sharp'), findsOneWidget);
    final saved = DrillProgressStore(userId: repo.currentUser!.id);
    await saved.load();
    expect(saved.discipline, DrillDiscipline.bjj);
    semantics.dispose();
  });

  testWidgets('marking a drill sharp shows the next step and advances the hero',
      (tester) async {
    final repo = await makeRepo(signedIn: true, plan: Plan.pro);
    await DrillProgressStore(userId: repo.currentUser!.id)
        .selectDiscipline(DrillDiscipline.striking);
    await tester.pumpWidget(
        wrapApp(const Scaffold(body: DrillLibraryScreen()), repo: repo));
    await tester.pumpAndSettle();
    expect(find.text('Learn: The Jab'), findsOneWidget);
    await tester.tap(find.text('Learn: The Jab'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sharp'), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.text('Sharp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sharp'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('After this drill: The 1-2'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('After this drill: The 1-2'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Learn: The 1-2'), findsOneWidget);
    expect(find.text('1 of 8 drills sharp'), findsOneWidget);
  });

  testWidgets('free path pauses at Pro and paywall does not unlock it',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final repo = await makeRepo(signedIn: true, plan: Plan.free);
    final store = DrillProgressStore(userId: repo.currentUser!.id);
    await store.selectDiscipline(DrillDiscipline.striking);
    await store.setProgress('jab', DrillProgress.sharp);
    await tester.pumpWidget(
        wrapApp(const Scaffold(body: DrillLibraryScreen()), repo: repo));
    await tester.pumpAndSettle();
    expect(find.text('The 1-2'), findsOneWidget);
    expect(find.text('Pro drill · path paused'), findsOneWidget);
    expect(find.bySemanticsLabel('View Pro options'), findsOneWidget);
    await tester.tap(find.text('View Pro options'));
    await tester.pumpAndSettle();
    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(repo.currentUser!.plan, Plan.free);
    await tester.tap(find.byIcon(AppIcons.caretLeft));
    await tester.pumpAndSettle();
    expect(find.text('Pro drill · path paused'), findsOneWidget);
    expect(repo.currentUser!.plan, Plan.free);
    semantics.dispose();
  });

  testWidgets('path hero wraps at 320px and 200 percent text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final repo = await makeRepo(signedIn: true);
    await DrillProgressStore(userId: repo.currentUser!.id)
        .selectDiscipline(DrillDiscipline.clinch);
    await tester.pumpWidget(
        wrapApp(const Scaffold(body: DrillLibraryScreen()), repo: repo));
    await tester.pumpAndSettle();
    expect(find.text('Learn: Plum Clinch & Knees'), findsOneWidget);
    await tester.ensureVisible(find.text('Learn: Plum Clinch & Knees'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn: Plum Clinch & Knees'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sharp'), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.text('Sharp'));
    await tester.pumpAndSettle();
    expect(find.text('Studied'), findsOneWidget);
    expect(find.text('Drilled'), findsOneWidget);
    expect(find.text('Sharp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
