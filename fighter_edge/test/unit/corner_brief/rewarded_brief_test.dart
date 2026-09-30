import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/ads/fake_rewarded_ad_gateway.dart';
import 'package:fighter_edge/ads/reward_ticket_gateway.dart';
import 'package:fighter_edge/ads/rewarded_ad_gateway.dart';
import 'package:fighter_edge/features/corner_brief/presentation/corner_brief_controller.dart';
import 'package:fighter_edge/features/daily_snapshot/domain/daily_snapshot.dart';
import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_gateway.dart';
import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_models.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/observability/telemetry.dart';

final _target = NutritionTarget(
  status: NutritionTargetStatus.success,
  policyVersion: 1,
  calculatedAt: DateTime(2026, 1, 1),
  targetCalories: 2400,
  proteinGrams: 180,
  carbGrams: 280,
  fatGrams: 70,
);

final _monday = DateTime(2026, 9, 28, 9);

DailySnapshot _snapshot() => DailySnapshot.build(
      today: _monday,
      training: const [],
      plannedSessionsPerWeek: 4,
      goal: null,
      nutritionDays: const [],
      weights: const [],
    );

EdgeFuelAiResult _brief() => const EdgeFuelAiResult.success(
      EdgeFuelAiResponse(lines: [
        CornerBriefLine(topic: CornerTopic.fuel, text: 'Eat protein next.'),
        CornerBriefLine(topic: CornerTopic.training, text: 'Keep it easy.'),
        CornerBriefLine(topic: CornerTopic.recovery, text: 'Sleep early.'),
      ]),
    );

/// Answers "not yet" [pending] times (AdMob's confirmation still on its
/// way), then [then].
class _Ai implements EdgeFuelAiGateway {
  _Ai({this.pending = 0, EdgeFuelAiResult Function()? then})
      : then = then ?? _brief;

  int pending;
  EdgeFuelAiResult Function() then;
  int calls = 0;

