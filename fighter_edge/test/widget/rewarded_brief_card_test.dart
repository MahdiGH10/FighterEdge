import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/ads/fake_rewarded_ad_gateway.dart';
import 'package:fighter_edge/ads/reward_ticket_gateway.dart';
import 'package:fighter_edge/ads/rewarded_ad_gateway.dart';
import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/features/corner_brief/presentation/corner_brief_card.dart';
import 'package:fighter_edge/features/edge_fuel/ai/fake_edge_fuel_ai_gateway.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/screens/settings_screen.dart';

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

class _Tickets implements RewardTicketGateway {
  _Tickets(
      [this.next = const RewardTicket(RewardTicketStatus.ready,
          token: 'one-time-token')]);

  RewardTicket next;
  int calls = 0;

  @override
  Future<RewardTicket> start() async {
    calls++;
    return next;
  }
}

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    Plan plan = Plan.free,
    int? age = 27,
    bool adsInBuild = true,
    FakeRewardedAdGateway? ads,
    _Tickets? tickets,
  }) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo =
        await makeRepo(signedIn: true, plan: plan, aiCoachConsent: true);
    final uid = repo.currentUser!.id;
    final edgeFuelRepo = InMemoryEdgeFuelRepository();
    await edgeFuelRepo.saveTarget(uid, _target());
    await edgeFuelRepo.saveProfileDraft(
        uid, NutritionSetupDraft(confirmed: true, ageYears: age));
    await tester.pumpWidget(wrapApp(
      const Scaffold(body: SingleChildScrollView(child: CornerBriefCard())),
      repo: repo,
      edgeFuelRepo: edgeFuelRepo,
      edgeFuelAiGateway: const FakeEdgeFuelAiGateway(),
      rewardedAds: adsInBuild
          ? (ads ?? FakeRewardedAdGateway())
          : const UnavailableRewardedAdGateway(),
      rewardTickets: tickets ?? _Tickets(),
    ));
    await tester.pumpAndSettle();
  }

  const watch = "Watch a short video for today's full brief";

  testWidgets('a free adult can watch one video for the full brief',
      (tester) async {
    final ads = FakeRewardedAdGateway();
    await pumpCard(tester, ads: ads);

    expect(find.text(watch), findsOneWidget);
    expect(find.text('Unlock the full brief'), findsOneWidget);

    await tester.tap(find.text(watch));
    await tester.pumpAndSettle();

    expect(ads.shows, 1);
    expect(find.text('Log your next meal so your corner can stay specific.'),
        findsOneWidget);
    expect(find.textContaining("Today's free brief."), findsOneWidget);
    expect(find.text(watch), findsNothing, reason: 'one a day');
    expect(find.text('Unlock the full brief'), findsOneWidget);
  });

  testWidgets('nobody sees an ad they did not ask for', (tester) async {
    final ads = FakeRewardedAdGateway();
    await pumpCard(tester, ads: ads);
    expect(ads.shows, 0);
  });

  testWidgets('Pro never sees the video offer', (tester) async {
    await pumpCard(tester, plan: Plan.pro);
    expect(find.text(watch), findsNothing);
  });

  testWidgets('no video offer for a minor or an unknown age', (tester) async {
    await pumpCard(tester, age: 17);
    expect(find.text(watch), findsNothing);
  });

  testWidgets('no video offer in a build without ads', (tester) async {
    await pumpCard(tester, adsInBuild: false);
    expect(find.text(watch), findsNothing);
    expect(find.text('Unlock the full brief'), findsOneWidget);
  });

  testWidgets('a used day says so and hides the offer', (tester) async {
    final ads = FakeRewardedAdGateway();
    await pumpCard(tester,
        ads: ads,
        tickets: _Tickets(const RewardTicket(RewardTicketStatus.usedToday)));

    await tester.tap(find.text(watch));
    await tester.pumpAndSettle();

    expect(ads.shows, 0);
    expect(
        find.textContaining("You've had today's free brief"), findsOneWidget);
    expect(find.text(watch), findsNothing);
  });

  testWidgets('Settings offers ad privacy choices only where required',
      (tester) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await makeRepo(signedIn: true);

    await tester.pumpWidget(wrapApp(const SettingsScreen(), repo: repo));
    await tester.pumpAndSettle();
    expect(find.text('Ad privacy choices'), findsNothing);

    final ads = FakeRewardedAdGateway(privacyOptionsRequired: true);
    await tester.pumpWidget(
        wrapApp(const SettingsScreen(), repo: repo, rewardedAds: ads));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Ad privacy choices'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Ad privacy choices'));
    await tester.pump();
    expect(ads.privacyOptionsShown, 1);
  });

  testWidgets('closing the video early explains how to unlock', (tester) async {
    await pumpCard(tester,
        ads:
            FakeRewardedAdGateway(nextResult: RewardedVideoResult.closedEarly));

    await tester.tap(find.text(watch));
    await tester.pumpAndSettle();

    expect(find.text('Watch to the end to unlock the brief.'), findsOneWidget);
    expect(find.text(watch), findsOneWidget, reason: 'they can try again');
  });
}
