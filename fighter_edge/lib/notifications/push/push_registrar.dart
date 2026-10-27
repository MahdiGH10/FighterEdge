import 'dart:async';

import '../reminder_gateway.dart';
import 'push_gateway.dart';
import 'push_token_repository.dart';

/// Keeps this phone's messaging token filed under the signed-in account, so
/// Firebase can send that account a push.
///
/// It registers only once the athlete has allowed notifications (the same
/// permission the reminders use), shows a push that arrives while the app is
/// in front, and removes the token when the account signs out of the phone.
/// Every call is safe to repeat and never throws: a push that cannot be set up
/// must not break the app.
class PushRegistrar {
  PushRegistrar({
    required PushGateway push,
    required PushTokenRepository tokens,
    required ReminderGateway reminders,
    String platform = 'android',
  })  : _push = push,
        _tokens = tokens,
        _reminders = reminders,
        _platform = platform;

  final PushGateway _push;
  final PushTokenRepository _tokens;
  final ReminderGateway _reminders;
  final String _platform;

  /// The id of the notification a foreground push is shown under.
  static const foregroundNotificationId = 6900;

  String? _userId;
  String? _token;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<PushMessage>? _foregroundSub;

  /// Files the current token for [userId], if notifications are allowed.
  Future<void> sync(String? userId) async {
    if (userId == null || !_push.isAvailable) return;
    try {
      if (!await _reminders.areNotificationsAllowed()) return;
      _userId = userId;
      _listen();
      final token = await _push.token();
      if (token == null || token.isEmpty) return;
      _token = token;
      await _tokens.save(userId, token, _platform);
    } catch (_) {
      // Registration is a convenience; the next sync tries again.
    }
  }

  /// The account signed out of this phone: forget the token, here and in
  /// Firebase, so the next account on the phone starts clean.
  Future<void> release(String userId) async {
    final token = _token;
    _token = null;
    _userId = null;
    try {
      if (token != null) await _tokens.delete(userId, token);
      await _push.deleteToken();
    } catch (_) {}
  }

  void _listen() {
    _refreshSub ??= _push.tokenRefresh.listen((token) async {
      final userId = _userId;
      if (userId == null || token.isEmpty) return;
      _token = token;
      try {
        await _tokens.save(userId, token, _platform);
      } catch (_) {}
    });
    _foregroundSub ??= _push.foreground.listen((message) {
      unawaited(_reminders.showNow(
        id: foregroundNotificationId,
        title: message.title,
        body: message.body,
      ));
    });
  }

  Future<void> dispose() async {
    await _refreshSub?.cancel();
    await _foregroundSub?.cancel();
  }
}
