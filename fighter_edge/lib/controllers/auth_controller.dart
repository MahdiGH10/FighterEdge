import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/auth_repository.dart';
import '../auth/local_auth_repository.dart';
import '../billing/subscription.dart';
import '../models/app_user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// App-facing auth state. Wraps an [AuthRepository] and exposes status +
/// the current user to the widget tree via Provider. All screens read this;
/// none of them know which backend is behind it.
class AuthController extends ChangeNotifier {
  final AuthRepository _repo;
  StreamSubscription<AppUser?>? _sub;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  bool _busy = false;

  AuthController(this._repo) {
    // Seed status synchronously from the current snapshot: a broadcast stream
    // won't replay the initial event emitted before we subscribe here.
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

  void _onUserChanged(AppUser? user) {
    _user = user;
    _status =
        user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
    notifyListeners();
  }

  /// Runs a side-effect auth action with busy-state management (no user change).
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

  /// Runs an action that returns the new signed-in user and applies it
  /// synchronously, so state is correct the moment the future resolves (the
  /// broadcast auth stream may deliver the same change a microtask later).
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

  Future<void> sendMagicLink(String email) =>
      _run(() => _repo.sendMagicLink(email));

  Future<void> verifyMagicCode(String email, String code) =>
      _apply(() => _repo.verifyMagicCode(email: email, code: code));

  Future<void> signOut() => _run(() async {
        await _repo.signOut();
        _onUserChanged(null);
      });

  /// Upgrade/downgrade the current user's plan.
  ///
  /// SECURITY: this is a CLIENT-side write, safe only for the current
  /// no-payments demo. Before shipping paid Pro, plan changes must be made
  /// server-side from a verified payment webhook (see docs/firebase_setup.md
  /// §5–6) and Firestore rules must forbid the client writing `plan`. Never
  /// trust a client-supplied plan for entitlement decisions that cost money.
  Future<void> setPlan(Plan plan) async {
    final u = _user;
    if (u == null) return;
    await _apply(() => _repo.updatePlan(u.copyWith(plan: plan)));
  }

  bool allows(Feature feature) => Entitlements.allows(plan, feature);

  /// DEV ONLY: with the local backend, returns the last simulated magic code
  /// so the passwordless flow is demoable without a real email service.
  /// Returns null under a real provider (e.g. Firebase).
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
