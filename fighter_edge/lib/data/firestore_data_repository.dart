import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/meal.dart';
import '../models/training_log_entry.dart';
import '../models/training_session.dart';
import '../models/weight_entry.dart';
import 'data_repository.dart';

class FirestoreDataRepository implements DataRepository {
  FirestoreDataRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _userCollection(
    String userId,
    String collection,
  ) =>
      _db.collection('users').doc(userId).collection(collection);

  @override
  Stream<List<WeightEntry>> watchWeights(String userId) {
    return _userCollection(userId, 'weights')
        .orderBy('date')
        .snapshots()
        .map((snapshot) => [
              for (final doc in snapshot.docs)
                WeightEntry.fromJson(doc.data(), id: doc.id),
            ]);
  }

  @override
  Future<void> addWeight(String userId, WeightEntry entry) {
    final docId = entry.stableId;
    return _userCollection(userId, 'weights').doc(docId).set(entry.toJson());
  }

  @override
  Stream<List<Meal>> watchMeals(String userId, DateTime date) {
    return _userCollection(userId, 'meals')
        .doc(mealDateKey(date))
        .snapshots()
        .map((snapshot) {
      final rawMeals = snapshot.data()?['meals'] as List<dynamic>? ?? [];
      return [
        for (final raw in rawMeals)
          Meal.fromJson(Map<String, dynamic>.from(raw as Map)),
      ];
    });
  }

  @override
  Future<void> saveMealsForDate(
    String userId,
    DateTime date,
    List<Meal> meals,
  ) {
    return _userCollection(userId, 'meals').doc(mealDateKey(date)).set({
      'date': mealDateKey(date),
      'meals': [for (final meal in meals) meal.toJson()],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Stream<List<TrainingSession>> watchSessions(String userId) {
    return _userCollection(userId, 'sessions').snapshots().map((snapshot) {
      final sessions = [
        for (final doc in snapshot.docs) TrainingSession.fromJson(doc.data()),
      ]..sort((a, b) => _dayOrder(a.day).compareTo(_dayOrder(b.day)));
      return sessions;
    });
  }

  @override
  Future<void> saveSession(String userId, TrainingSession session) {
    return _userCollection(userId, 'sessions')
        .doc(session.id)
        .set(session.toJson());
  }

  @override
  Stream<List<TrainingLogEntry>> watchTrainingLog(String userId) {
    return _userCollection(userId, 'trainingLog')
        .orderBy('completedAtMs', descending: true)
        .snapshots()
        .map((snapshot) => [
              for (final doc in snapshot.docs)
                if (TrainingLogEntry.fromJson(doc.data(), id: doc.id)
                    case final entry?)
                  entry,
            ]);
  }

  @override
  Future<void> saveTrainingLogEntry(String userId, TrainingLogEntry entry) {
    return _userCollection(userId, 'trainingLog')
        .doc(entry.id)
        .set(entry.toJson());
  }

  @override
  Future<void> deleteTrainingLogEntry(String userId, String entryId) {
    return _userCollection(userId, 'trainingLog').doc(entryId).delete();
  }

  int _dayOrder(String day) {
    return switch (day.toLowerCase()) {
      'mon' => 1,
      'tue' => 2,
      'wed' => 3,
      'thu' => 4,
      'fri' => 5,
      'sat' => 6,
      'sun' => 7,
      _ => 99,
    };
  }
}
