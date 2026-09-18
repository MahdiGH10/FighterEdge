import '../models/app_user.dart';

/// Actions that an unverified account may not take.
///
/// The list is deliberately short. Verification exists to protect the things
/// where an unreachable email causes real harm — money and server cost — not
/// to hold the product hostage. Logging food, weight and training, the round
/// timer, and the EdgeFuel plan all stay open, because a user who cannot try
/// the product has no reason to verify anything.
enum VerifiedAction {
  /// Buying Pro. A subscription tied to an address that may not exist is a
  /// refund and account-recovery problem the moment anything goes wrong.
  purchasePro,

  /// The AI coach. Every call costs money on our side, which makes unverified
  /// accounts a cheap way to farm inference.
  aiCoach,
}

/// How loudly the app should currently be asking for verification.
enum VerificationStage {
  /// Verified, or the backend does not support verification at all.
  none,

  /// Freshly signed up. A quiet banner; nothing is in the way.
  reminder,

  /// Past the grace period. The prompt gets prominent and the gated actions
  /// have been refused for a while.
  urgent,

  /// Long overdue. The app asks the user to resolve it before continuing.
  blocking,
}

/// The single place that decides what an unverified account can do.
///
/// Kept apart from [Entitlements] on purpose: billing answers "has this user
/// paid", verification answers "can we reach this user". Conflating them makes
/// both harder to reason about.
class VerificationGate {
  VerificationGate._();

  /// Days of untroubled use before the prompt becomes prominent.
  static const int graceDays = 3;

  /// Days before the app stops letting the user past the prompt. Generous on
  /// purpose — someone mid-fight-camp should not be locked out over an email
  /// that landed in spam.
  static const int blockingDays = 7;

  /// Whether [user] may perform [action].
  ///
  /// [supportsVerification] comes from the auth backend. When the backend has
  /// no concept of verification (the local/dev repository), the gate is open —
  /// otherwise dev and test builds would be unable to reach gated surfaces at
  /// all.
  static bool allows(
    AppUser? user,
    VerifiedAction action, {
    required bool supportsVerification,
  }) {
    if (!supportsVerification) return true;
    if (user == null) return false;
    return user.emailVerified;
  }

  /// How hard the app should currently be pushing [user] to verify.
  ///
  /// [now] is injectable so this stays a pure function — the stage depends on
  /// how long the account has existed, and tests must be able to move time
  /// without waiting for it.
  static VerificationStage stageFor(
    AppUser? user, {
    required bool supportsVerification,
    DateTime? now,
  }) {
    if (!supportsVerification) return VerificationStage.none;
    if (user == null || user.emailVerified) return VerificationStage.none;

    final age = (now ?? DateTime.now()).difference(user.createdAt).inDays;
    if (age >= blockingDays) return VerificationStage.blocking;
    if (age >= graceDays) return VerificationStage.urgent;
    return VerificationStage.reminder;
  }

  /// Copy for the moment a gated action is refused. Written to explain the
  /// reason rather than scold — the user has not done anything wrong.
  static String refusalMessage(VerifiedAction action) {
    return switch (action) {
      VerifiedAction.purchasePro =>
        'Verify your email before upgrading. Your subscription and receipts '
            'are tied to it.',
      VerifiedAction.aiCoach => 'Verify your email to unlock the AI coach.',
    };
  }
}
