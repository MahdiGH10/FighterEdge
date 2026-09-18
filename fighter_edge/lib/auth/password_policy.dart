/// How strong a candidate password looks.
enum PasswordStrength {
  /// Nothing typed yet. The meter stays quiet.
  empty,

  /// Below [PasswordPolicy.minLength]. The only level that blocks submission.
  tooShort,

  /// Long enough, but trivially guessable.
  weak,
  fair,
  strong,
}

/// The single place that decides what a new password must be and how good it
/// looks. Used by signup and by password change, so both agree.
///
/// Only length is enforced. Composition rules ("one symbol, one capital")
/// push people toward `Password1!`; length and avoiding the obvious do more,
/// so the meter nudges and never blocks past the minimum.
class PasswordPolicy {
  PasswordPolicy._();

  /// Firebase accepts 6. We ask for 8, the common floor for new passwords.
  /// Existing accounts with shorter passwords can still sign in — this only
  /// applies when a password is being set.
  static const int minLength = 8;

  /// Passwords people reach for first. A match is weak however long it is.
  static const _common = {
    'password',
    'password1',
    'password123',
    '12345678',
    '123456789',
    '1234567890',
    'qwertyuiop',
    'qwerty123',
    'iloveyou',
    'fighteredge',
    'letmein123',
    'football',
    'baseball',
  };

  static PasswordStrength strengthOf(String password) {
    if (password.isEmpty) return PasswordStrength.empty;
    if (password.length < minLength) return PasswordStrength.tooShort;
    if (_common.contains(password.toLowerCase()) ||
        RegExp(r'^(.)\1+$').hasMatch(password)) {
      return PasswordStrength.weak;
    }

    var score = 0;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;
    if (RegExp('[a-z]').hasMatch(password) &&
        RegExp('[A-Z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;

    if (score >= 3) return PasswordStrength.strong;
    if (score >= 2) return PasswordStrength.fair;
    return PasswordStrength.weak;
  }

  /// An error for a new password, or null when it can be submitted.
  static String? validateNew(String password) {
    if (password.isEmpty) return 'Choose a password.';
    if (password.length < minLength) {
      return 'Use at least $minLength characters.';
    }
    return null;
  }

  /// An error when [confirmation] does not repeat [password], else null.
  static String? validateConfirmation(String password, String confirmation) {
    if (confirmation.isEmpty) return 'Type your password again.';
    if (confirmation != password) return "Passwords don't match.";
    return null;
  }
}

/// Email shape check shared by the auth forms. Deliberately loose: the only
/// real test of an address is the verification email.
String? validateEmailAddress(String email) {
  final trimmed = email.trim();
  if (trimmed.isEmpty) return 'Enter your email.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed)) {
    return 'That email looks incomplete.';
  }
  return null;
}
