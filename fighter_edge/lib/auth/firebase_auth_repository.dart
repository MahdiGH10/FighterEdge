import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../billing/subscription.dart';
import '../models/app_user.dart';
import '../models/dev_message.dart';
import '../privacy/data_consent.dart';
import 'auth_repository.dart';

/// Production auth backend built on Firebase Auth + Cloud Firestore.
/// Implements the same [AuthRepository] the whole app depends on, so switching
/// from [LocalAuthRepository] is a one-line change in `main.dart`.
///
/// - Email/password, Google and Apple are handled by Firebase Auth.
/// - Each user's profile + plan live in `users/{uid}` in Firestore. Firestore
///   reads are best-effort: if the database isn't set up yet, auth still works
///   and the user defaults to the free plan.
class FirebaseAuthRepository implements AuthRepository {
  /// The Firebase singletons in production. Tests pass in-memory doubles, so
  /// the adapter itself is exercised rather than only the controllers above
  /// it.
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    bool? appleSignInEnabled,
    TargetPlatform? platform,
    bool? isWeb,
    FirebaseFunctions Function()? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? (() => FirebaseFunctions.instance),
        _db = firestore ?? FirebaseFirestore.instance,
        _appleSignInEnabled = appleSignInEnabled ??
            const bool.fromEnvironment('ENABLE_APPLE_SIGN_IN'),
        _platform = platform ?? defaultTargetPlatform,
        _isWeb = isWeb ?? kIsWeb;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseFunctions Function() _functions;

  /// Sign in with Apple needs an Apple Developer service ID and the Firebase
  /// Apple provider, which are account setup, not code. Until a build is
  /// made with `--dart-define=ENABLE_APPLE_SIGN_IN=true` it stays hidden.
  final bool _appleSignInEnabled;
  final TargetPlatform _platform;
  final bool _isWeb;

  AppUser? _cached;

  bool get _isIos => !_isWeb && _platform == TargetPlatform.iOS;

  /// App Review Guideline 4.8: an iOS app that offers a third-party login must
  /// also offer Sign in with Apple. Google is therefore shown on iOS only
  /// when Apple is available alongside it.
  @override
  bool get supportsGoogle => !_isIos || supportsApple;

  @override
  bool get supportsApple => _appleSignInEnabled;

  @override
  bool get supportsMagicLink => false;

  @override
  bool get supportsEmailVerification => true;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Future<void> init() async {
    // Wait for Firebase to restore any persisted session, then hydrate it so
    // AuthController can seed its status synchronously (no login-screen flash).
    final user = await _auth.authStateChanges().first;
    if (user != null) _cached = await _hydrate(user);
  }

