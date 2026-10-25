import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/data_repository.dart';
import '../../../models/meal.dart';
import '../domain/models/food_log_entry.dart';
import '../domain/models/nutrition_setup_draft.dart';
import '../domain/models/nutrition_day.dart';
import '../domain/models/nutrition_target.dart';
import '../../training_plan/data/stored_training_plan.dart';
import '../../training_plan/domain/models/date_key.dart';
import 'edge_fuel_repository.dart';

/// Firestore-backed EdgeFuel storage. Paths match master prompt §12:
/// `users/{uid}/nutritionProfile/current` and
/// `users/{uid}/nutritionTargets/current`. One document each is sufficient
/// for V1 (a single user has no write concurrency on their own profile).
class FirestoreEdgeFuelRepository implements EdgeFuelRepository {
  FirestoreEdgeFuelRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _profileDoc(String userId) => _db
      .collection('users')
      .doc(userId)
      .collection('nutritionProfile')
      .doc('current');

  DocumentReference<Map<String, dynamic>> _targetDoc(String userId) => _db
      .collection('users')
      .doc(userId)
      .collection('nutritionTargets')
      .doc('current');

  DocumentReference<Map<String, dynamic>> _dayDoc(
    String userId,
    DateTime localDate,
  ) =>
      _db
          .collection('users')
          .doc(userId)
          .collection('nutritionDays')
          .doc(mealDateKey(localDate));

  CollectionReference<Map<String, dynamic>> _entries(
    String userId,
    String localDate,
  ) =>
      _db
          .collection('users')
          .doc(userId)
          .collection('nutritionDays')
          .doc(localDate)
          .collection('entries');

  DocumentReference<Map<String, dynamic>> _entryDoc(
    String userId,
    String localDate,
    String entryId,
  ) =>
      _entries(userId, localDate).doc(base64Url.encode(utf8.encode(entryId)));

  DocumentReference<Map<String, dynamic>> _legacyMealDoc(
    String userId,
    DateTime localDate,
  ) =>
      _db
          .collection('users')
          .doc(userId)
          .collection('meals')
          .doc(mealDateKey(localDate));

