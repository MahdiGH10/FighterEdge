import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/fight_camp/domain/camp_screening.dart';
import 'package:fighter_edge/features/fight_camp/presentation/camp_screening_from_draft.dart';
import 'package:fighter_edge/screens/onboarding/onboarding_screen.dart';

import '../helpers/test_harness.dart';

Future<void> _tapVisible(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _reachBody(WidgetTester tester) async {
  await _tapVisible(tester, 'Skip');
  await _tapVisible(tester, 'Continue');
  await _tapVisible(tester, 'Continue');
  expect(find.text('Tell us your starting point.'), findsOneWidget);
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), '30');
  await tester.enterText(fields.at(1), '180');
  await tester.enterText(fields.at(2), '80');
  await tester.pumpAndSettle();
}

Future<void> _finishQuestions(WidgetTester tester) async {
  // Formula, daily activity, training rhythm, then Review.
  for (var step = 0; step < 4; step++) {
    await _tapVisible(tester, 'Continue');
  }
  expect(find.text('Your first plan is ready.'), findsOneWidget);
  await _tapVisible(tester, 'Start my plan');
}

void main() {
  testWidgets('initial onboarding requires explicit review before a target',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final authRepo = await makeRepo(signedIn: true);
    final fuelRepo = InMemoryEdgeFuelRepository();
    await tester.pumpWidget(wrapApp(
      const OnboardingScreen(),
      repo: authRepo,
      edgeFuelRepo: fuelRepo,
    ));
    await tester.pumpAndSettle();
    await _reachBody(tester);

    for (final question in const [
      'Pregnant or breastfeeding',
      'Eating-disorder history or symptoms',
      'Diabetes requiring medication',
      'Kidney disease',
      'Serious liver disease',
      'Another clinician-managed diet',
    ]) {
      expect(find.text(question), findsOneWidget);
    }
    await _tapVisible(tester, 'Continue');
    expect(find.text('Review every health question before creating a target.'),
        findsOneWidget);
    expect(find.text('Tell us your starting point.'), findsOneWidget);

    await _tapVisible(tester, 'I reviewed every health question');
    await _finishQuestions(tester);
    final draft =
        await fuelRepo.watchProfileDraft(authRepo.currentUser!.id).first;
    final target = await fuelRepo.watchTarget(authRepo.currentUser!.id).first;
    expect(draft?.screeningStatus, NutritionScreeningStatus.completed);
    expect(draft?.confirmed, isTrue);
    expect(campScreeningFromDraft(draft), CampScreening.cleared);
    expect(target?.isSuccess, isTrue);
  });

  testWidgets('a reviewed clinical flag never creates an automated target',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final authRepo = await makeRepo(signedIn: true);
    final fuelRepo = InMemoryEdgeFuelRepository();
    await tester.pumpWidget(wrapApp(
      const OnboardingScreen(),
      repo: authRepo,
      edgeFuelRepo: fuelRepo,
    ));
    await tester.pumpAndSettle();
    await _reachBody(tester);
    await _tapVisible(tester, 'Kidney disease');
    await _tapVisible(tester, 'I reviewed every health question');
    await _finishQuestions(tester);

    final draft =
        await fuelRepo.watchProfileDraft(authRepo.currentUser!.id).first;
    final target = await fuelRepo.watchTarget(authRepo.currentUser!.id).first;
    expect(draft?.screeningStatus, NutritionScreeningStatus.needsReview);
    expect(draft?.confirmed, isFalse);
    expect(
        campScreeningFromDraft(draft), CampScreening.needsProfessionalReview);
    expect(target, isNull);
  });
}
