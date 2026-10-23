import 'package:fighter_edge/billing/subscription.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 20, 12);

AccessState _derive({
  Plan plan = Plan.pro,
  DateTime? expiresAt,
  ProPeriod? period,
  bool confirmed = true,
  AccessState? lastKnown,
}) =>
    AccessState.derive(
      plan: plan,
      now: _now,
      expiresAt: expiresAt,
      period: period,
      confirmed: confirmed,
      lastKnown: lastKnown,
    );

void main() {
  group('AccessState.derive (server-fed entitlement only)', () {
    test('a free plan is read-only, never trial or active', () {
      final state = _derive(plan: Plan.free);
      expect(state.kind, AccessKind.readOnly);
      expect(state.canWrite, isFalse);
      expect(state.hasPaidAccess, isFalse);
    });

    test(
        'a free plan stays read-only even with a trial period and future '
        'expiry on the profile', () {
      // Only plan == pro grants anything; the period alone is not access.
      final state = _derive(
        plan: Plan.free,
        expiresAt: _now.add(const Duration(days: 3)),
        period: ProPeriod.trial,
      );
      expect(state.isReadOnly, isTrue);
    });

    test('Pro + TRIAL + future expiry is a trial that ends at the expiry', () {
      final ends = _now.add(const Duration(days: 7));
      final state = _derive(expiresAt: ends, period: ProPeriod.trial);
      expect(state.isTrial, isTrue);
      expect(state.trialEndsAt, ends);
      expect(state.canWrite, isTrue);
      expect(state.hasPaidAccess, isTrue);
    });

    test('Pro + NORMAL, INTRO or an unknown period is active', () {
      final ends = _now.add(const Duration(days: 30));
      for (final period in [ProPeriod.normal, ProPeriod.intro, null]) {
        expect(_derive(expiresAt: ends, period: period).isActive, isTrue,
            reason: '$period');
      }
    });

    test('a trial with no recorded expiry cannot be dated, so it is active',
        () {
      expect(_derive(period: ProPeriod.trial).isActive, isTrue);
    });

    test('Pro with no expiry (lifetime or manual grant) is active', () {
      expect(_derive().isActive, isTrue);
    });

    test('expiry is honoured with the server leeway', () {
      final justExpired = _now.subtract(const Duration(minutes: 1));
      expect(_derive(expiresAt: justExpired).isActive, isTrue,
          reason: 'inside the 1 hour renewal-lag leeway');
      final longGone = _now.subtract(Entitlements.expiryLeeway);
      expect(_derive(expiresAt: longGone).isReadOnly, isTrue,
          reason: 'a missed EXPIRATION webhook cannot keep access on');
    });

    test('a lapsed trial is read-only', () {
      final state = _derive(
        expiresAt: _now.subtract(const Duration(days: 2)),
        period: ProPeriod.trial,
      );
      expect(state.isReadOnly, isTrue);
    });
  });

  group('unknown and the last cached state', () {
    test('an unconfirmed profile is unknown, carrying the last known state',
        () {
      const last = AccessState.active();
      final state = _derive(
        plan: Plan.free, // the placeholder default must not matter
        confirmed: false,
        lastKnown: last,
      );
      expect(state.isUnknown, isTrue);
      expect(state.lastKnown, last);
      expect(state.effective, last);
      expect(state.hasPaidAccess, isTrue);
      expect(state.canWrite, isTrue);
    });

    test('unknown over a read-only last state stays read-only', () {
      const state = AccessState.unknown(lastKnown: AccessState.readOnly());
      expect(state.canWrite, isFalse);
      expect(state.hasPaidAccess, isFalse);
    });

    test(
        'unknown with nothing cached never unlocks paid features but does '
        'not block the athlete from logging their own data', () {
      const state = AccessState.unknown();
      expect(state.effective, isNull);
      expect(state.hasPaidAccess, isFalse);
      expect(state.canWrite, isTrue);
    });

    test('unknown over a trial keeps counting the trial days', () {
      final ends = _now.add(const Duration(days: 2));
      final state = AccessState.unknown(lastKnown: AccessState.trial(ends));
      expect(state.trialDaysLeft(_now), 2);
    });
  });

  group('trialDaysLeft', () {
    test('rounds up and never goes negative; null outside a trial', () {
      final ends = _now.add(const Duration(days: 7));
      final trial = AccessState.trial(ends);
      expect(trial.trialDaysLeft(_now), 7);
      expect(trial.trialDaysLeft(_now.add(const Duration(hours: 1))), 7);
      expect(
          trial.trialDaysLeft(_now.add(const Duration(days: 6, hours: 1))), 1);
      expect(trial.trialDaysLeft(ends), 0);
      expect(trial.trialDaysLeft(ends.add(const Duration(days: 3))), 0);
      expect(const AccessState.active().trialDaysLeft(_now), isNull);
      expect(const AccessState.readOnly().trialDaysLeft(_now), isNull);
    });
  });

  group('value semantics', () {
    test('equal states compare equal', () {
      final ends = _now.add(const Duration(days: 1));
      expect(AccessState.trial(ends), AccessState.trial(ends));
      expect(const AccessState.active(), const AccessState.active());
      expect(const AccessState.active(), isNot(const AccessState.readOnly()));
    });
  });

  group('ProPeriod parsing', () {
    test('maps the webhook codes and rejects everything else', () {
      expect(ProPeriodParsing.fromServer('TRIAL'), ProPeriod.trial);
      expect(ProPeriodParsing.fromServer('INTRO'), ProPeriod.intro);
      expect(ProPeriodParsing.fromServer('NORMAL'), ProPeriod.normal);
      for (final bad in ['trial', 'PROMOTIONAL', '', 3, null]) {
        expect(ProPeriodParsing.fromServer(bad), isNull, reason: '$bad');
      }
    });
  });

  group('features follow access', () {
    test('every feature, corner cues included, needs trial or paid access', () {
      final trial = AccessState.trial(_now.add(const Duration(days: 1)));
      for (final feature in Feature.values) {
        expect(Entitlements.isProOnly(feature), isTrue);
        expect(Entitlements.allowsAccess(trial, feature), isTrue);
        expect(Entitlements.allowsAccess(const AccessState.active(), feature),
            isTrue);
        expect(Entitlements.allowsAccess(const AccessState.readOnly(), feature),
            isFalse);
        expect(Entitlements.allowsAccess(const AccessState.unknown(), feature),
            isFalse);
      }
    });

    test('the plan-based helper still compiles and agrees', () {
      expect(Entitlements.allows(Plan.pro, Feature.cornerCoach), isTrue);
      expect(Entitlements.allows(Plan.free, Feature.cornerCoach), isFalse);
    });
  });
}
