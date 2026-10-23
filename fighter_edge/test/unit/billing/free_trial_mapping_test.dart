import 'package:fighter_edge/billing/billing_gateway.dart';
import 'package:fighter_edge/billing/revenuecat_billing_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

rc.PricingPhase _phase({
  required int micros,
  rc.PeriodUnit unit = rc.PeriodUnit.week,
  int value = 1,
  int? cycles = 1,
}) =>
    rc.PricingPhase(
      rc.Period(unit, value, 'P$value'),
      rc.RecurrenceMode.finiteRecurring,
      cycles,
      rc.Price(micros == 0 ? 'Free' : r'$1.00', micros, 'USD'),
      rc.OfferPaymentMode.freeTrial,
    );

rc.SubscriptionOption _option({rc.PricingPhase? free}) => rc.SubscriptionOption(
      'monthly:trial',
      'monthly',
      'monthly',
      [if (free != null) free],
      const [],
      false,
      null,
      false,
      null,
      free,
      null,
      null,
      null,
    );

rc.StoreProduct _product({
  rc.IntroductoryPrice? intro,
  rc.SubscriptionOption? option,
}) =>
    rc.StoreProduct(
      'monthly',
      '',
      'Pro monthly',
      7.99,
      r'$7.99',
      'USD',
      introductoryPrice: intro,
      defaultOption: option,
    );

void main() {
  const eligible = rc.IntroEligibilityStatus.introEligibilityStatusEligible;

  group('Google Play free phase', () {
    test('a 1 week free phase on the default option is a 7 day trial', () {
      final product = _product(option: _option(free: _phase(micros: 0)));
      expect(
          freeTrialFromStoreProduct(product), const BillingFreeTrial(days: 7));
    });

    test('a 7 day free phase is 7 days', () {
      final product = _product(
        option: _option(
          free: _phase(micros: 0, unit: rc.PeriodUnit.day, value: 7),
        ),
      );
      expect(freeTrialFromStoreProduct(product)?.days, 7);
    });

    test('a default option with no free phase has no trial', () {
      expect(freeTrialFromStoreProduct(_product(option: _option())), isNull);
    });

    test('a paid first phase is not a free trial', () {
      final product = _product(option: _option(free: _phase(micros: 990000)));
      expect(freeTrialFromStoreProduct(product), isNull);
    });
  });

  group('App Store intro offer', () {
    const freeWeek =
        rc.IntroductoryPrice(0, r'$0.00', 'P1W', 1, rc.PeriodUnit.week, 1);

    test('a free intro offer counts only when the customer is eligible', () {
      final product = _product(intro: freeWeek);
      expect(
          freeTrialFromStoreProduct(product, eligibility: eligible)?.days, 7);
      for (final status in [
        rc.IntroEligibilityStatus.introEligibilityStatusIneligible,
        rc.IntroEligibilityStatus.introEligibilityStatusUnknown,
        rc.IntroEligibilityStatus.introEligibilityStatusNoIntroOfferExists,
        null,
      ]) {
        expect(freeTrialFromStoreProduct(product, eligibility: status), isNull,
            reason: 'status $status must not claim a trial');
      }
    });

    test('a paid intro price is not a free trial', () {
      const paid = rc.IntroductoryPrice(
          1.99, r'$1.99', 'P1M', 1, rc.PeriodUnit.month, 1);
      expect(
          freeTrialFromStoreProduct(_product(intro: paid),
              eligibility: eligible),
          isNull);
    });

    test('a product with no offer has no trial', () {
      expect(
          freeTrialFromStoreProduct(_product(), eligibility: eligible), isNull);
    });
  });
}
