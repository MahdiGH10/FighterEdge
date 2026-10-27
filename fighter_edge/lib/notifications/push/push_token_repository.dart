import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Where a phone's messaging token is kept: `users/{uid}/pushTokens/{id}`.
///
/// The token is only an address Firebase uses to reach this install. It is
/// readable by its owner alone, removed when the account is deleted, and
/// removed when the account signs out of the phone.
abstract class PushTokenRepository {
  Future<void> save(String userId, String token, String platform);

  Future<void> delete(String userId, String token);
}

/// The document id for a token. A messaging token is `<install id>:<secret>`;
/// the install id is stable while the token rotates, so a refresh updates one
/// document instead of piling up new ones.
String pushTokenId(String token) {
  final colon = token.indexOf(':');
  if (colon > 0) return token.substring(0, colon);
  final encoded = base64Url.encode(utf8.encode(token));
  return encoded.length > 40 ? encoded.substring(0, 40) : encoded;
}

class FirestorePushTokenRepository implements PushTokenRepository {
  FirestorePushTokenRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  // Looked up on use: this is built before Firebase is initialised.
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String userId, String token) =>
      _db
          .collection('users')
          .doc(userId)
          .collection('pushTokens')
          .doc(pushTokenId(token));

  @override
  Future<void> save(String userId, String token, String platform) =>
      _doc(userId, token).set({
        'token': token,
        'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> delete(String userId, String token) =>
      _doc(userId, token).delete();
}
