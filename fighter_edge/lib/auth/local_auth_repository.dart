import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../billing/subscription.dart';
import '../models/app_user.dart';
import 'auth_repository.dart';

/// A fully working on-device auth backend used until Firebase is connected.
/// Accounts + session persist across restarts via SharedPreferences, so the
/// signup / login / logout / Pro-upgrade flows are real and testable today.
///
/// Social sign-in and magic links are simulated locally (no network). This
/// class is the reference implementation of [AuthRepository]; a
/// FirebaseAuthRepository implements the same interface for production.
class LocalAuthRepository implements AuthRepository {
  /// Opt in to acting like a backend that has email verification.
  ///
  /// Off by default so the simulated backend stays frictionless for dev work
  /// and so existing tests keep seeing verified accounts. Turn it on to
  /// exercise the verification screen and [VerificationGate] without Firebase:
  /// new email accounts then start unverified and only
  /// [debugMarkEmailVerified] clears them, standing in for the user clicking
  /// the link in their inbox.
  LocalAuthRepository({bool simulateEmailVerification = false})
      : _simulateEmailVerification = simulateEmailVerification;

  final bool _simulateEmailVerification;

  static const _accountsKey = 'fe_accounts';
  static const _sessionKey = 'fe_session_email';
  static const _salt = 'fighter_edge_v1';

  final _controller = StreamController<AppUser?>.broadcast();
  SharedPreferences? _prefs;
  AppUser? _current;

  /// The last simulated magic-link code (dev convenience so the UI can show
  /// "your code is ..." without a real email service).
  String? lastMagicCode;

  @override
  bool get supportsGoogle => true;

  @override
  bool get supportsApple => true;

  @override
  bool get supportsMagicLink => true;

  @override
  bool get supportsEmailVerification => _simulateEmailVerification;

