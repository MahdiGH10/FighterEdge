import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/training_plan/data/stored_training_plan.dart';
import 'package:fighter_edge/features/training_plan/presentation/plan_controller.dart';
import 'package:fighter_edge/features/weekly_review/domain/weekly_review.dart';
import 'package:fighter_edge/models/training_log_entry.dart';
import 'package:fighter_edge/state/app_state.dart';

/// Monday 2026-10-05, the first day of a plan with sessions on Mon, Wed, Fri.
final _start = DateTime(2026, 10, 5, 9);

class _Rig {
  _Rig(this.now, {int days = 3}) {
    state = AppState(clock: () => now);
    plan = PlanController(log: state)
      ..startFresh(
          weeklyTrainingDays: days, goal: 'Gain muscle', level: 'Beginner');
  }

  DateTime now;
  late final AppState state;
  late final PlanController plan;

  /// Does every session in the week starting [monday] on its own day.
  void doWeek(DateTime monday, {int skip = 0}) {
    final week = plan.weekContaining(monday)!;
    var left = skip;
    for (final session in week.sessions) {
      if (left > 0) {
        left--;
        continue;
      }
      state.addTrainingLogEntry(TrainingLogEntry(
        id: 'done-${session.id}',
        completedAt: session.date.add(const Duration(hours: 18)),
        source: TrainingSource.planned,
        title: 't',
        planSlotId: session.id,
      ));
    }
  }

  void dispose() {
    plan.dispose();
    state.dispose();
  }
}

_Rig _rig(DateTime now, {int days = 3}) {
  final rig = _Rig(now, days: days);
  addTearDown(rig.dispose);
  return rig;
}

void main() {
  group('weekly streak', () {
    test('counts weeks that met their target, not days', () {
      final rig = _rig(_start);
      rig.doWeek(_start);
      rig.doWeek(DateTime(2026, 10, 12));
      rig.now = DateTime(2026, 10, 19, 9); // Monday of week three

      final streak = rig.plan.weeklyStreak;
      expect(streak.count, 2);
      expect(streak.currentWeekAlive, isTrue);
    });

    test('this week joins the streak once its target is met', () {
      final rig = _rig(_start);
      rig.doWeek(_start);
      rig.now = DateTime(2026, 10, 12, 9); // Monday of week two
      expect(rig.plan.weeklyStreak.count, 1);
      rig.doWeek(DateTime(2026, 10, 12));
      expect(rig.plan.weeklyStreak.count, 2);
      expect(rig.plan.weeklyStreak.currentWeekMet, isTrue);
    });

    test('a week below target ends the streak once it is over', () {
      final rig = _rig(_start);
      rig.doWeek(_start);
      rig.doWeek(DateTime(2026, 10, 12), skip: 1);
      rig.now = DateTime(2026, 10, 21, 9); // week three, nothing yet
      expect(rig.plan.weeklyStreak.count, 0);
    });

    test('a busy week allows one miss (five planned, four count)', () {
      final rig = _rig(_start, days: 5);
      rig.doWeek(_start, skip: 1);
      rig.now = DateTime(2026, 10, 12, 9);
      expect(rig.plan.weeklyStreak.count, 1);
    });

    test('rest days never break it, whatever day it is', () {
      final rig = _rig(_start);
      for (var w = 0; w < 4; w++) {
        rig.doWeek(DateTime(2026, 10, 5 + 7 * w));
      }
      for (var d = 0; d < 28; d++) {
        rig.now = DateTime(2026, 10, 5 + d, 22);
        expect(rig.plan.weeklyStreak.count, d ~/ 7 + 1,
            reason: '${rig.now}: every planned session was done');
        expect(rig.plan.thisWeek.missed, 0);
      }
    });

    test('a plan that only just started has no streak and no failure', () {
      final rig = _rig(DateTime(2026, 10, 7, 9)); // Wednesday
      expect(rig.plan.weeklyStreak.count, 0);
      expect(rig.plan.weeklyStreak.currentWeekAlive, isTrue);
      expect(rig.plan.thisWeek.missed, 0);
    });

    test('no plan, no streak', () {
      final state = AppState(clock: () => _start);
      final plan = PlanController(log: state);
      addTearDown(plan.dispose);
      addTearDown(state.dispose);
      expect(plan.weeklyStreak.count, 0);
    });
  });

  group('weekly target', () {
    test('counts only planned sessions', () {
      final rig = _rig(_start);
      expect(rig.plan.thisWeek.planned, 3);
      expect(rig.plan.thisWeek.completed, 0);
      rig.plan.complete(rig.plan.todaySession!.session, title: 't');
      expect(rig.plan.thisWeek.completed, 1);
      expect(rig.plan.thisWeek.target, 3);
    });

    test('is one fewer with five or more planned', () {
      final rig = _rig(_start, days: 5);
      expect(rig.plan.thisWeek.planned, 5);
      expect(rig.plan.thisWeek.target, 4);
    });

    test('a skipped session is not a miss', () {
      final rig = _rig(_start);
      rig.plan.skip(rig.plan.todaySession!.session);
      expect(rig.plan.thisWeek.skipped, 1);
      expect(rig.plan.thisWeek.missed, 0);
    });
  });

  group('review decisions', () {
    test('are kept with the plan and survive a reload', () async {
      final repo = InMemoryDataRepository();
      addTearDown(repo.dispose);
      final state = AppState(dataRepository: repo, clock: () => _start)
        ..setUser('u');
      addTearDown(state.dispose);
      final plan = PlanController(log: state, repository: repo)
        ..configure(userId: 'u');
      addTearDown(plan.dispose);
      plan.startFresh(
          weeklyTrainingDays: 3, goal: 'Gain muscle', level: 'Beginner');
      expect(plan.reviewDecision(_start), isNull);

      plan.recordReview(_start, ReviewDecision.accepted);
      expect(plan.reviewDecision(_start), ReviewDecision.accepted);
      expect(plan.reviewDecision(DateTime(2026, 10, 12)), isNull);
      await pumpEventQueue();

      final saved = (await repo.watchTrainingPlan('u').first)!;
      expect(saved.reviews['2026-10-05'], ReviewDecision.accepted);
    });

    test('round-trip through JSON and ignore unknown values', () {
      final plan = StoredTrainingPlan.fromJson({
        'inputs': {
          'startDate': '2026-10-05',
          'weekdays': [1]
        },
        'reviews': {'2026-10-05': 'kept', '2026-10-12': 'maybe'},
      })!;
      expect(plan.reviews, {'2026-10-05': ReviewDecision.kept});
      expect(
          StoredTrainingPlan.fromJson(jsonDecode(jsonEncode(plan.toJson()))
                  as Map<String, dynamic>)!
              .reviews,
          plan.reviews);
    });
  });
}
