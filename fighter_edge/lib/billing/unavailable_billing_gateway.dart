import 'billing_gateway.dart';

/// Safe fallback used when a store key is not configured (tests, web preview,
/// and local development). It never grants Pro or pretends a purchase worked.
class UnavailableBillingGateway implements BillingGateway {
  const UnavailableBillingGateway();

  @override
  bool get isAvailable => false;

  @override
  Stream<BillingCustomerState> get customerInfoUpdates => const Stream.empty();

  @override
  Future<void> configureForUser(String userId) async {}

  @override
  Future<List<BillingProduct>> loadProducts() async => const [];

  @override
  Future<BillingCustomerState> purchase(BillingProduct product) {
    throw const BillingException(
      'billing-not-configured',
      'Payments are not active on this build yet.',
    );
  }

  @override
  Future<BillingCustomerState> restorePurchases() {
    throw const BillingException(
      'billing-not-configured',
      'Purchase restore is not active on this build yet.',
    );
  }

  @override
  Future<BillingCustomerState> refreshCustomerInfo() async =>
      const BillingCustomerState.free();

  @override
  Future<void> logOut() async {}
}
