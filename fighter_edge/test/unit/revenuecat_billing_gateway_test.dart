import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

import 'package:fighter_edge/billing/revenuecat_billing_gateway.dart';

/// `PurchasesErrorHelper.getErrorCode` reads the numeric index straight off
/// `PlatformException.code` — no platform channel involved — so the mapping
/// in `translateRevenueCatError` is fully testable without mocking
/// `purchases_flutter` itself (audit M-8).
PlatformException _platformError(rc.PurchasesErrorCode code) =>
    PlatformException(
      code: rc.PurchasesErrorCode.values.indexOf(code).toString(),
      message: 'raw platform message nobody should see',
    );

void main() {
  test('a cancelled purchase gets its own quiet code', () {
    final result = translateRevenueCatError(
      _platformError(rc.PurchasesErrorCode.purchaseCancelledError),
      fallback: 'Purchase failed.',
    );
    expect(result.code, 'cancelled');
    expect(result.message, 'Purchase cancelled.');
  });

  for (final (code, expectedSubstring) in [
    (rc.PurchasesErrorCode.paymentPendingError, 'needs approval'),
    (rc.PurchasesErrorCode.productAlreadyPurchasedError, 'already own'),
    (rc.PurchasesErrorCode.storeProblemError, 'store had a problem'),
    (rc.PurchasesErrorCode.networkError, 'No connection'),
    (rc.PurchasesErrorCode.offlineConnectionError, 'No connection'),
  ]) {
    test('${code.name} gets a message worth showing, not the platform string',
        () {
      final result =
          translateRevenueCatError(_platformError(code), fallback: 'fallback');
      expect(result.code, code.name);
      expect(result.message, contains(expectedSubstring));
      expect(result.message, isNot(contains('nobody should see')));
    });
  }

  test('an unmapped code falls back to the caller-provided message', () {
    final result = translateRevenueCatError(
      _platformError(rc.PurchasesErrorCode.invalidCredentialsError),
      fallback: 'Restore failed.',
    );
    expect(result.code, 'invalidCredentialsError');
    expect(result.message, 'Restore failed.');
  });
}
