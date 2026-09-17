/// Provider-neutral subscription boundary.
///
/// The app can render a useful free plan and run tests without a store SDK.
/// Production billing is injected through [RevenueCatBillingGateway], while
/// the server remains the authority that grants `plan: pro`.
library;

enum BillingProductPeriod { monthly, annual }

class BillingProduct {
  final String id;
  final BillingProductPeriod period;
  final String priceString;
  final String currencyCode;
  final Object? providerHandle;

  const BillingProduct({
    required this.id,
    required this.period,
    required this.priceString,
    required this.currencyCode,
    this.providerHandle,
  });
}

class BillingCustomerState {
  final bool isPro;
  final DateTime? expiresAt;
  final bool willRenew;
  final String? managementUrl;

  const BillingCustomerState({
    required this.isPro,
    this.expiresAt,
    this.willRenew = false,
    this.managementUrl,
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

  Future<void> logOut();
}