  @override
  Future<EdgeFuelAiResult> generateCornerBrief({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
    DailySnapshot? today,
  }) async {
    calls++;
    if (pending > 0) {
      pending--;
      return const EdgeFuelAiResult.entitlementRequired();
    }
    return then();
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

class _Tickets implements RewardTicketGateway {
  _Tickets(this.next);

  RewardTicket next;
  int calls = 0;
  Completer<void>? hold;

  @override
  Future<RewardTicket> start() async {
    calls++;
    await hold?.future;
    return next;
  }
}

const _ready = RewardTicket(RewardTicketStatus.ready, token: 'one-time-token');

void main() {
  CornerBriefController make(
    _Ai ai,
    _Tickets tickets,
    RewardedAdGateway ads, {
    MemoryTelemetry? telemetry,
    int attempts = 8,
  }) =>
      CornerBriefController(
        gateway: ai,
        telemetry: telemetry,
        tickets: tickets,
        ads: ads,
        rewardPollInterval: Duration.zero,
        rewardPollAttempts: attempts,
      )..setUser('u1');

  test('a watched video unlocks the brief once the server confirms it',
      () async {
    final ai = _Ai(pending: 2);
    final ads = FakeRewardedAdGateway();
    final telemetry = MemoryTelemetry();
    final controller = make(ai, _Tickets(_ready), ads, telemetry: telemetry);

    final outcome =
        await controller.watchForBrief(target: _target, today: _snapshot());

    expect(outcome, RewardedBriefOutcome.written);
    expect(ads.shows, 1);
    expect(ads.lastToken, 'one-time-token',
        reason: 'the ad network gets our token, never the account ID');
    expect(ads.lastCustomData, rewardedBriefCustomData);
    expect(ai.calls, 3);
    expect(controller.briefFor(_monday)!.lines, hasLength(3));
    expect(controller.rewardUsedToday(_monday), isTrue);
    expect(controller.isWatching, isFalse);
    expect(
      telemetry.records.map((r) => r.event),
      [TelemetryEvent.rewardedAdResult, TelemetryEvent.aiRequestResult],
      reason: 'the "not yet" polls are not counted',
    );
    expect(telemetry.records.last.parameters['rewarded'], 1);
  });

  test('a reward already waiting writes the brief without a video', () async {
    final ads = FakeRewardedAdGateway();
    final controller = make(
        _Ai(), _Tickets(const RewardTicket(RewardTicketStatus.unused)), ads);

    final outcome =
        await controller.watchForBrief(target: _target, today: _snapshot());

    expect(outcome, RewardedBriefOutcome.written);
    expect(ads.shows, 0);
  });

  test('no video once today is used', () async {
    final ai = _Ai();
    final ads = FakeRewardedAdGateway();
    final controller = make(
        ai, _Tickets(const RewardTicket(RewardTicketStatus.usedToday)), ads);

    final outcome =
        await controller.watchForBrief(target: _target, today: _snapshot());

    expect(outcome, RewardedBriefOutcome.usedToday);
    expect(ads.shows, 0);
    expect(ai.calls, 0);
    expect(controller.rewardUsedToday(_monday), isTrue);
  });

  test('closing the video early earns nothing and writes nothing', () async {
    final ai = _Ai();
    final ads =
        FakeRewardedAdGateway(nextResult: RewardedVideoResult.closedEarly);
    final controller = make(ai, _Tickets(_ready), ads);

    final outcome =
        await controller.watchForBrief(target: _target, today: _snapshot());

    expect(outcome, RewardedBriefOutcome.closedEarly);
    expect(ai.calls, 0);
    expect(controller.rewardUsedToday(_monday), isFalse);
  });

  test('no video available, or no server, is not an error', () async {
    final ai = _Ai();
    final noFill =
        FakeRewardedAdGateway(nextResult: RewardedVideoResult.unavailable);
    expect(
      await make(ai, _Tickets(_ready), noFill)
          .watchForBrief(target: _target, today: _snapshot()),
      RewardedBriefOutcome.noVideo,
    );
    expect(
      await make(
        ai,
        _Tickets(const RewardTicket(RewardTicketStatus.unavailable)),
        FakeRewardedAdGateway(),
      ).watchForBrief(target: _target, today: _snapshot()),
      RewardedBriefOutcome.noVideo,
    );
    expect(ai.calls, 0);
  });

  test('stops asking when the confirmation never arrives', () async {
    final ai = _Ai(pending: 100);
    final controller =
        make(ai, _Tickets(_ready), FakeRewardedAdGateway(), attempts: 4);

    final outcome =
        await controller.watchForBrief(target: _target, today: _snapshot());

    expect(outcome, RewardedBriefOutcome.noVideo);
    expect(ai.calls, 4);
    expect(controller.lastStatusFor(_monday), isNull,
        reason: '"not confirmed yet" is not a result to show');
    expect(controller.isWatching, isFalse);
  });

  test('a brief that could not be written says so, the reward waits', () async {
    final ai = _Ai(then: () => const EdgeFuelAiResult.unavailable());
    final controller = make(ai, _Tickets(_ready), FakeRewardedAdGateway());

    final outcome =
        await controller.watchForBrief(target: _target, today: _snapshot());

    expect(outcome, RewardedBriefOutcome.failed);
    expect(controller.rewardUsedToday(_monday), isFalse);
  });

  test('missing AI consent is reported, no video shown', () async {
    final ads = FakeRewardedAdGateway();
    final controller = make(_Ai(),
        _Tickets(const RewardTicket(RewardTicketStatus.consentRequired)), ads);

    expect(
      await controller.watchForBrief(target: _target, today: _snapshot()),
      RewardedBriefOutcome.consentRequired,
    );
    expect(ads.shows, 0);
  });

  test('a new account drops the video flow on the way', () async {
    final tickets = _Tickets(_ready)..hold = Completer<void>();
    final ads = FakeRewardedAdGateway();
    final controller = make(_Ai(), tickets, ads);

    final pending =
        controller.watchForBrief(target: _target, today: _snapshot());
    expect(controller.isWatching, isTrue);
    controller.setUser('u2');
    tickets.hold!.complete();

    expect(await pending, RewardedBriefOutcome.noVideo);
    expect(ads.shows, 0);
    expect(controller.isWatching, isFalse);
  });

  test('only one video flow at a time', () async {
    final tickets = _Tickets(_ready)..hold = Completer<void>();
    final controller = make(_Ai(), tickets, FakeRewardedAdGateway());

    final first = controller.watchForBrief(target: _target, today: _snapshot());
    final second =
        await controller.watchForBrief(target: _target, today: _snapshot());
    tickets.hold!.complete();

    expect(second, RewardedBriefOutcome.noVideo);
    expect(await first, RewardedBriefOutcome.written);
    expect(tickets.calls, 1);
  });
}
