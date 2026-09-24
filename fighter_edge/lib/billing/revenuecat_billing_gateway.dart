import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

import 'billing_gateway.dart';

/// RevenueCat adapter. Public store keys are intentionally supplied through
/// `--dart-define`; no secret or entitlement decision lives in the client.
class RevenueCatBillingGateway implements BillingGateway {
  RevenueCatBillingGateway({
    String? androidApiKey,
    String? iosApiKey,
  })  : _androidApiKey = androidApiKey ??
            const String.fromEnvironment('REVENUECAT_ANDROID_PUBLIC_KEY'),
        _iosApiKey = iosApiKey ??
            const String.fromEnvironment('REVENUECAT_IOS_PUBLIC_KEY');

  final String _androidApiKey;
  final String _iosApiKey;
  final Map<String, rc.Package> _packages = {};
  bool _configured = false;
  final _updates = StreamController<BillingCustomerState>.broadcast();

  @override
  Stream<BillingCustomerState> get customerInfoUpdates => _updates.stream;

  @override
  bool get isAvailable => !kIsWeb && _apiKeyForPlatform.isNotEmpty;

  String get _apiKeyForPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) return _androidApiKey;
    if (defaultTargetPlatform == TargetPlatform.iOS) return _iosApiKey;
    return '';
  }

  @override
  Future<void> configureForUser(String userId) async {
    if (!isAvailable) return;
    if (!_configured) {
      await rc.Purchases.configure(
        rc.PurchasesConfiguration(_apiKeyForPlatform)..appUserID = userId,
      );
      rc.Purchases.addCustomerInfoUpdateListener(
        (info) => _updates.add(_stateFrom(info)),
      );
      _configured = true;
      return;
    }
    final current = await rc.Purchases.appUserID;
    if (current != userId) await rc.Purchases.logIn(userId);
  }

  @override
  Future<List<BillingProduct>> loadProducts() async {
    if (!isAvailable || !_configured) return const [];
    final offerings = await rc.Purchases.getOfferings();
    final current = offerings.current;
    if (current == null) return const [];

    final products = <BillingProduct>[];
    for (final package in current.availablePackages) {
      final period = switch (package.packageType) {
        rc.PackageType.monthly => BillingProductPeriod.monthly,
        rc.PackageType.annual => BillingProductPeriod.annual,
        _ => null,
      };
      if (period == null) continue;
      _packages[package.identifier] = package;
      products.add(BillingProduct(
        id: package.identifier,
        period: period,
        priceString: package.storeProduct.priceString,
        currencyCode: package.storeProduct.currencyCode,
        price: package.storeProduct.price,
        providerHandle: package,
      ));
    }
    return products;
  }

  @override
  Future<BillingCustomerState> purchase(BillingProduct product) async {
    if (!isAvailable || !_configured) {
      throw const BillingException(
        'billing-not-configured',
        'Payments are not active on this build yet.',
      );
    }
    final package = product.providerHandle is rc.Package
        ? product.providerHandle! as rc.Package
        : _packages[product.id];
    if (package == null) {
      throw const BillingException(
        'product-unavailable',
        'That subscription option is not available right now.',
      );
    }
    try {
      final result = await rc.Purchases.purchase(
        rc.PurchaseParams.package(package),
      );
      return _stateFrom(result.customerInfo);
    } on PlatformException catch (error) {
      final code = rc.PurchasesErrorHelper.getErrorCode(error);
      if (code == rc.PurchasesErrorCode.purchaseCancelledError) {
        throw const BillingException('cancelled', 'Purchase cancelled.');
      }
      throw BillingException(
          'purchase-failed', error.message ?? 'Purchase failed.');
    }
  }

  @override
  Future<BillingCustomerState> restorePurchases() async {
    if (!isAvailable || !_configured) {
      throw const BillingException(
        'billing-not-configured',
        'Purchase restore is not active on this build yet.',
      );
    }
    return _stateFrom(await rc.Purchases.restorePurchases());
  }

  @override
  Future<BillingCustomerState> refreshCustomerInfo() async {
    if (!isAvailable || !_configured) return const BillingCustomerState.free();
    return _stateFrom(await rc.Purchases.getCustomerInfo());
  }

  @override
  Future<void> logOut() async {
    if (_configured) await rc.Purchases.logOut();
    _packages.clear();
  }

  BillingCustomerState _stateFrom(rc.CustomerInfo info) {
    final entitlement = info.entitlements.active['pro'];
    return BillingCustomerState(
      isPro: entitlement?.isActive == true,
      expiresAt: DateTime.tryParse(entitlement?.expirationDate ?? ''),
      willRenew: entitlement?.willRenew ?? false,
      managementUrl: info.managementURL,
    );
  }
}
