import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/controllers/auth_controller.dart';
import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_day_plan.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/features/fight_camp/data/in_memory_fight_camp_repository.dart';
import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/fight_camp/presentation/fight_camp_controller.dart';
import 'package:fighter_edge/features/training_plan/data/legacy_session_slot.dart';
import 'package:fighter_edge/features/training_plan/presentation/plan_controller.dart';
import 'package:fighter_edge/notifications/notification_inputs_reader.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:fighter_edge/state/sync_tracker.dart';

import '../../helpers/test_harness.dart';

/// Monday 2026-10-19, 09:00.
final _monday = DateTime(2026, 10, 19, 9);
const _uid = 'fighter';

void main() {
  late InMemoryDataRepository data;
  late InMemoryEdgeFuelRepository fuelRepo;
  late InMemoryFightCampRepository fightRepo;
  late AppState state;
  late PlanController plan;
  late FightCampController fight;
  late EdgeFuelController edgeFuel;
  late AuthController auth;
  late NotificationInputsReader reader;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> build({bool withPlan = true}) async {
    data = InMemoryDataRepository();
    fuelRepo = InMemoryEdgeFuelRepository();
    fightRepo = InMemoryFightCampRepository();
    if (withPlan) {
      for (final slot in [
        const LegacySessionSlot(
            id: 'Mon-Striking', day: 'Mon', title: 'Striking'),
        const LegacySessionSlot(
            id: 'Wed-Wrestling', day: 'Wed', title: 'Wrestling'),
        const LegacySessionSlot(id: 'Fri-BJJ', day: 'Fri', title: 'BJJ'),
      ]) {
        await data.saveLegacySession(_uid, slot);
      }
    }
    state = AppState(dataRepository: data, clock: () => _monday)..setUser(_uid);
    fight = FightCampController(repository: fightRepo)..setUser(_uid);
    plan = PlanController(log: state, repository: data, sync: SyncTracker())
      ..configure(
        userId: _uid,
        fight: fight.camp,
        goal: 'Gain muscle',
        level: 'Intermediate',
      );
    edgeFuel = EdgeFuelController(repository: fuelRepo)..setUser(_uid);
    final repo = await makeRepo(signedIn: true);
    auth = AuthController(repo);
    await pumpEventQueue();
    reader = NotificationInputsReader(
      plan: plan,
      fightCamp: fight,
      edgeFuel: edgeFuel,
      auth: auth,
    );
    addTearDown(() {
      plan.dispose();
      fight.dispose();
      edgeFuel.dispose();
      state.dispose();
      auth.dispose();
      data.dispose();
    });
  }

  Future<void> confirmFuelSetup(int age) async {
    await fuelRepo.saveProfileDraft(
      _uid,
      NutritionSetupDraft(ageYears: age, confirmed: true),
    );
    await pumpEventQueue();
  }

  group('sessions and fuel day types', () {
    test('sessions are the Train tab\'s own rows', () async {
      await build();
      expect(plan.hasPlan, isTrue);
      expect(reader.read().sessions, plan.rows);
      expect(reader.read().sessions, isNotEmpty);
    });

    test('fuel day types cover this week and next, from the same plan',
        () async {
      await build();
      final types = reader.read().fuelDayTypes;
      final thisWeek = weekStart(_monday);
      for (var i = 0; i < 14; i++) {
        expect(types.containsKey(addDays(thisWeek, i)), isTrue,
            reason: 'day $i');
      }
      // Training days differ from rest days: the types come from the plan.
      expect(types.values.toSet().length, greaterThan(1));
      // Only a day type goes out, never a number.
      expect(types.values.every((t) => FuelDayType.values.contains(t)), isTrue);
    });

    test('there is nothing to feed without a plan', () async {
      await build(withPlan: false);
      expect(plan.hasPlan, isFalse);
      final inputs = reader.read();
      expect(inputs.sessions, isEmpty);
      expect(inputs.fuelDayTypes, isEmpty);
    });
  });

  group('the fight', () {
    test('no fight, no date', () async {
      await build();
      expect(reader.read().fightDate, isNull);
    });

    test('a booked fight gives its date, and fight week has its own type',
        () async {
      await build();
      final camp = FightCamp.tryCreate(
        fightDate: DateTime(2026, 10, 24),
        weightLimitKg: 70,
        category: CompetitionCategory.amateurStriking,
      )!;
      fight.save(camp);
      plan.configure(userId: _uid, fight: fight.camp, goal: 'x', level: 'y');
      await pumpEventQueue();

      final inputs = reader.read();
      expect(inputs.fightDate, calendarDay(DateTime(2026, 10, 24)));
      // Days inside the fight window are named fight week, which has no
      // fuel window.
      expect(inputs.fuelDayTypes.values, contains(FuelDayType.fightWeek));
    });
  });

  group('age and the nutrition channels', () {
    test('unknown until the Fuel setup is confirmed', () async {
      await build();
      expect(reader.read().ageYears, isNull);
      expect(NotificationInputsReader.nutritionAllowed(edgeFuel), isFalse);

      await fuelRepo.saveProfileDraft(
        _uid,
        const NutritionSetupDraft(ageYears: 30),
      );
      await pumpEventQueue();
      expect(reader.read().ageYears, isNull, reason: 'draft not confirmed');
    });

    test('an adult with a confirmed setup is allowed', () async {
      await build();
      await confirmFuelSetup(18);
      expect(reader.read().ageYears, 18);
      expect(NotificationInputsReader.nutritionAllowed(edgeFuel), isTrue);
    });

    test('under 18 is not allowed', () async {
      await build();
      await confirmFuelSetup(17);
      expect(reader.read().ageYears, 17);
      expect(NotificationInputsReader.nutritionAllowed(edgeFuel), isFalse);
    });
  });

  group('the trial', () {
    test('a trial gives its end; a paid plan and a free plan give none',
        () async {
      await build();
      final repo = await makeRepo(signedIn: true);
      auth.dispose();
      auth = AuthController(repo);
      reader = NotificationInputsReader(
        plan: plan,
        fightCamp: fight,
        edgeFuel: edgeFuel,
        auth: auth,
      );
      await pumpEventQueue();
      expect(reader.read().trialEndsAt, isNull);

      final ends = DateTime.now().add(const Duration(days: 5));
      await repo.debugSetPlan(Plan.pro,
          expiresAt: ends, period: ProPeriod.trial);
      await pumpEventQueue();
      expect(reader.read().trialEndsAt, isNotNull);
      expect(
        reader.read().trialEndsAt!.difference(ends).inSeconds.abs(),
        lessThan(2),
      );

      // Converted: paid access, no trial end, so the notice goes.
      await repo.debugSetPlan(
        Plan.pro,
        expiresAt: DateTime.now().add(const Duration(days: 300)),
        period: ProPeriod.normal,
      );
      await pumpEventQueue();
      expect(reader.read().trialEndsAt, isNull);
    });
  });
}