  @override
  Stream<NutritionSetupDraft?> watchProfileDraft(String userId) {
    return _profileDoc(userId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return NutritionSetupDraft.fromJson(data);
    });
  }

  @override
  Future<void> saveProfileDraft(
    String userId,
    NutritionSetupDraft draft,
  ) {
    return _profileDoc(userId).set({
      ...draft.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Stream<NutritionTarget?> watchTarget(String userId) {
    return _targetDoc(userId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return NutritionTarget.fromJson(data);
    });
  }

  @override
  Future<void> saveTarget(String userId, NutritionTarget target) {
    return _targetDoc(userId).set({
      ...target.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> saveConfirmedPlan(
      String userId, NutritionSetupDraft draft, NutritionTarget target) {
    final batch = _db.batch();
    batch.set(_profileDoc(userId), {
      ...draft.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_targetDoc(userId), {
      ...target.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return batch.commit();
  }

  @override
  Future<void> saveAcceptedReview(String userId, NutritionTarget target,
      StoredTrainingPlan plan, DateTime weekStart) {
    final reviewKey = dateKey(weekStart);
    if (plan.reviews[reviewKey]?.name != 'accepted') {
      throw StateError('Review was not prepared for acceptance');
    }
    final planDoc = _db
        .collection('users')
        .doc(userId)
        .collection('trainingPlan')
        .doc('current');
    return _db.runTransaction((transaction) async {
      final savedPlan = await transaction.get(planDoc);
      if (!savedPlan.exists) throw StateError('Training plan is missing');
      final reviews = savedPlan.data()?['reviews'];
      if (reviews is Map && reviews.containsKey(reviewKey)) {
        throw StateError('Review already has a decision');
      }
      transaction.set(_targetDoc(userId), {
        ...target.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(planDoc, {'reviews.$reviewKey': 'accepted'});
    });
  }

  @override
  Stream<NutritionDay> watchNutritionDay(
    String userId,
    DateTime localDate, {
    NutritionTarget? targetSnapshot,
  }) {
    final dateKey = mealDateKey(localDate);
    DocumentSnapshot<Map<String, dynamic>>? daySnapshot;
    QuerySnapshot<Map<String, dynamic>>? entrySnapshot;
    DocumentSnapshot<Map<String, dynamic>>? legacySnapshot;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? daySub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? entrySub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? legacySub;
    late final StreamController<NutritionDay> controller;

    void emit() {
      if (controller.isClosed || daySnapshot == null || entrySnapshot == null) {
        return;
      }
      final data = daySnapshot!.data();
      if (data == null && legacySnapshot == null) return;
      final legacyMeals = data == null
          ? _legacyEntries(legacySnapshot!.data(), localDate)
          : const <FoodLogEntry>[];

      final base = data == null
          ? NutritionDay.empty(
              localDate: dateKey,
              timeZone: localDate.timeZoneName,
              now: DateTime.now(),
              targetSnapshot: targetSnapshot,
            ).copyWith(
              entries: legacyMeals,
              migratedFromLegacyMeals: legacyMeals.isNotEmpty,
            )
          : NutritionDay.fromJson(_normalizedTimestamps(data));
      // Old day arrays stay readable. Each new entry document overrides the
      // same ID, including a tombstone for a deleted legacy entry.
      final byId = {for (final entry in base.entries) entry.id: entry};
      for (final document in entrySnapshot!.docs) {
        final record = document.data();
        final id = record['id'];
        if (id is! String || id.isEmpty) continue;
        if (record['deleted'] == true) {
          byId.remove(id);
        } else {
          byId[id] = FoodLogEntry.fromJson(record);
        }
      }
      final entries = byId.values.toList()
        ..sort((a, b) {
          final time = a.loggedAt.compareTo(b.loggedAt);
          return time != 0 ? time : a.id.compareTo(b.id);
        });
      controller.add(base.copyWith(entries: entries));
    }

    controller = StreamController<NutritionDay>(
      onListen: () {
        daySub = _dayDoc(userId, localDate).snapshots().listen(
          (snapshot) {
            daySnapshot = snapshot;
            emit();
          },
          onError: controller.addError,
        );
        entrySub = _entries(userId, dateKey).snapshots().listen(
          (snapshot) {
            entrySnapshot = snapshot;
            emit();
          },
          onError: controller.addError,
        );
        legacySub = _legacyMealDoc(userId, localDate).snapshots().listen(
          (snapshot) {
            legacySnapshot = snapshot;
            emit();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await daySub?.cancel();
        await entrySub?.cancel();
        await legacySub?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> saveNutritionDay(String userId, NutritionDay day) {
    // Used by imports/fixtures, not interactive edits. Never replace the
    // legacy entries array or delete other devices' entry documents.
    final batch = _db.batch();
    final metadata = day.toJson()
      ..remove('entries')
      ..remove('totals');
    batch.set(
        _dayDoc(userId, DateTime.parse(day.localDate)),
        {
          ...metadata,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    for (final entry in day.entries) {
      batch.set(_entryDoc(userId, day.localDate, entry.id), {
        ...entry.toJson(),
        'deleted': false,
      });
    }
    return batch.commit();
  }

  @override
  Future<void> upsertFoodEntry(
    String userId,
    String localDate,
    FoodLogEntry entry,
  ) =>
      _entryDoc(userId, localDate, entry.id).set({
        ...entry.toJson(),
        'deleted': false,
      });

  @override
  Future<void> deleteFoodEntry(
    String userId,
    String localDate,
    String entryId,
  ) =>
      _entryDoc(userId, localDate, entryId).set({
        'id': entryId,
        'deleted': true,
      });

  List<FoodLogEntry> _legacyEntries(
    Map<String, dynamic>? data,
    DateTime localDate,
  ) {
    final rawMeals = data?['meals'] as List<dynamic>? ?? const [];
    if (rawMeals.isEmpty) return const [];

    final entries = <FoodLogEntry>[];
    for (final raw in rawMeals) {
      if (raw is! Map) {
        continue;
      }
      final meal = Meal.fromJson(Map<String, dynamic>.from(raw));
      if (meal.name.trim().isEmpty && meal.calories <= 0) {
        continue;
      }
      entries.add(
        FoodLogEntry.fromMeal(
          meal,
          loggedAt:
              DateTime(localDate.year, localDate.month, localDate.day, 12),
        ),
      );
    }
    return entries;
  }

  Map<String, dynamic> _normalizedTimestamps(Map<String, dynamic> data) {
    String normalize(Object? value) {
      if (value is Timestamp) return value.toDate().toIso8601String();
      if (value is String) return value;
      return DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();
    }

    return {
      ...data,
      'createdAt': normalize(data['createdAt']),
      'updatedAt': normalize(data['updatedAt']),
    };
  }
}
