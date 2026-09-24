import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/models/app_user.dart';

void main() {
  AppUser sample() => AppUser(
        id: 'u1',
        email: 'a@b.com',
        displayName: 'Ayoub',
        plan: Plan.free,
        createdAt: DateTime.utc(2024, 1, 2, 3, 4, 5),
        emailVerified: true,
      );

  group('expiry-aware Pro (audit M-4)', () {
    final now = DateTime.utc(2026, 9, 24, 12);
    AppUser pro({DateTime? expires}) =>
        sample().copyWith(plan: Plan.pro, planExpiresAt: expires);

    test('a Pro plan with a future expiry is Pro', () {
      expect(
          pro(expires: now.add(const Duration(days: 30))).isProAt(now), isTrue);
    });

    test('just past expiry stays Pro within the renewal leeway', () {
      expect(
          pro(expires: now.subtract(const Duration(minutes: 5))).isProAt(now),
          isTrue);
    });

    test('past the leeway it is no longer Pro, even with plan: pro', () {
      final lapsed = pro(
          expires: now.subtract(
              Entitlements.expiryLeeway + const Duration(seconds: 1)));
      expect(lapsed.isProAt(now), isFalse);
    });

    test('no recorded expiry (lifetime or manual grant) stays Pro', () {
      expect(pro().isProAt(now), isTrue);
    });

    test('a free plan is never Pro, whatever the expiry', () {
      expect(
          sample()
              .copyWith(planExpiresAt: now.add(const Duration(days: 1)))
              .isProAt(now),
          isFalse);
    });
  });

  group('AppUser', () {
    test('isPro reflects the plan', () {
      expect(sample().isPro, isFalse);
      expect(sample().copyWith(plan: Plan.pro).isPro, isTrue);
    });

    test('copyWith changes only the given fields', () {
      final u = sample();
      final u2 = u.copyWith(displayName: 'Sam', plan: Plan.pro);
      expect(u2.id, u.id);
      expect(u2.email, u.email);
      expect(u2.displayName, 'Sam');
      expect(u2.plan, Plan.pro);
      expect(u2.createdAt, u.createdAt);
    });

    test('toJson / fromJson round-trips', () {
      final u = sample();
      final restored = AppUser.fromJson(u.toJson());
      expect(restored.id, u.id);
      expect(restored.email, u.email);
      expect(restored.displayName, u.displayName);
      expect(restored.plan, u.plan);
      expect(restored.emailVerified, u.emailVerified);
      expect(restored.createdAt, u.createdAt);
    });

    test('fromJson defaults missing/invalid fields safely', () {
      final u = AppUser.fromJson({
        'id': 'x',
        'email': 'x@y.com',
        // no displayName, unknown plan, bad date
        'plan': 'enterprise',
        'createdAt': 'not-a-date',
      });
      expect(u.displayName, '');
      expect(u.plan, Plan.free);
      expect(u.emailVerified, isFalse);
      expect(u.createdAt, isA<DateTime>());
    });
  });
}
