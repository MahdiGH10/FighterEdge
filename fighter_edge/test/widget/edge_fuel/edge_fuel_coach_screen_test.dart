import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/features/edge_fuel/ai/fake_edge_fuel_ai_gateway.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/screens/edge_fuel_coach_screen.dart';

import '../../helpers/test_harness.dart';

NutritionTarget _successTarget() => NutritionTarget(
      status: NutritionTargetStatus.success,
      policyVersion: 1,
      calculatedAt: DateTime(2026, 1, 1),
      targetCalories: 2500,
      proteinGrams: 150,
      carbGrams: 260,
      fatGrams: 80,
    );

void main() {
  group('EdgeFuelCoachScreen', () {
    testWidgets('lets a Pro athlete create a structured Fighter Brief',
        (tester) async {
      final repo = await makeRepo(signedIn: true, plan: Plan.pro);
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(repo.currentUser!.id, _successTarget());

      await tester.pumpWidget(wrapApp(
        const EdgeFuelCoachScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
        edgeFuelAiGateway: const FakeEdgeFuelAiGateway(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Talk to your coach'), findsOneWidget);
      expect(find.text('GET TODAY\'S FIGHTER BRIEF'), findsOneWidget);
      await tester.tap(find.text('GET TODAY\'S FIGHTER BRIEF').first);
      await tester.pumpAndSettle();

      expect(find.text('NEXT ACTION'), findsOneWidget);
      expect(find.text('MEAL SUGGESTION'), findsOneWidget);
      expect(find.text('TRAINING TIMING'), findsOneWidget);
      expect(find.text('WEEKLY ADJUSTMENT'), findsOneWidget);
    });

    testWidgets('keeps a follow-up question in the same conversation',
        (tester) async {
      final repo = await makeRepo(signedIn: true, plan: Plan.pro);
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(repo.currentUser!.id, _successTarget());

      await tester.pumpWidget(wrapApp(
        const EdgeFuelCoachScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
        edgeFuelAiGateway: const FakeEdgeFuelAiGateway(),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(EditableText),
        'What should I eat before training?',
      );
      await tester.tap(find.bySemanticsLabel('Send'));
      await tester.pumpAndSettle();

      expect(find.text('What should I eat before training?'), findsOneWidget);
      expect(
        find.textContaining('Your target is 2500 kcal with 150g protein'),
        findsOneWidget,
      );
    });

    testWidgets('presents Fuel Match as a catalog-backed Pro action',
        (tester) async {
      final repo = await makeRepo(signedIn: true, plan: Plan.pro);
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(repo.currentUser!.id, _successTarget());

      await tester.pumpWidget(wrapApp(
        const EdgeFuelCoachScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
        edgeFuelAiGateway: const FakeEdgeFuelAiGateway(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('BUILD MY FUEL MATCH'), findsOneWidget);
      expect(
        find.textContaining('Calculated from our curated food catalog'),
        findsOneWidget,
      );
    });

    testWidgets('shows a clear Pro gate without exposing the chat input',
        (tester) async {
      final repo = await makeRepo(signedIn: true, plan: Plan.free);
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(repo.currentUser!.id, _successTarget());

      await tester.pumpWidget(wrapApp(
        const EdgeFuelCoachScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('SEE PRO'), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);
      expect(find.textContaining('Ask a real question about your plan'),
          findsOneWidget);
    });
  });
}
