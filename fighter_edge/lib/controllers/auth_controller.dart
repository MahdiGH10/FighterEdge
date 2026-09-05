import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/auth_repository.dart';
import '../auth/local_auth_repository.dart';
import '../billing/subscription.dart';
import '../models/app_user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// App-facing auth state. Wraps an [AuthRepository] and exposes status and the
/// current user to the widget tree via Provider.
class AuthController extends ChangeNotifier {
  final AuthRepository _repo;
  StreamSubscription<AppUser?>? _sub;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  bool _busy = false;

  AuthController(this._repo) {
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

  void _onUserChanged(AppUser? user) {
    _user = user;
    _status =
        user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
    notifyListeners();
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

  /// Starts the Pro purchase flow.
  ///
  /// This intentionally does not change the user's plan. Paid entitlements must
  /// be granted by a trusted billing backend, then refreshed here.
  Future<void> startProCheckout() => _run(() async {
        throw const AuthException(
          'billing-not-configured',
          'Payments are not active yet. Pro checkout will unlock after the store billing setup is connected.',
        );
      });

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
