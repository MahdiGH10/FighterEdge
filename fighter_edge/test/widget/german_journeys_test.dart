import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/screens/edge_fuel_setup_screen.dart';
import 'package:fighter_edge/screens/onboarding/onboarding_screen.dart';
import 'package:fighter_edge/screens/profile_screen.dart';
import 'package:fighter_edge/screens/first_run/first_week_checklist.dart';
import 'package:fighter_edge/screens/session_log_dialog.dart';
import 'package:fighter_edge/screens/training_camp_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('German setup stays German through health screening',
      (tester) async {
    final repo = await makeRepo(signedIn: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fe_locale', 'de');
    await tester.pumpWidget(wrapApp(const OnboardingScreen(), repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Dein Camp, klar geplant.'), findsOneWidget);
    await tester.tap(find.text('Überspringen'));
    await tester.pumpAndSettle();
    expect(find.text('Womit soll Fighter Edge beginnen?'), findsOneWidget);
    await tester.tap(find.text('Technik verbessern'));
    await tester.ensureVisible(find.text('Weiter'));
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(
        find.text('Worauf soll EdgeFuel ausgerichtet sein?'), findsOneWidget);
    await tester.ensureVisible(find.text('Weiter'));
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Wo stehst du gerade?'), findsOneWidget);
    expect(find.text('Kurzer Gesundheitscheck'), findsOneWidget);
    expect(
        find.text('Ich habe alle Gesundheitsfragen geprüft'), findsOneWidget);
  });

  testWidgets('German Profile labels describe available tools', (tester) async {
    final repo = await makeRepo(signedIn: true, onboarded: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fe_locale', 'de');
    await tester.pumpWidget(wrapApp(const ProfileScreen(), repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Trainingstage'), findsOneWidget);
    expect(find.text('Gewichtsverlauf'), findsOneWidget);
    expect(find.text('Einstellungen, Datenschutz und Konto'), findsOneWidget);
    expect(find.text('Training days'), findsNothing);
  });

  testWidgets('German Train empty week explains when the plan appears',
      (tester) async {
    final repo = await makeRepo(signedIn: true, onboarded: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fe_locale', 'de');
    await tester.pumpWidget(wrapApp(const TrainingCampScreen(), repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('WOCHE 1'), findsOneWidget);
    expect(find.textContaining('Noch keine Einheiten geplant'), findsOneWidget);
    expect(find.textContaining('No sessions planned yet'), findsNothing);
  });

  testWidgets('German Fuel setup and plan stay localized', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await makeRepo(signedIn: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fe_locale', 'de');
    final fuel = InMemoryEdgeFuelRepository();
    await fuel.saveProfileDraft(
      repo.currentUser!.id,
      const NutritionSetupDraft(
        currentStep: 5,
        goal: NutritionGoal.maintain,
        ageYears: 30,
        heightCm: 180,
        currentWeightKg: 80,
        equationProfile: EquationProfile.higherOffset,
        normalActivityLevel: ActivityLevel.moderate,
        screeningStatus: NutritionScreeningStatus.completed,
      ),
    );
    await tester.pumpWidget(
        wrapApp(const EdgeFuelSetupScreen(), repo: repo, edgeFuelRepo: fuel));
    await tester.pumpAndSettle();

    expect(find.text('Schritt 6 von 6 · Prüfen'), findsOneWidget);
    expect(find.text('Dein Plan'), findsOneWidget);
    expect(find.text('Annahmen'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Plan bestätigen'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Plan bestätigen'));
    await tester.pumpAndSettle();
    expect(find.text('So wurde das Ziel berechnet'), findsOneWidget);
    expect(find.text('Erneut einrichten'), findsOneWidget);
  });

  testWidgets('German first week and session dialog use translated copy',
      (tester) async {
    final repo = await makeRepo(signedIn: true, onboarded: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fe_locale', 'de');
    await tester.pumpWidget(wrapApp(
      Scaffold(
        body: FirstWeekChecklist(
          onStartTour: () {},
          onLogMeal: () {},
          onTrain: () {},
        ),
      ),
      repo: repo,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Deine erste Woche'), findsOneWidget);
    expect(find.text('Plan erstellen'), findsOneWidget);
    expect(find.text('30-Sekunden-Rundgang starten'), findsOneWidget);

    await tester.pumpWidget(wrapApp(
      const SessionLogDialog(
        title: 'Sparring',
        initialRpe: 0,
        initialNote: '',
      ),
      repo: repo,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sparring erfassen'), findsOneWidget);
    expect(find.text('Kurze Notiz'), findsOneWidget);
  });
}