  /// Must be called once at startup to restore any persisted session.
  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final email = _prefs!.getString(_sessionKey);
    if (email != null) {
      final account = _accounts()[email];
      if (account != null) {
        _current = AppUser.fromJson(account['user'] as Map<String, dynamic>);
      }
    }
    _controller.add(_current);
  }

  // ---- interface ----

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  AppUser? get currentUser => _current;

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final normalized = email.trim().toLowerCase();
    _validateEmail(normalized);
    if (password.length < 6) {
      throw const AuthException(
          'weak-password', 'Password must be at least 6 characters.');
    }
    final accounts = _accounts();
    if (accounts.containsKey(normalized)) {
      throw const AuthException(
          'email-already-in-use', 'An account with this email already exists.');
    }
    final user = AppUser(
      id: _newId(),
      email: normalized,
      displayName: displayName.trim().isEmpty
          ? normalized.split('@').first
          : displayName.trim(),
      plan: Plan.free,
      createdAt: DateTime.now(),
    );
    await _persistAccount(user, password);
    return _completeSignIn(user);
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    final account = _accounts()[normalized];
    if (account == null) {
      throw const AuthException(
          'user-not-found', 'No account found for this email.');
    }
    if (account['passwordHash'] != _hash(password)) {
      throw const AuthException('wrong-password', 'Incorrect password.');
    }
    return _completeSignIn(
        AppUser.fromJson(account['user'] as Map<String, dynamic>));
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    // Simulated: in production Firebase emails a reset link.
    debugPrint('[auth] password reset link sent to $email');
  }

  @override
  bool get canChangePassword {
    final current = _current;
    if (current == null) return false;
    final account = _accounts()[current.email] as Map<String, dynamic>?;
    return account?['passwordHash'] != null;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final current = _current;
    if (current == null) {
      throw const AuthException('signed-out', 'Sign in before changing it.');
    }
    final account = _accounts()[current.email] as Map<String, dynamic>?;
    if (account?['passwordHash'] != _hash(currentPassword)) {
      throw const AuthException(
        'wrong-password',
        'Your current password is incorrect.',
      );
    }
    await _persistAccount(current, newPassword);
  }

  @override
  Future<void> sendEmailVerification() async {
    // Simulated local backend: production Firebase sends the real email.
    debugPrint('[auth] verification email sent to ${_current?.email}');
  }

  @override
  Future<AppUser> signInWithGoogle() =>
      _signInSocial('google', 'Google Athlete');

  @override
  Future<AppUser> signInWithApple() => _signInSocial('apple', 'Apple Athlete');

  @override
  Future<void> sendMagicLink(String email) async {
    _validateEmail(email.trim().toLowerCase());
    // Deterministic 6-digit code from the email for the local simulation.
    final code = (email.hashCode.abs() % 900000 + 100000).toString();
    lastMagicCode = code;
    debugPrint('[auth] magic code for $email is $code');
  }

  @override
  Future<AppUser> verifyMagicCode({
    required String email,
    required String code,
  }) async {
    final normalized = email.trim().toLowerCase();
    final expected = (normalized.hashCode.abs() % 900000 + 100000).toString();
    if (code.trim() != expected) {
      throw const AuthException('invalid-code', 'That code is not correct.');
    }
    final existing = _accounts()[normalized];
    final user = existing != null
        ? AppUser.fromJson(existing['user'] as Map<String, dynamic>)
        : AppUser(
            id: _newId(),
            email: normalized,
            displayName: normalized.split('@').first,
            plan: Plan.free,
            createdAt: DateTime.now(),
            emailVerified: true,
          );
    if (existing == null) {
      await _persistAccount(user, null);
    }
    return _completeSignIn(user);
  }

  @override
  Future<void> signOut() async {
    _current = null;
    await _prefs?.remove(_sessionKey);
    _controller.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    final current = _current;
    if (current == null) {
      throw const AuthException('signed-out', 'Sign in before deleting.');
    }
    final accounts = _accounts();
    accounts.remove(current.email);
    await _prefs?.setString(_accountsKey, jsonEncode(accounts));
    _current = null;
    await _prefs?.remove(_sessionKey);
    _controller.add(null);
  }

  @override
  Future<AppUser?> refreshCurrentUser() async => _current;

  @override
  Future<AppUser> completeOnboarding({
    required String goal,
    required String experienceLevel,
    required int weeklyTrainingDays,
    required double? startingWeightKg,
  }) async {
    final current = _current;
    if (current == null) {
      throw const AuthException('signed-out', 'Sign in before setup.');
    }
    final user = current.copyWith(
      onboardingComplete: true,
      goal: goal,
      experienceLevel: experienceLevel,
      weeklyTrainingDays: weeklyTrainingDays,
      startingWeightKg: startingWeightKg,
    );
    await _persistAccount(user, null);
    return _completeSignIn(user);
  }

  /// Test/dev-only entitlement seeding. Production UI must never call this.
  Future<AppUser> debugSetPlan(Plan plan) async {
    final current = _current;
    if (current == null) {
      throw const AuthException('signed-out', 'Sign in before changing plan.');
    }
    final user = current.copyWith(plan: plan);
    await _persistAccount(user, null);
    _current = user;
    _controller.add(_current);
    return user;
  }

  /// Test/dev-only. Stands in for the user clicking the link in their inbox,
  /// so the verification screen's polling can be driven deterministically.
  Future<AppUser> debugMarkEmailVerified() async {
    final current = _current;
    if (current == null) {
      throw const AuthException('signed-out', 'Sign in before verifying.');
    }
    final user = current.copyWith(emailVerified: true);
    await _persistAccount(user, null);
    _current = user;
    _controller.add(_current);
    return user;
  }

  // ---- helpers ----

  Future<AppUser> _signInSocial(String provider, String name) async {
    final email = '$provider.athlete@fighteredge.app';
    final existing = _accounts()[email];
    final user = existing != null
        ? AppUser.fromJson(existing['user'] as Map<String, dynamic>)
        : AppUser(
            id: _newId(),
            email: email,
            displayName: name,
            plan: Plan.free,
            createdAt: DateTime.now(),
            emailVerified: true,
          );
    if (existing == null) {
      await _persistAccount(user, null);
    }
    return _completeSignIn(user);
  }

  Future<AppUser> _completeSignIn(AppUser user) async {
    _current = user;
    await _prefs?.setString(_sessionKey, user.email);
    _controller.add(user);
    return user;
  }

  Map<String, dynamic> _accounts() {
    final raw = _prefs?.getString(_accountsKey);
    if (raw == null || raw.isEmpty) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _persistAccount(AppUser user, String? password) async {
    final accounts = _accounts();
    final prior = accounts[user.email] as Map<String, dynamic>?;
    final passwordHash =
        password != null ? _hash(password) : prior?['passwordHash'];
    accounts[user.email] = {
      'passwordHash': passwordHash,
      'user': user.toJson(),
    };
    await _prefs?.setString(_accountsKey, jsonEncode(accounts));
  }

  String _hash(String password) =>
      sha256.convert(utf8.encode('$_salt:$password')).toString();

  void _validateEmail(String email) {
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!re.hasMatch(email)) {
      throw const AuthException(
          'invalid-email', 'Enter a valid email address.');
    }
  }

  String _newId() => 'local_${DateTime.now().microsecondsSinceEpoch}';

  void dispose() => _controller.close();
}
