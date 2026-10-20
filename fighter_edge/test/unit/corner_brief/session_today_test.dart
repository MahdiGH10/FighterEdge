import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/daily_snapshot/domain/daily_snapshot.dart'
    as snapshot;
import 'package:fighter_edge/features/daily_snapshot/presentation/daily_snapshot_builder.dart';
import 'package:fighter_edge/features/fight_camp/data/in_memory_fight_camp_repository.dart';
import 'package:fighter_edge/features/fight_camp/presentation/fight_camp_controller.dart';
import 'package:fighter_edge/features/training_plan/data/legacy_session_slot.dart';
import 'package:fighter_edge/features/training_plan/domain/models/discipline.dart';
import 'package:fighter_edge/features/training_plan/domain/models/intensity.dart';
import 'package:fighter_edge/features/training_plan/domain/models/planned_session.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_kind.dart';
import 'package:fighter_edge/features/training_plan/presentation/plan_controller.dart';
import 'package:fighter_edge/features/training_plan/presentation/plan_labels.dart';
import 'package:fighter_edge/state/app_state.dart';

PlannedSession _session(SessionKind kind, [Discipline? discipline]) =>
    PlannedSession(
      id: '2026-09-29.${kind.name}',
      date: DateTime.utc(2026, 9, 29),
      kind: kind,
      discipline: discipline,
      intensity: Intensity.moderate,
      titleKey: kind.fallbackTitleKey,
      estimatedMinutes: 45,
    );

LegacySessionSlot _slot(String day, String title) =>
    LegacySessionSlot(id: '$day-$title', day: day, title: title);

void main() {
  // A Tuesday.
  final tuesday = DateTime(2026, 9, 29, 12);

  test('the kind of a session comes from a fixed list of kinds', () {
    snapshot.SessionKind of(SessionKind kind, [Discipline? d]) =>
        PlanLabels.snapshotKind(_session(kind, d));
    expect(of(SessionKind.skill, Discipline.boxing),
        snapshot.SessionKind.striking);
    expect(of(SessionKind.skill, Discipline.muayThai),
        snapshot.SessionKind.striking);
    expect(of(SessionKind.sparring, Discipline.wrestling),
        snapshot.SessionKind.wrestling);
    expect(of(SessionKind.skill, Discipline.bjj), snapshot.SessionKind.bjj);
    expect(of(SessionKind.conditioning), snapshot.SessionKind.conditioning);
    expect(of(SessionKind.strength), snapshot.SessionKind.strength);
    expect(of(SessionKind.recovery), snapshot.SessionKind.recovery);
  });

  test('a session with no fixed name is sent as other, never as words', () {
    expect(PlanLabels.snapshotKind(_session(SessionKind.skill)),
        snapshot.SessionKind.other);
    expect(PlanLabels.snapshotKind(_session(SessionKind.gymClass)),
        snapshot.SessionKind.other);
    expect(PlanLabels.snapshotKind(_session(SessionKind.skill, Discipline.mma)),
        snapshot.SessionKind.other);
  });

  Future<(AppState, PlanController)> setUp(
    List<LegacySessionSlot> slots,
  ) async {
    final repo = InMemoryDataRepository();
    for (final slot in slots) {
      await repo.saveLegacySession('u', slot);
    }
    final state = AppState(dataRepository: repo, clock: () => tuesday)
      ..setUser('u');
    final plan = PlanController(log: state, repository: repo)
      ..configure(userId: 'u');
    await pumpEventQueue();
    return (state, plan);
  }

  test("today's session is found by the plan's dated week", () async {
    final (_, plan) =
        await setUp([_slot('Mon', 'Striking'), _slot('Tue', 'Wrestling')]);

    expect(plan.todayRow?.session.date.weekday, DateTime.tuesday);
  });

  test('a rest day has no planned session', () async {
    final (state, plan) = await setUp([_slot('Mon', 'Striking')]);

    expect(plan.todayRow, isNull);
    final result = buildDailySnapshot(
      state,
      plan,
      FightCampController(repository: InMemoryFightCampRepository()),
    );
    expect(result.training.plannedToday, isNull);
    expect(result.training.plannedTodayDone, isFalse);
  });

  test('the snapshot carries the kind and whether it is done', () async {
    final (state, plan) = await setUp([_slot('Tue', 'Wrestling')]);
    final fightCamp =
        FightCampController(repository: InMemoryFightCampRepository());

    final before = buildDailySnapshot(state, plan, fightCamp);
    expect(before.training.plannedToday, isNotNull);
    expect(before.training.plannedTodayDone, isFalse);
    expect(before.training.plannedSessionsPerWeek, 1);

    plan.complete(plan.todayRow!.session, title: 'Done');
    final after = buildDailySnapshot(state, plan, fightCamp);
    expect(after.training.plannedTodayDone, isTrue);
    final json = after.toJson()['training'] as Map;
    expect(json['plannedTodayDone'], isTrue);
  });
}
