import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/data_repository.dart';
import '../../../models/meal.dart';
import '../domain/models/food_log_entry.dart';
import '../domain/models/nutrition_setup_draft.dart';
import '../domain/models/nutrition_day.dart';
import '../domain/models/nutrition_target.dart';
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
  Stream<NutritionDay> watchNutritionDay(
    String userId,
    DateTime localDate, {
    NutritionTarget? targetSnapshot,
  }) {
    return _dayDoc(userId, localDate).snapshots().asyncMap((snapshot) async {
      final data = snapshot.data();
      if (data != null) {
        return NutritionDay.fromJson(_normalizedTimestamps(data));
      }

      final migrated = await _migrateLegacyMealsIfPresent(
        userId,
        localDate,
        targetSnapshot: targetSnapshot,
      );
      return migrated ??
          NutritionDay.empty(
            localDate: mealDateKey(localDate),
            timeZone: localDate.timeZoneName,
            now: DateTime.now(),
            targetSnapshot: targetSnapshot,
          );
    });
  }

  @override
  Future<void> saveNutritionDay(String userId, NutritionDay day) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('nutritionDays')
        .doc(day.localDate)
        .set({
      ...day.toJson(),
      'totals': FoodLogTotals.fromEntries(day.entries).toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<NutritionDay?> _migrateLegacyMealsIfPresent(
    String userId,
    DateTime localDate, {
    NutritionTarget? targetSnapshot,
  }) async {
    final legacySnapshot = await _legacyMealDoc(userId, localDate).get();
    final data = legacySnapshot.data();
    final rawMeals = data?['meals'] as List<dynamic>? ?? const [];
    if (rawMeals.isEmpty) return null;

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
    if (entries.isEmpty) return null;

    final now = DateTime.now();
    final migrated = NutritionDay.empty(
      localDate: mealDateKey(localDate),
      timeZone: localDate.timeZoneName,
      now: now,
      targetSnapshot: targetSnapshot,
    ).copyWith(
      entries: entries,
      migratedFromLegacyMeals: true,
      loggingCoverage: entries.length < 3 ? 'partial' : 'full',
      updatedAt: now,
    );
    await saveNutritionDay(userId, migrated);
    return migrated;
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
