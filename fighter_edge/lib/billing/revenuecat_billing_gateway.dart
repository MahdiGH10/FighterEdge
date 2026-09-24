import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

import 'billing_gateway.dart';

/// Maps a RevenueCat error into user-facing copy (audit M-8). Only
/// `purchaseCancelledError` needs a distinct code today (the paywall treats
/// a cancel as "say nothing"); everything else keeps the raw platform code
/// but gets a message worth showing someone, with a retry or restore
/// suggestion where one applies, instead of the developer-facing platform
/// string. A top-level function, not a gateway method, so the mapping is
/// testable without mocking the `purchases_flutter` platform channel —
/// `PurchasesErrorHelper.getErrorCode` only parses `error.code`.
BillingException translateRevenueCatError(
  PlatformException error, {
  required String fallback,
}) {
  final code = rc.PurchasesErrorHelper.getErrorCode(error);
  if (code == rc.PurchasesErrorCode.purchaseCancelledError) {
    return const BillingException('cancelled', 'Purchase cancelled.');
  }
  final message = switch (code) {
    rc.PurchasesErrorCode.paymentPendingError =>
      "Your payment needs approval (parental controls, bank authorization) "
          "before it can complete. We'll unlock Pro once it clears.",
    rc.PurchasesErrorCode.productAlreadyPurchasedError =>
      'You already own this subscription. Try Restore Purchases instead.',
    rc.PurchasesErrorCode.storeProblemError =>
      'The store had a problem completing this. Please try again in a moment.',
    rc.PurchasesErrorCode.networkError ||
    rc.PurchasesErrorCode.offlineConnectionError =>
      'No connection to the store. Check your connection and try again.',
    _ => null,
  };
  return BillingException(code.name, message ?? fallback);
}

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
      throw translateRevenueCatError(error, fallback: 'Purchase failed.');
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
    try {
      return _stateFrom(await rc.Purchases.restorePurchases());
    } on PlatformException catch (error) {
      throw translateRevenueCatError(error, fallback: 'Restore failed.');
    }
  }

  @override
  Future<BillingCustomerState> refreshCustomerInfo() async {
    if (!isAvailable || !_configured) return const BillingCustomerState.free();
    return _stateFrom(await rc.Purchases.getCustomerInfo());
  }

  @override
  Future<void> logOut() async {
    if (_configured) {
      try {
        await rc.Purchases.logOut();
      } on PlatformException catch (error) {
        // Two sign-out events in a row, or a session that never actually
        // logged in to the store: RevenueCat already considers the current
        // user anonymous, so there is nothing left to undo (audit M-8).
        final code = rc.PurchasesErrorHelper.getErrorCode(error);
        if (code != rc.PurchasesErrorCode.logOutWithAnonymousUserError) {
          rethrow;
        }
      }
    }
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