  /// The signed-in user, re-emitted whenever their `users/{uid}` profile
  /// changes on the server. A webhook granting, renewing or revoking Pro
  /// therefore reaches the app at once. Before this, the plan was read once
  /// per session, so buyers sat on "pending" and expirations only landed on
  /// the next launch (audit M-3).
  @override
  Stream<AppUser?> authStateChanges() {
    StreamSubscription<User?>? authSub;
    StreamSubscription<Object?>? profileSub;
    late final StreamController<AppUser?> controller;
    controller = StreamController<AppUser?>(
      onListen: () {
        authSub = _auth.authStateChanges().listen(
          (user) {
            unawaited(profileSub?.cancel());
            profileSub = null;
            if (user == null) {
              _cached = null;
              controller.add(null);
              return;
            }
            profileSub = _followProfile(user, controller.add);
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await profileSub?.cancel();
        await authSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Follows one account's profile document. Errors (offline with no cache,
  /// a permission race while signing out) are not fatal: the last known
  /// state stays, and if nothing was known yet the account continues as
  /// free, exactly as the one-shot read used to.
  ///
  /// A plain subscription rather than an `async*` generator: a generator
  /// only notices cancellation at its next event, so it kept the Firestore
  /// listener open after sign-out and could still overwrite [_cached] with
  /// the previous account when a late snapshot arrived.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> _followProfile(
    User user,
    void Function(AppUser user) emit,
  ) {
    var emitted = false;
    var seeded = false;
    return _doc(user.uid).snapshots().listen(
      (snap) {
        if (!snap.exists && !seeded && !snap.metadata.isFromCache) {
          seeded = true;
          unawaited(_seedProfile(user).catchError((Object _) {}));
        }
        emitted = true;
        emit(_remember(_appUserFrom(user, snap.data() ?? const {})));
      },
      onError: (Object error) {
        if (kDebugMode) debugPrint('[auth] profile listener error: $error');
      },
      onDone: () {
        if (!emitted) emit(_remember(_appUserFrom(user, const {})));
      },
    );
  }

  AppUser _remember(AppUser user) => _cached = user;

  Future<void> _seedProfile(User user) => _doc(user.uid).set({
        'email': user.email,
        'displayName': user.displayName,
        'plan': Plan.free.name,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  @override
  AppUser? get currentUser => _cached;

  /// Map a Firebase [User] to our [AppUser], reading (or seeding) the plan in
  /// Firestore. Falls back to a free-plan user if Firestore is unavailable.
  Future<AppUser> _hydrate(User user) async {
    Map<String, dynamic> profileData = const {};
    try {
      final snap = await _doc(user.uid).get();
      if (snap.exists) {
        profileData = snap.data() ?? const {};
      } else {
        await _seedProfile(user);
      }
    } catch (e) {
      // Debug only: Firestore errors can name the `users/{uid}` path, and
      // debugPrint is not stripped from release builds.
      if (kDebugMode) {
        debugPrint('[auth] Firestore unavailable, defaulting to free plan: $e');
      }
    }
    return _remember(_appUserFrom(user, profileData));
  }

  /// Builds the app's user from the auth account and its profile document.
  AppUser _appUserFrom(User user, Map<String, dynamic> profileData) {
    final billingData = Map<String, dynamic>.from(
      (profileData['billing'] as Map?) ?? const <String, dynamic>{},
    );
    final plan = Plan.values.firstWhere(
      (p) => p.name == profileData['plan'],
      orElse: () => Plan.free,
    );
    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      displayName:
          user.displayName ?? (user.email?.split('@').first ?? 'Fighter'),
      emailVerified: user.emailVerified,
      plan: plan,
      planExpiresAt: _parseBillingDate(billingData['expiresAtMs']),
      planWillRenew: (billingData['willRenew'] as bool?) ?? false,
      billingProvider: billingData['provider'] as String?,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      onboardingComplete: (profileData['onboardingComplete'] as bool?) ?? false,
      goal: (profileData['goal'] as String?) ?? '',
      experienceLevel: (profileData['experienceLevel'] as String?) ?? '',
      weeklyTrainingDays:
          (profileData['weeklyTrainingDays'] as num?)?.toInt() ?? 4,
      startingWeightKg: (profileData['startingWeightKg'] as num?)?.toDouble(),
      devMessage: DevMessage.fromJson(
        (profileData['devMessage'] as Map?)?.cast<String, dynamic>(),
      ),
      consents: DataConsents.fromProfile(
        profileData['consents'],
        readDate: (value) => value is Timestamp ? value.toDate() : null,
      ),
    );
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      if (displayName.trim().isNotEmpty) {
        await user.updateDisplayName(displayName.trim());
        await user.reload();
      }
      unawaited(user.sendEmailVerification().catchError((_) {}));
      return await _hydrate(_auth.currentUser ?? user);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code, _message(e));
    }
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return await _hydrate(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code, _message(e));
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code, _message(e));
    }
  }

  @override
  bool get canChangePassword =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == EmailAuthProvider.PROVIDER_ID) ??
      false;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthException('signed-out', 'Sign in before changing it.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: currentPassword),
      );
    } on FirebaseAuthException catch (e) {
      // At this step a credential failure can only mean the current password
      // was wrong — the email is the account's own.
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw const AuthException(
          'wrong-password',
          'Your current password is incorrect.',
        );
      }
      throw AuthException(e.code, _message(e));
    }
    try {
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code, _message(e));
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException(
        'signed-out',
        'Sign in before requesting verification.',
      );
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code, _message(e));
    }
  }

  @override
  Future<AppUser> signInWithGoogle() =>
      _signInWithProvider(GoogleAuthProvider());

  @override
  Future<AppUser> signInWithApple() {
    final provider = OAuthProvider('apple.com')
      ..addScope('email')
      ..addScope('name');
    return _signInWithProvider(provider);
  }

  Future<AppUser> _signInWithProvider(AuthProvider provider) async {
    try {
      // Passed through as-is. `GoogleAuthProvider` is an `AuthProvider` but
      // not an `OAuthProvider`; the cast that used to sit here threw a
      // TypeError on every mobile Google sign-in (audit S-2).
      final cred = _isWeb
          ? await _auth.signInWithPopup(provider)
          : await _auth.signInWithProvider(provider);
      return await _hydrate(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code, _message(e));
    }
  }

  @override
  Future<void> sendMagicLink(String email) async {
    // Firebase email-link sign-in returns a tapped link (not a 6-digit code),
    // which needs deep-link handling to complete. Not wired yet.
    throw const AuthException(
      'unsupported',
      'Email-link sign-in isn\'t set up yet — use email & password or Google.',
    );
  }

  @override
  Future<AppUser> verifyMagicCode({
    required String email,
    required String code,
  }) async {
    throw const AuthException(
      'unsupported',
      'Email-link sign-in isn\'t set up yet.',
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('signed-out', 'Sign in before deleting.');
    }
    try {
      // Runs server-side with the Admin SDK — Firestore rules deliberately
      // block a client from deleting `users/{uid}` itself (billing state is
      // server-owned), and this also sidesteps Firebase's "requires a
      // recent sign-in" client-side re-auth requirement entirely.
      await _functions().httpsCallable('deleteAccount').call();
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(
        e.code,
        'Could not delete your account. Please try again.',
      );
    }
    _cached = null;
    await _auth.signOut();
  }

  @override
  Future<AppUser?> refreshCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      _cached = null;
      return null;
    }
    await user.reload();
    return _hydrate(_auth.currentUser ?? user);
  }

  /// Asks the server to re-read this account's entitlement from RevenueCat
  /// right now (after a purchase or restore). The profile listener then
  /// delivers the result. Best effort: the webhook still catches up if this
  /// fails.
  @override
  Future<void> syncEntitlement() async {
    if (_auth.currentUser == null) return;
    try {
      await _functions()
          .httpsCallable('syncEntitlement')
          .call<Object?>()
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      // Offline, not deployed yet, or RevenueCat unavailable.
    }
  }

  /// `grantedAt` is the server's clock, and the rules require exactly that,
  /// so the record can't be backdated.
  @override
  Future<AppUser> setDataConsent(
    DataConsentPurpose purpose, {
    required bool granted,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('signed-out', 'Sign in first.');
    }
    final write = _doc(user.uid).set({
      'consents': {
        purpose.key: granted
            ? {
                'version': purpose.currentVersion,
                'grantedAt': FieldValue.serverTimestamp(),
              }
            : FieldValue.delete(),
      },
    }, SetOptions(merge: true));
    // The local cache applies the write at once and the profile listener
    // re-emits it. Waiting for the server would hang offline (audit A-4); a
    // rejected write reverts through that same listener, and the app asks
    // again.
    unawaited(write.catchError((Object e) {
      if (kDebugMode) debugPrint('[auth] consent write failed: $e');
    }));
    final cached = _cached;
    final base = cached != null && cached.id == user.uid
        ? cached
        : _appUserFrom(user, const {});
    return _remember(base.copyWith(
      consents: granted
          ? base.consents.granted(purpose)
          : base.consents.withdrawn(purpose),
    ));
  }

  @override
  Future<AppUser> completeOnboarding({
    required String goal,
    required String experienceLevel,
    required int weeklyTrainingDays,
    required double? startingWeightKg,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('signed-out', 'Sign in before setup.');
    }
    await _doc(user.uid).set({
      'goal': goal,
      'experienceLevel': experienceLevel,
      'weeklyTrainingDays': weeklyTrainingDays,
      'startingWeightKg': startingWeightKg,
      'onboardingComplete': true,
      'onboardedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return _hydrate(user);
  }

  String _message(FirebaseAuthException e) {
    return switch (e.code) {
      'email-already-in-use' => 'An account with this email already exists.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' => 'Password must be at least 6 characters.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'Incorrect email or password.',
      'too-many-requests' => 'Too many attempts. Wait a minute and try again.',
      'requires-recent-login' =>
        'For your security, sign in again to make this change.',
      'network-request-failed' => 'Network error. Check your connection.',
      'popup-closed-by-user' || 'cancelled' => 'Sign-in cancelled.',
      _ => e.message ?? 'Authentication failed.',
    };
  }

  DateTime? _parseBillingDate(Object? value) {
    if (value is num && value > 0) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
