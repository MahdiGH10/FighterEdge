import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/features/edge_fuel/data/firestore_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/models/meal.dart';
import 'package:fighter_edge/state/sync_tracker.dart';

FoodLogEntry food(String id) => FoodLogEntry(
      id: id,
      name: 'Food $id',
      notes: '',
      calories: 300,
      proteinGrams: 20,
      carbGrams: 40,
      fatGrams: 7,
      loggedAt: DateTime(2026, 10, 25, 12),
    );

class _DelayedDayRepository extends InMemoryEdgeFuelRepository {
  final firstDay = StreamController<NutritionDay>.broadcast();
  int writes = 0;

  @override
  Stream<NutritionDay> watchNutritionDay(String userId, DateTime date,
          {dynamic targetSnapshot}) =>
      firstDay.stream;

  @override
  Future<void> upsertFoodEntry(
      String userId, String localDate, FoodLogEntry entry) async {
    writes++;
    await super.upsertFoodEntry(userId, localDate, entry);
  }

  Future<NutritionDay> stored(String userId, DateTime date) =>
      super.watchNutritionDay(userId, date).first;
}

class _RejectingRepository extends InMemoryEdgeFuelRepository {
  bool reject = true;
  int writes = 0;

  @override
  Future<void> upsertFoodEntry(
      String userId, String localDate, FoodLogEntry entry) async {
    writes++;
    if (reject) throw StateError('rejected');
    await super.upsertFoodEntry(userId, localDate, entry);
  }
}

class _RejectingDeleteRepository extends InMemoryEdgeFuelRepository {
  bool rejectDelete = true;

  @override
  Future<void> deleteFoodEntry(
      String userId, String localDate, String entryId) async {
    if (rejectDelete) throw StateError('rejected');
    await super.deleteFoodEntry(userId, localDate, entryId);
  }
}

class _DelayedFirstWriteRepository extends InMemoryEdgeFuelRepository {
  final firstWrite = Completer<void>();
  int writes = 0;

  @override
  Future<void> upsertFoodEntry(
      String userId, String localDate, FoodLogEntry entry) async {
    if (writes++ == 0) {
      await firstWrite.future;
      throw StateError('rejected');
    }
    await super.upsertFoodEntry(userId, localDate, entry);
  }
}

class _QueuedWrite {
  _QueuedWrite(this.userId, this.localDate, this.entry);
  final String userId;
  final String localDate;
  final FoodLogEntry entry;
  final ack = Completer<void>();
}

class _QueuedRepository extends InMemoryEdgeFuelRepository {
  bool online = false;
  final pending = <_QueuedWrite>[];

  @override
  Future<void> upsertFoodEntry(
      String userId, String localDate, FoodLogEntry entry) {
    if (online) return super.upsertFoodEntry(userId, localDate, entry);
    final write = _QueuedWrite(userId, localDate, entry);
    pending.add(write);
    return write.ack.future;
  }

