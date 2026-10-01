import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/daily_snapshot/presentation/daily_snapshot_builder.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_profile.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/fight_camp/data/in_memory_fight_camp_repository.dart';
import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_week_plan.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_path.dart';
import 'package:fighter_edge/features/fight_camp/presentation/fight_camp_controller.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Thursday, the day of the weigh-in.
final now = DateTime(2026, 10, 1, 9);

const confirmed = NutritionSetupDraft(ageYears: 30, confirmed: true);

/// The coach screen and the Corner Brief both hand this builder the Fuel
/// draft. Age and the camp screening gate come from it together, so a surface
/// cannot send the AI a camp fact that skipped the gate (the Corner Brief once
/// did: it passed the age and forgot the screening).
void main() {
  late AppState state;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // 73.9 kg trend against a 73.5 kg limit on weigh-in day: food only.
    state = AppState(dataRepository: InMemoryDataRepository(), clock: () => now)
      ..addWeight(addDays(now, -1), 74.2)
      ..addWeight(now, 73.6);
  });

  Future<FightCampController> campOnWeighInDay({bool? refuelGuidance}) async {
    final repo = InMemoryFightCampRepository();
    await repo.saveFight(
      'u',
      FightCamp.tryCreate(
        fightDate: addDays(now, 1),
        weighInDate: now,
        weightLimitKg: 73.5,
        category: CompetitionCategory.professional,
      )!,
    );
    final controller =
        FightCampController(repository: repo, refuelGuidance: refuelGuidance);
    addTearDown(controller.dispose);
    controller.setUser('u');
    await pumpEventQueue();
    return controller;
  }

  test('without a Fuel draft the camp asks for setup', () async {
    final snapshot = buildDailySnapshot(state, await campOnWeighInDay());
    final camp = snapshot.camp!;
    expect(camp.weightPath.status, WeightPathStatus.needsScreening);
    expect(camp.fightWeekCut, isNull);
    expect(camp.todaySteps, isEmpty);
    expect((snapshot.toJson()['camp'] as Map)['weightPathStatus'],
        'needsScreening');
  });

  test('a draft that is not confirmed is not screening', () async {
    final snapshot = buildDailySnapshot(state, await campOnWeighInDay(),
        fuelDraft: const NutritionSetupDraft(ageYears: 30));
    expect(snapshot.camp!.weightPath.status, WeightPathStatus.needsScreening);
  });

  test('a confirmed draft gives the age and clears the gate together',
      () async {
    final snapshot = buildDailySnapshot(state, await campOnWeighInDay(),
        fuelDraft: confirmed);
    final camp = snapshot.camp!;
    expect(camp.weightPath.status, WeightPathStatus.onTrack);
    expect(camp.fightWeekCut, FightWeekCut.lowFibre);
    expect((snapshot.toJson()['camp'] as Map)['weightPathStatus'], 'onTrack');
  });

  test('a clinical flag holds the camp for professional review', () async {
    final snapshot = buildDailySnapshot(state, await campOnWeighInDay(),
        fuelDraft: const NutritionSetupDraft(
          ageYears: 30,
          confirmed: true,
          safetyFlags: NutritionSafetyFlags(kidneyDisease: true),
        ));
    final camp = snapshot.camp!;
    expect(camp.weightPath.status, WeightPathStatus.needsProfessionalReview);
    expect(camp.fightWeekCut, isNull);
    expect(camp.todaySteps, isEmpty);
  });

  test('a minor gets no camp guidance', () async {
    final snapshot = buildDailySnapshot(state, await campOnWeighInDay(),
        fuelDraft: const NutritionSetupDraft(ageYears: 17, confirmed: true));
    final camp = snapshot.camp!;
    expect(camp.weightPath.status, WeightPathStatus.notSupported);
    expect(camp.fightWeekCut, isNull);
    expect(camp.todaySteps, isEmpty);
  });

  test('the refuel step follows the controller switch', () async {
    final off = buildDailySnapshot(
        state, await campOnWeighInDay(refuelGuidance: false),
        fuelDraft: confirmed);
    expect(off.camp!.todaySteps, [FightWeekStep.weighIn]);

    final on = buildDailySnapshot(
        state, await campOnWeighInDay(refuelGuidance: true),
        fuelDraft: confirmed);
    expect(on.camp!.todaySteps, [FightWeekStep.weighIn, FightWeekStep.refuel]);
  });
}
