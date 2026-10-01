import 'dart:async';

import 'package:fighter_edge/features/fight_camp/data/fight_camp_repository.dart';
import 'package:fighter_edge/features/fight_camp/data/in_memory_fight_camp_repository.dart';
import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/camp_screening.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_path.dart';
import 'package:fighter_edge/features/fight_camp/presentation/fight_camp_controller.dart';
import 'package:fighter_edge/models/weight_entry.dart';
import 'package:fighter_edge/observability/error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 1);

FightCamp fightIn(int days, {double limit = 73.5}) => FightCamp.tryCreate(
      fightDate: addDays(today, days),
      weightLimitKg: limit,
      category: CompetitionCategory.professional,
      campWeeks: 12,
    )!;

class _FailingRepository implements FightCampRepository {
  final _controller = StreamController<FightCamp?>.broadcast();

  @override
  Stream<FightCamp?> watchFight(String userId) {
    Future.microtask(() => _controller.add(null));
    return _controller.stream;
  }

  @override
  Future<void> saveFight(String userId, FightCamp camp) =>
      Future.error(StateError('offline'));

  @override
  Future<void> deleteFight(String userId) =>
      Future.error(StateError('offline'));
}

class _RecordingReporter implements ErrorReporter {
  final reasons = <String?>[];

  @override
  void report(Object error, StackTrace stack,
      {String? reason, bool fatal = false}) {
    reasons.add(reason);
  }
}

void main() {
  test('loads nothing, then the saved fight, per account', () async {
    final repo = InMemoryFightCampRepository();
    await repo.saveFight('alice', fightIn(40));
    final controller = FightCampController(repository: repo);
    addTearDown(controller.dispose);

    controller.setUser('bob');
    expect(controller.loaded, isFalse);
    await pumpEventQueue();
    expect(controller.loaded, isTrue);
    expect(controller.camp, isNull);

    controller.setUser('alice');
    expect(controller.camp, isNull, reason: "bob's state is cleared at once");
    await pumpEventQueue();
    expect(controller.camp, fightIn(40));

    controller.setUser(null);
    expect(controller.camp, isNull);
    expect(controller.loaded, isFalse);
  });

  test('save and clear update the screen before the write lands', () async {
    final repo = InMemoryFightCampRepository();
    final controller = FightCampController(repository: repo);
    addTearDown(controller.dispose);
    controller.setUser('alice');
    await pumpEventQueue();

    var notified = 0;
    controller.addListener(() => notified++);
    controller.save(fightIn(40));
    expect(controller.camp, fightIn(40));
    expect(notified, greaterThan(0));
    await pumpEventQueue();
    expect(await repo.watchFight('alice').first, fightIn(40));

    controller.clear();
    expect(controller.camp, isNull);
    await pumpEventQueue();
    expect(await repo.watchFight('alice').first, isNull);
  });

  test('a failed write is reported and the athlete keeps their input',
      () async {
    final reporter = _RecordingReporter();
    final controller = FightCampController(
      repository: _FailingRepository(),
      errorReporter: reporter,
    );
    addTearDown(controller.dispose);
    controller.setUser('alice');
    await pumpEventQueue();

    controller.save(fightIn(40));
    await pumpEventQueue();
    expect(controller.camp, fightIn(40));
    controller.clear();
    await pumpEventQueue();
    expect(reporter.reasons, ['fight_save_failed', 'fight_delete_failed']);
  });

  test('does nothing without a signed-in account', () {
    final controller =
        FightCampController(repository: InMemoryFightCampRepository());
    addTearDown(controller.dispose);
    controller.save(fightIn(40));
    expect(controller.camp, isNull);
  });

  test('status reads the trend weight, phase and path', () {
    final status = FightCampStatus.of(
      fightIn(84),
      weights: [
        WeightEntry(addDays(today, -1), 80.4),
        WeightEntry(today, 79.6),
        WeightEntry(addDays(today, -30), 90), // outside the trend window
      ],
      today: today,
      ageYears: 30,
      screening: CampScreening.cleared,
    );
    expect(status.trend.trendKg, closeTo(80.0, 1e-9));
    expect(status.phase, CampPhase.camp);
    expect(status.daysToFight, 84);
    expect(status.daysToWeighIn, 84);
    expect(status.path.status, WeightPathStatus.onTrack);
  });

  test('a minor gets no plan', () {
    final status = FightCampStatus.of(
      fightIn(84),
      weights: [WeightEntry(today, 80)],
      today: today,
      ageYears: 16,
    );
    expect(status.path.status, WeightPathStatus.notSupported);
  });
}