  Future<void> reconnect() async {
    online = true;
    for (final write in pending) {
      await super.upsertFoodEntry(write.userId, write.localDate, write.entry);
      write.ack.complete();
    }
    pending.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('two devices add to the same day without replacing either entry',
      () async {
    final db = FakeFirebaseFirestore();
    final first = FirestoreEdgeFuelRepository(firestore: db);
    final second = FirestoreEdgeFuelRepository(firestore: db);
    final date = DateTime(2026, 10, 25);
    // Both devices begin from the same empty snapshot.
    expect((await first.watchNutritionDay('u', date).first).entries, isEmpty);
    expect((await second.watchNutritionDay('u', date).first).entries, isEmpty);
    await first.upsertFoodEntry('u', '2026-10-25', food('a'));
    await second.upsertFoodEntry('u', '2026-10-25', food('b'));
    final stored = await first.watchNutritionDay('u', date).first;
    expect(stored.entries.map((entry) => entry.id).toSet(), {'a', 'b'});
    expect(stored.totals.calories, 600);
  });

  test('replaying an entry ID after restart does not duplicate it', () async {
    final db = FakeFirebaseFirestore();
    final before = FirestoreEdgeFuelRepository(firestore: db);
    await before.upsertFoodEntry('u', '2026-10-25', food('same'));
    final after = FirestoreEdgeFuelRepository(firestore: db);
    await after.upsertFoodEntry('u', '2026-10-25', food('same'));
    final stored =
        await after.watchNutritionDay('u', DateTime(2026, 10, 25)).first;
    expect(stored.entries.map((entry) => entry.id), ['same']);
  });

  test('legacy day arrays stay readable; edits and tombstones overlay them',
      () async {
    final db = FakeFirebaseFirestore();
    final date = DateTime(2026, 10, 25);
    final legacy = NutritionDay.empty(
      localDate: '2026-10-25',
      timeZone: 'local',
      now: date,
    ).copyWith(entries: [food('old')]);
    await db
        .collection('users')
        .doc('u')
        .collection('nutritionDays')
        .doc('2026-10-25')
        .set(legacy.toJson());
    final repo = FirestoreEdgeFuelRepository(firestore: db);
    expect((await repo.watchNutritionDay('u', date).first).entries.single.id,
        'old');
    await repo.upsertFoodEntry('u', '2026-10-25', food('new'));
    expect((await repo.watchNutritionDay('u', date).first).entries.length, 2);
    await repo.deleteFoodEntry('u', '2026-10-25', 'old');
    final reopened = FirestoreEdgeFuelRepository(firestore: db);
    final stored = await reopened.watchNutritionDay('u', date).first;
    expect(stored.entries.map((entry) => entry.id), ['new']);
    final raw = await db
        .collection('users')
        .doc('u')
        .collection('nutritionDays')
        .doc('2026-10-25')
        .get();
    expect((raw.data()!['entries'] as List), hasLength(1),
        reason: 'the legacy array was preserved for safe rollout');
  });

  test('old meals documents are read without replacing new entry documents',
      () async {
    final db = FakeFirebaseFirestore();
    final oldMeal = Meal(
      id: 'breakfast',
      name: 'Breakfast',
      items: 'Oats',
      calories: 300,
      protein: 10,
      carbs: 50,
      fats: 6,
      eaten: true,
    );
    await db
        .collection('users')
        .doc('u')
        .collection('meals')
        .doc('2026-10-25')
        .set({
      'meals': [oldMeal.toJson()]
    });
    final repo = FirestoreEdgeFuelRepository(firestore: db);
    await repo.upsertFoodEntry('u', '2026-10-25', food('new'));
    final merged =
        await repo.watchNutritionDay('u', DateTime(2026, 10, 25)).first;
    expect(merged.entries.map((entry) => entry.id).toSet(),
        {'legacy-breakfast', 'new'});
    await repo.deleteFoodEntry('u', '2026-10-25', 'legacy-breakfast');
    final reopened = await FirestoreEdgeFuelRepository(firestore: db)
        .watchNutritionDay('u', DateTime(2026, 10, 25))
        .first;
    expect(reopened.entries.map((entry) => entry.id), ['new']);
  });

  test('a write before the first day load is blocked', () async {
    final repo = _DelayedDayRepository();
    final controller = EdgeFuelController(repository: repo)..setUser('u');
    await Future<void>.delayed(Duration.zero);
    expect(controller.dayLoaded, isFalse);
    await controller.addEntry(food('new'));
    expect(repo.writes, 0);

    final date = controller.selectedDate;
    final existing = NutritionDay.empty(
      localDate: '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}',
      timeZone: 'local',
      now: date,
    ).copyWith(entries: [food('existing')]);
    await repo.saveNutritionDay('u', existing);
    repo.firstDay.add(existing);
    await Future<void>.delayed(Duration.zero);
    expect(controller.dayLoaded, isTrue);
    await controller.addEntry(food('new'));
    expect((await repo.stored('u', date)).entries.map((e) => e.id).toSet(),
        {'existing', 'new'});
    controller.dispose();
    await repo.firstDay.close();
  });

  test('a failed entry retries its original day after date navigation',
      () async {
    final repo = _RejectingRepository();
    final sync = SyncTracker();
    final controller = EdgeFuelController(repository: repo, sync: sync)
      ..setUser('u');
    await Future<void>.delayed(Duration.zero);
    final original = controller.selectedDate;
    await controller.addEntry(food('failed'));
    expect(sync.hasFailure, isTrue);
    controller.shiftDate(1);
    await Future<void>.delayed(Duration.zero);
    repo.reject = false;
    await sync.retry();
    expect(
        (await repo.watchNutritionDay('u', original).first).entries.single.id,
        'failed');
    expect(controller.entries, isEmpty,
        reason: 'the next day must not receive the retry');
    expect(sync.hasFailure, isFalse);
    controller.dispose();
    sync.dispose();
  });

  test('a retry cannot write a failed entry into a different account',
      () async {
    final repo = _RejectingRepository();
    final sync = SyncTracker();
    final controller = EdgeFuelController(repository: repo, sync: sync)
      ..setUser('first');
    await Future<void>.delayed(Duration.zero);
    final date = controller.selectedDate;
    await controller.addEntry(food('failed'));
    controller.setUser('second');
    await Future<void>.delayed(Duration.zero);
    repo.reject = false;
    await sync.retry();
    expect(
        (await repo.watchNutritionDay('first', date).first).entries, isEmpty);
    expect(
        (await repo.watchNutritionDay('second', date).first).entries, isEmpty);
    controller.dispose();
    sync.dispose();
  });

  test('a failed deletion retries the original day as a tombstone', () async {
    final repo = _RejectingDeleteRepository();
    final sync = SyncTracker();
    final controller = EdgeFuelController(repository: repo, sync: sync)
      ..setUser('u');
    await Future<void>.delayed(Duration.zero);
    final original = controller.selectedDate;
    await controller.addEntry(food('remove'));
    await controller.deleteEntry(controller.entries.single);
    expect(sync.hasFailure, isTrue);
    controller.shiftDate(1);
    await Future<void>.delayed(Duration.zero);
    repo.rejectDelete = false;
    await sync.retry();
    expect(
        (await repo.watchNutritionDay('u', original).first).entries, isEmpty);
    expect(sync.hasFailure, isFalse);
    controller.dispose();
    sync.dispose();
  });

  test('an older rejected write cannot retry over a newer accepted edit',
      () async {
    final repo = _DelayedFirstWriteRepository();
    final sync = SyncTracker();
    final controller = EdgeFuelController(repository: repo, sync: sync)
      ..setUser('u');
    await Future<void>.delayed(Duration.zero);
    final first = controller.addEntry(food('same'));
    await Future<void>.delayed(Duration.zero);
    await controller.updateEntry(food('same').copyWith(calories: 450));
    repo.firstWrite.complete();
    await first;
    expect(sync.hasFailure, isFalse);
    expect(controller.entries.single.calories, 450);
    expect(
        (await repo.watchNutritionDay('u', controller.selectedDate).first)
            .entries
            .single
            .calories,
        450);
    controller.dispose();
    sync.dispose();
  });

  test('offline entry stays visible and is stored after reconnect', () async {
    final repo = _QueuedRepository();
    final controller = EdgeFuelController(repository: repo)..setUser('u');
    await Future<void>.delayed(Duration.zero);
    final date = controller.selectedDate;
    var acknowledged = false;
    unawaited(controller.addEntry(food('offline')).then((_) {
      acknowledged = true;
    }));
    await Future<void>.delayed(Duration.zero);
    expect(controller.entries.single.id, 'offline');
    expect(acknowledged, isFalse);
    await repo.reconnect();
    await Future<void>.delayed(Duration.zero);
    expect(acknowledged, isTrue);
    controller.dispose();
    final restarted = EdgeFuelController(repository: repo)..setUser('u');
    await Future<void>.delayed(Duration.zero);
    expect((await repo.watchNutritionDay('u', date).first).entries.single.id,
        'offline');
    restarted.dispose();
  });
}
