import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/auth_repository.dart';
import '../auth/local_auth_repository.dart';
import '../billing/subscription.dart';
import '../billing/billing_gateway.dart';
import '../billing/unavailable_billing_gateway.dart';
import '../models/app_user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// App-facing auth state. Wraps an [AuthRepository] and exposes status and the
/// current user to the widget tree via Provider.
class AuthController extends ChangeNotifier {
  final AuthRepository _repo;
  final BillingGateway _billing;
  StreamSubscription<AppUser?>? _sub;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  bool _busy = false;
  List<BillingProduct> _billingProducts = const [];
  BillingCustomerState _billingState = const BillingCustomerState.free();
  int _billingSession = 0;

  AuthController(this._repo, {BillingGateway? billingGateway})
      : _billing = billingGateway ?? const UnavailableBillingGateway() {
    // Seed status synchronously from the current snapshot: a broadcast stream
    // will not replay the initial event emitted before this subscription.
    _user = _repo.currentUser;
    _status =
        _user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
    _sub = _repo.authStateChanges().listen(_onUserChanged);
  }

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get isBusy => _busy;
  bool get isPro => _user?.isPro ?? false;
  Plan get plan => _user?.plan ?? Plan.free;
  bool get supportsGoogle => _repo.supportsGoogle;
  bool get supportsApple => _repo.supportsApple;
  bool get supportsMagicLink => _repo.supportsMagicLink;
  bool get supportsEmailVerification => _repo.supportsEmailVerification;
  bool get billingAvailable => _billing.isAvailable;
  List<BillingProduct> get billingProducts => _billingProducts;
  BillingCustomerState get billingState => _billingState;
  String? get billingManagementUrl => _billingState.managementUrl;

  void _onUserChanged(AppUser? user) {
    _user = user;
    _status =
        user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
    _billingProducts = const [];
    _billingState = const BillingCustomerState.free();
    notifyListeners();
    final session = ++_billingSession;
    unawaited(_syncBilling(user, session));
  }

  Future<void> _syncBilling(AppUser? user, int session) async {
    try {
      if (user == null) {
        await _billing.logOut();
        if (session != _billingSession) return;
        _billingProducts = const [];
        _billingState = const BillingCustomerState.free();
        return;
      }
      await _billing.configureForUser(user.id);
      if (session != _billingSession) return;
      if (!_billing.isAvailable) return;
      _billingProducts = await _billing.loadProducts();
      if (session != _billingSession) return;
      _billingState = await _billing.refreshCustomerInfo();
      if (session != _billingSession) return;
      notifyListeners();
    } catch (_) {
      // Billing is a secondary surface. A store outage must not block login or
      // make the app appear signed out; the next explicit restore can retry.
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _apply(Future<AppUser> Function() action) =>
      _run(() async => _onUserChanged(await action()));

  Future<void> signUp(String email, String password, String name) =>
      _apply(() => _repo.signUpWithEmail(
          email: email, password: password, displayName: name));

  Future<void> signIn(String email, String password) =>
      _apply(() => _repo.signInWithEmail(email: email, password: password));

  Future<void> signInWithGoogle() => _apply(_repo.signInWithGoogle);

  Future<void> signInWithApple() => _apply(_repo.signInWithApple);

  Future<void> sendPasswordReset(String email) =>
      _run(() => _repo.sendPasswordReset(email));

  Future<void> sendEmailVerification() =>
      _run(() => _repo.sendEmailVerification());

  Future<void> sendMagicLink(String email) =>
      _run(() => _repo.sendMagicLink(email));

  Future<void> verifyMagicCode(String email, String code) =>
      _apply(() => _repo.verifyMagicCode(email: email, code: code));

  Future<void> signOut() => _run(() async {
        await _repo.signOut();
        _onUserChanged(null);
      });

  /// Permanently deletes the account and all of its data. Irreversible.
  Future<void> deleteAccount() => _run(() async {
        await _repo.deleteAccount();
        _onUserChanged(null);
      });

  /// Starts a store purchase. The store result is never converted directly
  /// into Pro; the RevenueCat webhook must update Firestore first.
  Future<void> startProCheckout([BillingProduct? product]) => _run(() async {
        try {
          final selected = product ??
              (_billingProducts.isNotEmpty ? _billingProducts.first : null);
          if (selected == null) {
            throw const BillingException(
              'billing-not-configured',
              'Payments are not active yet. Connect the store products before purchasing.',
            );
          }
          _billingState = await _billing.purchase(selected);
          notifyListeners();
          await _refreshServerEntitlement();
        } on BillingException catch (e) {
          throw AuthException(e.code, e.message);
        } catch (_) {
          throw const AuthException(
            'billing-failed',
            'The store could not complete that purchase. Please try again.',
          );
        }
      });

  Future<void> restorePurchases() => _run(() async {
        try {
          _billingState = await _billing.restorePurchases();
          notifyListeners();
          await _refreshServerEntitlement();
        } on BillingException catch (e) {
          throw AuthException(e.code, e.message);
        } catch (_) {
          throw const AuthException(
            'billing-failed',
            'The store could not restore purchases. Please try again.',
          );
        }
      });

  Future<void> loadBillingProducts() => _run(() async {
        try {
          if (_user == null || !_billing.isAvailable) return;
          await _billing.configureForUser(_user!.id);
          _billingProducts = await _billing.loadProducts();
          _billingState = await _billing.refreshCustomerInfo();
          notifyListeners();
        } catch (_) {
          _billingProducts = const [];
          _billingState = const BillingCustomerState.free();
          notifyListeners();
        }
      });

  Future<void> _refreshServerEntitlement() async {
    // Webhook delivery is asynchronous. Bounded polling improves activation
    // latency without turning the client into an entitlement authority.
    for (var attempt = 0; attempt < 3; attempt++) {
      final refreshed = await _repo.refreshCurrentUser();
      _user = refreshed;
      _status = refreshed == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
      notifyListeners();
      if (refreshed?.isPro == true) return;
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
    }
  }

  Future<void> refreshCurrentUser() => _run(() async {
        _onUserChanged(await _repo.refreshCurrentUser());
      });

  Future<void> completeOnboarding({
    required String goal,
    required String experienceLevel,
    required int weeklyTrainingDays,
    required double? startingWeightKg,
  }) =>
      _apply(() => _repo.completeOnboarding(
            goal: goal,
            experienceLevel: experienceLevel,
            weeklyTrainingDays: weeklyTrainingDays,
            startingWeightKg: startingWeightKg,
          ));

  bool allows(Feature feature) => Entitlements.allows(plan, feature);

  /// DEV ONLY: with the local backend, returns the last simulated magic code so
  /// the passwordless flow is demoable without a real email service.
  String? get devMagicHint {
    final r = _repo;
    return r is LocalAuthRepository ? r.lastMagicCode : null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
