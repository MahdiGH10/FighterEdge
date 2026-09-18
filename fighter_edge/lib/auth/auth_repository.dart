import '../models/app_user.dart';

/// Thrown by any [AuthRepository] method on a recoverable auth failure.
/// Concrete implementations translate provider errors (FirebaseAuthException,
/// Supabase AuthException, …) into this so the UI stays provider-agnostic.
class AuthException implements Exception {
  final String code;
  final String message;
  const AuthException(this.code, this.message);

  @override
  String toString() => message;
}

/// The single seam the whole app talks to for identity. Swapping providers
/// (Local → Firebase) means implementing this one interface — no UI changes.
abstract class AuthRepository {
  bool get supportsGoogle => true;
  bool get supportsApple => true;
  bool get supportsMagicLink => true;
  bool get supportsEmailVerification => false;

  /// Restore any persisted session before the app builds. Call once at startup.
  Future<void> init();

  /// Emits the current user (or null) and every subsequent auth change.
  Stream<AppUser?> authStateChanges();

  /// The currently signed-in user, if any (synchronous snapshot).
  AppUser? get currentUser;

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset(String email);

  /// Whether the signed-in user has a password of their own. False for
  /// accounts that only ever used Google or Apple — they have nothing to
  /// change here.
  bool get canChangePassword;

  /// Proves the user knows [currentPassword], then replaces it.
  ///
  /// Reauthentication is part of the call, not a separate step: providers
  /// refuse a password change without a recent sign-in, and asking for the
  /// current password is the one prompt that satisfies that for everyone.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> sendEmailVerification();

  Future<AppUser> signInWithGoogle();

  Future<AppUser> signInWithApple();

  /// Sends a one-time code / magic link to [email].
  Future<void> sendMagicLink(String email);

  /// Completes passwordless sign-in with the code delivered to [email].
  Future<AppUser> verifyMagicCode({
    required String email,
    required String code,
  });

  Future<void> signOut();

  /// Permanently deletes the signed-in user's account and all of their data.
  /// Irreversible. Signs the user out as part of completing.
  Future<void> deleteAccount();

  /// Reload the current user and server-owned entitlement state.
  Future<AppUser?> refreshCurrentUser();

  /// Stores first-run setup choices. This is account profile data, not a paid
  /// entitlement, so the client may write it directly.
  Future<AppUser> completeOnboarding({
    required String goal,
    required String experienceLevel,
    required int weeklyTrainingDays,
    required double? startingWeightKg,
  });
}
