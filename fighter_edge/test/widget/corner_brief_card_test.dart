import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/features/corner_brief/presentation/corner_brief_card.dart';
import 'package:fighter_edge/features/daily_snapshot/domain/daily_snapshot.dart';
import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_gateway.dart';
import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_models.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';

import '../helpers/test_harness.dart';

NutritionTarget _target() => NutritionTarget(
      status: NutritionTargetStatus.success,
      policyVersion: 1,
      calculatedAt: DateTime(2026, 1, 1),
      targetCalories: 2400,
      proteinGrams: 180,
      carbGrams: 280,
      fatGrams: 70,
    );

EdgeFuelAiResult _brief() => const EdgeFuelAiResult.success(
      EdgeFuelAiResponse(
        lines: [
          CornerBriefLine(
              topic: CornerTopic.fuel, text: 'Get protein in at lunch.'),
          CornerBriefLine(
              topic: CornerTopic.training, text: 'Keep tonight easy.'),
          CornerBriefLine(topic: CornerTopic.weight, text: 'Weigh in fasted.'),
        ],
      ),
    );

class _Gateway implements EdgeFuelAiGateway {
  _Gateway(this.next);

  EdgeFuelAiResult Function() next;
  int calls = 0;

  @override
  Future<EdgeFuelAiResult> generateCornerBrief({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
    DailySnapshot? today,
  }) async {
    calls++;
    return next();
  }

