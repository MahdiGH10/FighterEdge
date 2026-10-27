import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// A push that arrived while the app was in front. When the app is in the
/// background Android shows the notification itself, so only these need the
/// app's help.
class PushMessage {
  const PushMessage({required this.title, required this.body});

  final String title;
  final String body;
}

/// Provider-neutral boundary for remote (Firebase Cloud Messaging) pushes.
///
/// Like the reminder gateway: product code depends on this interface, never
/// on the messaging SDK, so tests and platforms without push get a safe no-op.
/// Nothing here carries health data: a push is a plain title and body.
abstract class PushGateway {
  /// Whether this platform can receive pushes. Android only for now: iOS also
  /// needs the Push Notifications capability and an APNs key in Firebase.
  bool get isAvailable;

  /// This phone's current messaging token, or null when it cannot be had.
  Future<String?> token();

  /// A new token, when Firebase rotates it.
  Stream<String> get tokenRefresh => const Stream.empty();

  /// Pushes that arrive while the app is in front.
  Stream<PushMessage> get foreground => const Stream.empty();

  /// Forgets this phone's token, so the next account to sign in on it does not
  /// receive the previous account's pushes.
  Future<void> deleteToken();
}

/// No push on this platform.
class NoPushGateway implements PushGateway {
  const NoPushGateway();

  @override
  bool get isAvailable => false;

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokenRefresh => const Stream.empty();

  @override
  Stream<PushMessage> get foreground => const Stream.empty();

  @override
  Future<void> deleteToken() async {}
}

/// [PushGateway] on `firebase_messaging`.
class FirebasePushGateway implements PushGateway {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  bool get isAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<String?> token() async {
    if (!isAvailable) return null;
    try {
      // Auto-init is off in the manifest, so no token exists until now.
      await _messaging.setAutoInitEnabled(true);
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<String> get tokenRefresh =>
      isAvailable ? _messaging.onTokenRefresh : const Stream.empty();

  @override
  Stream<PushMessage> get foreground {
    if (!isAvailable) return const Stream.empty();
    return FirebaseMessaging.onMessage
        .map((message) {
          final notification = message.notification;
          final title = notification?.title;
          final body = notification?.body;
          if (title == null && body == null) return null;
          return PushMessage(title: title ?? '', body: body ?? '');
        })
        .where((message) => message != null)
        .cast<PushMessage>();
  }

  @override
  Future<void> deleteToken() async {
    if (!isAvailable) return;
    try {
      await _messaging.deleteToken();
    } catch (_) {}
  }
}
