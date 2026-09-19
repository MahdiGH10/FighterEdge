import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/billing/subscription.dart';

void main() {
  group('Entitlements', () {
    test('every Pro feature is denied on the free plan', () {
      for (final f in Feature.values) {
        expect(Entitlements.allows(Plan.free, f), isFalse,
            reason: '${f.name} should be Pro-only');
        expect(Entitlements.isProOnly(f), isTrue);
      }
    });

    test('every feature is allowed on the Pro plan', () {
      for (final f in Feature.values) {
        expect(Entitlements.allows(Plan.pro, f), isTrue);
      }
    });
  });

  group('Plan / Feature labels', () {
    test('plans expose a display label', () {
      expect(Plan.free.label, 'Free');
      expect(Plan.pro.label, 'Pro');
    });

    test('every feature has paywall copy', () {
      for (final f in Feature.values) {
        expect(f.title, isNotEmpty);
        expect(f.pitch, isNotEmpty);
      }
    });
  });
}
