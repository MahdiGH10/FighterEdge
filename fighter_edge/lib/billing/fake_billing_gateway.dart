import 'dart:async';

import 'billing_gateway.dart';

/// Deterministic billing adapter for widget/flow tests. It models the store
/// result but never changes the app's server-owned entitlement by itself.
class FakeBillingGateway implements BillingGateway {
  FakeBillingGateway({
    this.products = const [
      BillingProduct(
        id: 'fighter_edge_pro_monthly',
        period: BillingProductPeriod.monthly,
        priceString: r'$7.99',
        currencyCode: 'USD',
        price: 7.99,
      ),
      BillingProduct(
        id: 'fighter_edge_pro_annual',
        period: BillingProductPeriod.annual,
        priceString: r'$59.99',
        currencyCode: 'USD',
        price: 59.99,
      ),
    ],
    this.purchaseState = const BillingCustomerState(
      isPro: true,
      willRenew: true,
    ),
    this.restoreState = const BillingCustomerState.free(),
  });

  final List<BillingProduct> products;
  final BillingCustomerState purchaseState;
  final BillingCustomerState restoreState;
  bool configured = false;
  final _updates = StreamController<BillingCustomerState>.broadcast();

  /// Simulates the store telling the SDK about a change (e.g. a renewal).
  void emitCustomerInfo(BillingCustomerState state) => _updates.add(state);

  @override
  Stream<BillingCustomerState> get customerInfoUpdates => _updates.stream;
  int purchaseCount = 0;
  int restoreCount = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<void> configureForUser(String userId) async => configured = true;

  @override
  Future<List<BillingProduct>> loadProducts() async => products;

  @override
  Future<BillingCustomerState> purchase(BillingProduct product) async {
    purchaseCount++;
    return purchaseState;
  }

  @override
  Future<BillingCustomerState> restorePurchases() async {
    restoreCount++;
    return restoreState;
  }

  @override
  Future<BillingCustomerState> refreshCustomerInfo() async => restoreState;

  @override
  Future<void> logOut() async => configured = false;
}
