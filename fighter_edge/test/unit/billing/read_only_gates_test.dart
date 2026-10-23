import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/features/fight_camp/data/in_memory_fight_camp_repository.dart';
import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/fight_camp/presentation/fight_camp_controller.dart';
import 'package:fighter_edge/features/training_plan/data/legacy_session_slot.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_status.dart';
import 'package:fighter_edge/features/training_plan/presentation/plan_controller.dart';
import 'package:fighter_edge/features/weekly_review/domain/weekly_review.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:fighter_edge/state/sync_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every write path reachable after the paywall goes through
/// `AppState.requireWrite`, so a read-only account is refused everywhere and
/// the paywall opens once per refused attempt.
final _monday = DateTime(2026, 10, 19, 9);
const _uid = 'fighter';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryDataRepository repo;
  late AppState state;
  late PlanController plan;
  late AccessState access;
  late int blocked;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    access = const AccessState.active();
    blocked = 0;
    repo = InMemoryDataRepository();
    addTearDown(repo.dispose);
    await repo.saveLegacySession(
      _uid,
      const LegacySessionSlot(
          id: 'Mon-Striking', day: 'Mon', title: 'Striking'),
    );
    state = AppState(dataRepository: repo, clock: () => _monday)
      ..setUser(_uid)
      ..accessSource = (() => access)
      ..onWriteBlocked = () => blocked++;
    plan = PlanController(log: state, repository: repo, sync: SyncTracker())
      ..configure(userId: _uid, goal: 'Gain muscle', level: 'Intermediate');
    addTearDown(() {
      plan.dispose();
      state.dispose();
    });
    await pumpEventQueue();
  });

  group('plan actions', () {
    test('complete, skip, move, undo and review are refused when read-only',
        () async {
      final session = plan.todaySession!.session;
      access = const AccessState.readOnly();

      plan.complete(session, title: 'x');
      plan.skip(session);
      plan.move(session, plan.today.add(const Duration(days: 1)));
      plan.undoComplete(session);
      plan.recordReview(plan.thisWeekStart, ReviewDecision.accepted);
      await pumpEventQueue();

      expect(blocked, 5);
      expect(state.trainingLog, isEmpty);
      expect(plan.todaySession?.status, SessionStatus.today);
      expect(plan.reviewDecision(plan.thisWeekStart), isNull);
    });

    test('the same actions work with access', () async {
      final session = plan.todaySession!.session;

      plan.complete(session, title: 'x');
      await pumpEventQueue();
      expect(state.trainingLog, hasLength(1));

      plan.recordReview(plan.thisWeekStart, ReviewDecision.kept);
      expect(plan.reviewDecision(plan.thisWeekStart), ReviewDecision.kept);
      expect(blocked, 0);
    });

    test('taking back a completion is refused when read-only', () async {
      final session = plan.todaySession!.session;
      plan.complete(session, title: 'x');
      await pumpEventQueue();
      access = const AccessState.readOnly();

      plan.undoComplete(session);
      state.removeTrainingLogEntry(state.trainingLog.single.id);

      expect(state.trainingLog, hasLength(1));
      expect(blocked, 2);
    });

    test('onboarding can still make the first plan', () {
      access = const AccessState.readOnly();
      plan.startFresh(
          weeklyTrainingDays: 4, goal: 'Gain muscle', level: 'Intermediate');
      expect(plan.hasPlan, isTrue);
      expect(blocked, 0);
    });
  });

  group('food log', () {
    FoodLogEntry entry() => FoodLogEntry(
          id: 'food-1',
          name: 'Rice bowl',
          notes: '',
          calories: 700,
          proteinGrams: 45,
          carbGrams: 90,
          fatGrams: 12,
          loggedAt: _monday,
        );

    test('a read-only account cannot add, edit or delete food', () async {
      var open = false;
      final fuel = EdgeFuelController(repository: InMemoryEdgeFuelRepository())
        ..writeGate = (() => open)
        ..setUser(_uid);
      addTearDown(fuel.dispose);
      await pumpEventQueue();

      await fuel.addEntry(entry());
      expect(fuel.entries, isEmpty);

      open = true;
      await fuel.addEntry(entry());
      expect(fuel.entries, hasLength(1));

      open = false;
      await fuel.toggleEntry(fuel.entries.single);
      await fuel.deleteEntry(fuel.entries.single);
      expect(fuel.entries, hasLength(1));
      expect(fuel.entries.single.consumed, isTrue);
    });

    test('wired to AppState it follows the access state', () async {
      final fuel = EdgeFuelController(repository: InMemoryEdgeFuelRepository())
        ..writeGate = state.requireWrite
        ..setUser(_uid);
      addTearDown(fuel.dispose);
      await pumpEventQueue();

      access = const AccessState.readOnly();
      await fuel.addEntry(entry());
      expect(fuel.entries, isEmpty);
      expect(blocked, 1);
    });
  });

  group('fight date', () {
    test('a read-only account cannot set or clear the fight', () async {
      final camp = FightCamp.tryCreate(
        fightDate: addDays(calendarDay(_monday), 60),
        weightLimitKg: 73.5,
        category: CompetitionCategory.professional,
        campWeeks: 12,
      )!;
      var open = false;
      final controller = FightCampController(
        repository: InMemoryFightCampRepository(),
      )
        ..writeGate = (() => open)
        ..setUser(_uid);
      addTearDown(controller.dispose);
      await pumpEventQueue();

      controller.save(camp);
      expect(controller.camp, isNull);

      open = true;
      controller.save(camp);
      expect(controller.camp, camp);

      open = false;
      controller.clear();
      expect(controller.camp, camp);
    });
  });
}
