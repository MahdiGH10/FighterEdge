import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/nutrition_setup_draft.dart';
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
}
