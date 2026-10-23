/// Provider-neutral subscription boundary.
///
/// The app can render a useful free plan and run tests without a store SDK.
/// Production billing is injected through [RevenueCatBillingGateway], while
/// the server remains the authority that grants `plan: pro`.
library;

enum BillingProductPeriod { monthly, annual }

/// A free trial the store itself offers for a product, as the store reports
/// it for this customer. The paywall may only mention a trial when this is
/// non-null, so eligibility and wording always come from the store.
class BillingFreeTrial {
  /// Trial length in whole days (a store "1 week" trial is 7).
  final int days;

  const BillingFreeTrial({required this.days}) : assert(days > 0);

  @override
  bool operator ==(Object other) =>
      other is BillingFreeTrial && other.days == days;

  @override
  int get hashCode => days.hashCode;

  @override
  String toString() => 'BillingFreeTrial($days days)';
}

class BillingProduct {
  final String id;
  final BillingProductPeriod period;
  final String priceString;
  final String currencyCode;

  /// The numeric store price when the provider exposes it. Keeping this
  /// optional preserves support for providers that only return a localized
  /// display string, while allowing the paywall to show an honest annual
  /// monthly-equivalent label when the value is available.
  final double? price;
  final Object? providerHandle;

  /// The store's free-trial offer for this customer, or null when there is
  /// none or the customer is not eligible (e.g. already used it).
  final BillingFreeTrial? freeTrial;

  const BillingProduct({
    required this.id,
    required this.period,
    required this.priceString,
    required this.currencyCode,
    this.price,
    this.providerHandle,
    this.freeTrial,
  });
}

class BillingCustomerState {
  final bool isPro;
  final DateTime? expiresAt;
  final bool willRenew;
  final String? managementUrl;

  /// The store reports the active entitlement as a free trial. Display and
  /// telemetry only; access still comes from the server.
  final bool inTrial;

  const BillingCustomerState({
    required this.isPro,
    this.expiresAt,
    this.willRenew = false,
    this.managementUrl,
    this.inTrial = false,
  });

  const BillingCustomerState.free() : this(isPro: false);
}

class BillingException implements Exception {
  final String code;
  final String message;

  const BillingException(this.code, this.message);

  @override
  String toString() => message;
}

abstract interface class BillingGateway {
  bool get isAvailable;

  Future<void> configureForUser(String userId);

  Future<List<BillingProduct>> loadProducts();

  Future<BillingCustomerState> purchase(BillingProduct product);

  Future<BillingCustomerState> restorePurchases();

  Future<BillingCustomerState> refreshCustomerInfo();

  /// Store-side subscription changes the SDK learns about on its own: a
  /// renewal, an approved Ask to Buy, a pending payment completing. Display
  /// only. The server stays the entitlement authority.
  Stream<BillingCustomerState> get customerInfoUpdates;

  Future<void> logOut();
}
