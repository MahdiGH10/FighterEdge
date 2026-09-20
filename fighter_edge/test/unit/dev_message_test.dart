import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/models/app_user.dart';
import 'package:fighter_edge/models/dev_message.dart';

void main() {
  group('DevMessage', () {
    test('parses a complete message', () {
      final message = DevMessage.fromJson({
        'id': 'pro-grant-1',
        'title': 'You have Pro',
        'body': 'Enjoy the AI brief.',
        'from': 'Dev Mahdi',
        'sentAt': '2026-09-20T10:00:00.000Z',
      });
      expect(message, isNotNull);
      expect(message!.id, 'pro-grant-1');
      expect(message.from, 'Dev Mahdi');
      expect(message.sentAt?.year, 2026);
    });

    test('accepts a millisecond timestamp, and tolerates a missing one', () {
      expect(
        DevMessage.fromJson({
          'id': 'a',
          'title': 't',
          'body': 'b',
          'from': 'f',
          'sentAt': 1758326400000,
        })?.sentAt,
        isNotNull,
      );
      expect(
        DevMessage.fromJson({'id': 'a', 'title': 't', 'body': 'b', 'from': 'f'})
            ?.sentAt,
        isNull,
      );
    });

    test('a malformed or empty message is dropped, never half-shown', () {
      expect(DevMessage.fromJson(null), isNull);
      expect(DevMessage.fromJson({}), isNull);
      expect(
          DevMessage.fromJson({'id': 'a', 'title': '', 'body': 'b'}), isNull);
      expect(DevMessage.fromJson({'title': 't', 'body': 'b'}), isNull);
    });

    test('survives an AppUser JSON round trip', () {
      final user = AppUser(
        id: 'u1',
        email: 'a@b.c',
        displayName: 'Fighter',
        plan: Plan.pro,
        createdAt: DateTime(2026, 9, 20),
        devMessage: const DevMessage(
          id: 'pro-grant-1',
          title: 'You have Pro',
          body: 'Enjoy.',
          from: 'Dev Mahdi',
        ),
      );
      final restored = AppUser.fromJson(user.toJson());
      expect(restored.devMessage?.id, 'pro-grant-1');
      expect(restored.isPro, isTrue);
    });
  });
}
