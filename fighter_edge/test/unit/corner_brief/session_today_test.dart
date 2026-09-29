import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/daily_snapshot/domain/daily_snapshot.dart';
import 'package:fighter_edge/features/daily_snapshot/presentation/daily_snapshot_builder.dart';
import 'package:fighter_edge/features/fight_camp/data/in_memory_fight_camp_repository.dart';
import 'package:fighter_edge/features/fight_camp/presentation/fight_camp_controller.dart';
import 'package:fighter_edge/models/training_session.dart';
import 'package:fighter_edge/state/app_state.dart';

TrainingSession _session(String day, String title, {bool completed = false}) =>
    TrainingSession(
      day: day,
      title: title,
      subtitle: '',
      icon: Icons.sports_mma,
      completed: completed,
    );

void main() {
  // A Tuesday.
  final tuesday = DateTime(2026, 9, 29, 12);

  test('the kind of a session comes from a fixed list of titles', () {
    expect(sessionKindOf(_session('Mon', 'Striking')), SessionKind.striking);
    expect(
        sessionKindOf(_session('Tue', ' Wrestling ')), SessionKind.wrestling);
    expect(sessionKindOf(_session('Wed', 'Conditioning')),
        SessionKind.conditioning);
    expect(sessionKindOf(_session('Thu', 'BJJ')), SessionKind.bjj);
    expect(sessionKindOf(_session('Fri', 'Strength')), SessionKind.strength);
    expect(sessionKindOf(_session('Sat', 'Recovery')), SessionKind.recovery);
  });

  test("a title of the athlete's own never leaves the device", () {
    expect(
      sessionKindOf(_session('Tue', 'Sparring with Coach Amir')),
      SessionKind.other,
    );
  });

  test("today's session is found by the plan's day name", () async {
    final repo = InMemoryDataRepository();
    await repo.saveSession('u', _session('Mon', 'Striking'));
    await repo.saveSession('u', _session('Tue', 'Wrestling'));
    final state = AppState(dataRepository: repo, clock: () => tuesday)
      ..setUser('u');
    await Future<void>.delayed(Duration.zero);

    expect(plannedSessionToday(state)?.title, 'Wrestling');
  });

  test('a rest day has no planned session', () async {
    final repo = InMemoryDataRepository();
    await repo.saveSession('u', _session('Mon', 'Striking'));
    final state = AppState(dataRepository: repo, clock: () => tuesday)
      ..setUser('u');
    await Future<void>.delayed(Duration.zero);

    expect(plannedSessionToday(state), isNull);
    final snapshot = buildDailySnapshot(
      state,
      FightCampController(repository: InMemoryFightCampRepository()),
    );
    expect(snapshot.training.plannedToday, isNull);
    expect(snapshot.training.plannedTodayDone, isFalse);
  });

  test('the snapshot carries the kind and whether it is done', () async {
    final repo = InMemoryDataRepository();
    await repo.saveSession('u', _session('Tue', 'Wrestling'));
    final state = AppState(dataRepository: repo, clock: () => tuesday)
      ..setUser('u');
    await Future<void>.delayed(Duration.zero);
    final fightCamp =
        FightCampController(repository: InMemoryFightCampRepository());

    final before = buildDailySnapshot(state, fightCamp);
    expect(before.training.plannedToday, SessionKind.wrestling);
    expect(before.training.plannedTodayDone, isFalse);
    final json = before.toJson()['training'] as Map;
    expect(json['plannedToday'], 'wrestling');
    expect(json['plannedTodayDone'], isFalse);
  });
}