  @override
  Future<EdgeFuelAiResult> sendChatMessage({
    required NutritionTarget target,
    required String userMessage,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
    List<ChatTurn> history = const [],
    DailySnapshot? today,
  }) =>
      throw UnimplementedError();
}

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    Plan plan = Plan.pro,
    bool withTarget = true,
    bool aiConsent = true,
    bool german = false,
    _Gateway? gateway,
  }) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo =
        await makeRepo(signedIn: true, plan: plan, aiCoachConsent: aiConsent);
    if (german) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fe_locale', 'de');
    }
    final edgeFuelRepo = InMemoryEdgeFuelRepository();
    if (withTarget) {
      await edgeFuelRepo.saveTarget(repo.currentUser!.id, _target());
    }
    await tester.pumpWidget(wrapApp(
      const Scaffold(body: SingleChildScrollView(child: CornerBriefCard())),
      repo: repo,
      edgeFuelRepo: edgeFuelRepo,
      edgeFuelAiGateway: gateway ?? _Gateway(_brief),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a free athlete gets the calculated line and the way to Pro',
      (tester) async {
    final gateway = _Gateway(_brief);
    await pumpCard(tester, plan: Plan.free, gateway: gateway);

    expect(find.text('Corner Brief'.toUpperCase()), findsNothing);
    expect(find.text('Corner Brief'), findsOneWidget);
    expect(find.textContaining('Log your first meal'), findsOneWidget);
    expect(find.text('Unlock the full brief'), findsOneWidget);
    expect(find.text("Get today's brief"), findsNothing);
    expect(gateway.calls, 0);
  });

  testWidgets('a Pro athlete without a plan is sent to set one up',
      (tester) async {
    await pumpCard(tester, withTarget: false);

    expect(find.textContaining('Set up EdgeFuel'), findsWidgets);
    expect(find.text("Get today's brief"), findsNothing);
  });

  testWidgets('opening Home never asks the coach by itself', (tester) async {
    final gateway = _Gateway(_brief);
    await pumpCard(tester, gateway: gateway);

    expect(find.text("Get today's brief"), findsOneWidget);
    expect(gateway.calls, 0);
  });

  testWidgets("tapping Get today's brief writes three lines", (tester) async {
    final gateway = _Gateway(_brief);
    await pumpCard(tester, gateway: gateway);

    await tester.tap(find.text("Get today's brief"));
    await tester.pumpAndSettle();

    expect(gateway.calls, 1);
    expect(find.text('Get protein in at lunch.'), findsOneWidget);
    expect(find.text('Keep tonight easy.'), findsOneWidget);
    expect(find.text('Weigh in fasted.'), findsOneWidget);
    expect(find.text('Ask your coach'), findsOneWidget);
    expect(find.text("Get today's brief"), findsNothing);
  });

  testWidgets('a new log rewrites the brief once, without being asked',
      (tester) async {
    final gateway = _Gateway(_brief);
    await pumpCard(tester, gateway: gateway);
    await tester.tap(find.text("Get today's brief"));
    await tester.pumpAndSettle();
    expect(gateway.calls, 1);

    final fuel =
        tester.element(find.byType(CornerBriefCard)).read<EdgeFuelController>();
    await fuel.addEntry(FoodLogEntry(
      id: 'meal-1',
      name: 'Fixture meal',
      notes: 'fixture',
      calories: 600,
      proteinGrams: 40,
      carbGrams: 60,
      fatGrams: 15,
      loggedAt: DateTime.now(),
    ));
    await tester.pumpAndSettle();

    expect(gateway.calls, 2);
    await tester.pumpAndSettle();
    expect(gateway.calls, 2, reason: 'no loop after the rewrite');
  });

  testWidgets('no automatic rewrite after a failure, only Try again',
      (tester) async {
    final gateway = _Gateway(_brief);
    await pumpCard(tester, gateway: gateway);
    await tester.tap(find.text("Get today's brief"));
    await tester.pumpAndSettle();

    gateway.next = () => const EdgeFuelAiResult.unavailable();
    final fuel =
        tester.element(find.byType(CornerBriefCard)).read<EdgeFuelController>();
    Future<void> log(String id) => fuel.addEntry(FoodLogEntry(
          id: id,
          name: 'Fixture meal',
          notes: 'fixture',
          calories: 300,
          proteinGrams: 20,
          carbGrams: 30,
          fatGrams: 5,
          loggedAt: DateTime.now(),
        ));
    await log('a');
    await tester.pumpAndSettle();
    expect(gateway.calls, 2);
    expect(find.text('Try again'), findsOneWidget);

    await log('b');
    await tester.pumpAndSettle();
    expect(gateway.calls, 2, reason: 'a failed rewrite waits for the athlete');

    gateway.next = _brief;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(gateway.calls, 3);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('an unavailable answer offers Try again', (tester) async {
    final gateway = _Gateway(() => const EdgeFuelAiResult.unavailable());
    await pumpCard(tester, gateway: gateway);

    await tester.tap(find.text("Get today's brief"));
    await tester.pumpAndSettle();

    expect(find.textContaining("couldn't answer"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a used-up day says so and does not offer a retry',
      (tester) async {
    final gateway = _Gateway(() => const EdgeFuelAiResult.quotaReached());
    await pumpCard(tester, gateway: gateway);

    await tester.tap(find.text("Get today's brief"));
    await tester.pumpAndSettle();

    expect(find.textContaining('briefs are used up'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.text("Get today's brief"), findsNothing);
  });

  testWidgets('the consent sheet comes first, then the brief', (tester) async {
    final gateway = _Gateway(_brief);
    await pumpCard(tester, aiConsent: false, gateway: gateway);

    await tester.tap(find.text("Get today's brief"));
    await tester.pumpAndSettle();
    expect(gateway.calls, 0);
    expect(find.text('I agree'), findsOneWidget);

    await tester.tap(find.text('I agree'));
    await tester.pumpAndSettle();
    expect(gateway.calls, 1);
    expect(find.text('Weigh in fasted.'), findsOneWidget);
  });

  testWidgets('reads in German', (tester) async {
    await pumpCard(tester, plan: Plan.free, german: true);

    expect(find.text('Ecken-Briefing'), findsOneWidget);
    expect(find.text('Corner Brief'), findsNothing);
  });
}
