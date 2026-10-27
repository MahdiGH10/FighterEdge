import 'dart:async';

import 'package:fighter_edge/notifications/push/push_gateway.dart';
import 'package:fighter_edge/notifications/push/push_registrar.dart';
import 'package:fighter_edge/notifications/push/push_token_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_harness.dart';

class _FakePush implements PushGateway {
  _FakePush();

  bool available = true;
  String? currentToken = 'install1:secret';
  int tokenCalls = 0;
  int deleted = 0;
  final refresh = StreamController<String>.broadcast();
  final foregroundMessages = StreamController<PushMessage>.broadcast();

  @override
  bool get isAvailable => available;
  @override
  Future<String?> token() async {
    tokenCalls++;
    return currentToken;
  }

  @override
  Stream<String> get tokenRefresh => refresh.stream;
  @override
  Stream<PushMessage> get foreground => foregroundMessages.stream;
  @override
  Future<void> deleteToken() async => deleted++;
}

class _MemoryTokens implements PushTokenRepository {
  final saved = <String, Map<String, String>>{};
  Object? failWith;

  @override
  Future<void> save(String userId, String token, String platform) async {
    if (failWith != null) throw failWith!;
    saved['$userId/${pushTokenId(token)}'] = {
      'token': token,
      'platform': platform,
    };
  }

  @override
  Future<void> delete(String userId, String token) async {
    saved.remove('$userId/${pushTokenId(token)}');
  }
}

void main() {
  late _FakePush push;
  late _MemoryTokens tokens;
  late FakeReminderGateway reminders;
  late PushRegistrar registrar;

  setUp(() {
    push = _FakePush();
    tokens = _MemoryTokens();
    reminders = FakeReminderGateway(allowed: true);
    registrar = PushRegistrar(push: push, tokens: tokens, reminders: reminders);
  });

  tearDown(() => registrar.dispose());

  test('the document id is the install id, stable while the token rotates', () {
    expect(pushTokenId('abc123:APA91bSecretOne'), 'abc123');
    expect(pushTokenId('abc123:APA91bSecretTwo'), 'abc123');
    expect(pushTokenId('nocolonhere'), isNotEmpty);
    expect(pushTokenId('x' * 500).length, lessThanOrEqualTo(40));
  });

  test('a signed-in athlete who allowed notifications gets a token filed',
      () async {
    await registrar.sync('alice');
    expect(tokens.saved['alice/install1'],
        {'token': 'install1:secret', 'platform': 'android'});
  });

  test('nothing is registered before the athlete allows notifications',
      () async {
    reminders.allowed = false;
    await registrar.sync('alice');
    expect(push.tokenCalls, 0, reason: 'no token is even requested');
    expect(tokens.saved, isEmpty);
  });

  test('nothing is registered when signed out or without push', () async {
    await registrar.sync(null);
    push.available = false;
    await registrar.sync('alice');
    expect(push.tokenCalls, 0);
    expect(tokens.saved, isEmpty);
  });

  test('syncing again updates the same document', () async {
    await registrar.sync('alice');
    push.currentToken = 'install1:rotated';
    await registrar.sync('alice');
    expect(tokens.saved, hasLength(1));
    expect(tokens.saved['alice/install1']!['token'], 'install1:rotated');
  });

  test('a rotated token from Firebase is filed under the same account',
      () async {
    await registrar.sync('alice');
    push.refresh.add('install1:fresh');
    await Future<void>.delayed(Duration.zero);
    expect(tokens.saved['alice/install1']!['token'], 'install1:fresh');
  });

  test('a push that arrives in the foreground is shown', () async {
    await registrar.sync('alice');
    push.foregroundMessages.add(const PushMessage(title: 'Hi', body: 'Test'));
    await Future<void>.delayed(Duration.zero);
    expect(reminders.shown, [
      (id: PushRegistrar.foregroundNotificationId, title: 'Hi', body: 'Test'),
    ]);
  });

  test('signing out removes the token here and in Firebase', () async {
    await registrar.sync('alice');
    await registrar.release('alice');
    expect(tokens.saved, isEmpty);
    expect(push.deleted, 1);
  });

  test('a failure to save never throws', () async {
    tokens.failWith = StateError('offline');
    await registrar.sync('alice');
    await registrar.release('alice');
  });
}
