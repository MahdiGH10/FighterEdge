import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/models/app_user.dart';
import 'package:fighter_edge/privacy/data_consent.dart';

void main() {
  group('DataConsents', () {
    test('nothing is granted by default', () {
      for (final purpose in DataConsentPurpose.values) {
        expect(DataConsents.none.allows(purpose), isFalse);
      }
    });

    test('reads the profile map the app and server share', () {
      final at = DateTime.utc(2026, 9, 24, 12);
      final consents = DataConsents.fromProfile({
        'healthData': {'version': 1, 'grantedAt': at.millisecondsSinceEpoch},
        'aiCoach': const {'version': 1, 'grantedAt': null},
      });

      expect(consents.allows(DataConsentPurpose.healthData), isTrue);
      expect(consents.allows(DataConsentPurpose.aiCoach), isTrue);
      expect(
        consents.recordFor(DataConsentPurpose.healthData)?.grantedAt,
        at.toLocal(),
      );
      expect(
        consents.recordFor(DataConsentPurpose.aiCoach)?.grantedAt,
        isNull,
        reason: 'a pending server timestamp still counts as consent',
      );
    });

    test('an older wording is asked again', () {
      final consents = DataConsents.fromProfile({
        'healthData': {
          'version': DataConsentPurpose.healthData.currentVersion - 1,
        },
      });
      expect(consents.allows(DataConsentPurpose.healthData), isFalse);
    });

    test('malformed entries read as not granted', () {
      expect(DataConsents.fromProfile('yes'), DataConsents.none);
      final consents = DataConsents.fromProfile(const {
        'healthData': true,
        'aiCoach': {'version': '1'},
        'marketing': {'version': 9},
      });
      expect(consents, DataConsents.none);
    });

    test('uses the backend date reader when one is given', () {
      final at = DateTime.utc(2026, 1, 2);
      final consents = DataConsents.fromProfile(
        const {
          'healthData': {'version': 1, 'grantedAt': _FakeTimestamp()},
        },
        readDate: (value) => value is _FakeTimestamp ? at : null,
      );
      expect(consents.recordFor(DataConsentPurpose.healthData)?.grantedAt, at);
    });

    test('grant and withdraw are per purpose', () {
      final granted = DataConsents.none
          .granted(DataConsentPurpose.healthData)
          .granted(DataConsentPurpose.aiCoach);
      final withdrawn = granted.withdrawn(DataConsentPurpose.aiCoach);

      expect(withdrawn.allows(DataConsentPurpose.healthData), isTrue);
      expect(withdrawn.allows(DataConsentPurpose.aiCoach), isFalse);
    });

    test('round-trips through the local account store', () {
      final at = DateTime.utc(2026, 9, 24);
      final consents = DataConsents.allCurrent(at: at);
      final restored = DataConsents.fromProfile(consents.toJson());

      expect(restored, consents);
      expect(
        restored.recordFor(DataConsentPurpose.aiCoach)?.grantedAt,
        at.toLocal(),
      );
    });
  });

  group('AppUser consents', () {
    final base = AppUser(
      id: 'u1',
      email: 'u1@example.test',
      displayName: 'U',
      plan: Plan.free,
      createdAt: DateTime.utc(2026),
    );

    test('a new account holds no consent', () {
      expect(base.hasHealthDataConsent, isFalse);
      expect(base.hasAiCoachConsent, isFalse);
    });

    test('copyWith and JSON keep consents', () {
      final user = base.copyWith(
        consents: DataConsents.none.granted(DataConsentPurpose.healthData),
      );
      expect(user.hasHealthDataConsent, isTrue);
      expect(user.hasAiCoachConsent, isFalse);

      final restored = AppUser.fromJson(user.toJson());
      expect(restored.hasHealthDataConsent, isTrue);
      expect(restored.hasAiCoachConsent, isFalse);
    });
  });
}

class _FakeTimestamp {
  const _FakeTimestamp();
}
