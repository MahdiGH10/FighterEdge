import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/fight_camp.dart';
import 'fight_camp_repository.dart';

/// `users/{uid}/fightCamp/current`. Owner-only in `firestore.rules`, and
/// removed with the rest of `users/{uid}` when the account is deleted.
class FirestoreFightCampRepository implements FightCampRepository {
  FirestoreFightCampRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String userId) => _db
      .collection('users')
      .doc(userId)
      .collection('fightCamp')
      .doc('current');

  @override
  Stream<FightCamp?> watchFight(String userId) => _doc(userId)
      .snapshots()
      .map((snap) => snap.exists ? FightCamp.fromJson(snap.data()!) : null);

  @override
  Future<void> saveFight(String userId, FightCamp camp) =>
      _doc(userId).set(camp.toJson());

  @override
  Future<void> deleteFight(String userId) => _doc(userId).delete();
}
