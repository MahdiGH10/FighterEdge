import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/auth/password_policy.dart';

void main() {
  group('PasswordPolicy.strengthOf', () {
    test('is quiet before anything is typed', () {
      expect(PasswordPolicy.strengthOf(''), PasswordStrength.empty);
    });

    test('flags anything under the minimum as too short', () {
      expect(PasswordPolicy.strengthOf('Ab1!xyz'), PasswordStrength.tooShort);
    });

    test('rates common and repeated passwords weak however long', () {
      expect(PasswordPolicy.strengthOf('password123'), PasswordStrength.weak);
      expect(PasswordPolicy.strengthOf('FighterEdge'), PasswordStrength.weak);
      expect(
          PasswordPolicy.strengthOf('aaaaaaaaaaaaaaaa'), PasswordStrength.weak);
    });

    test('rewards length and variety', () {
      expect(PasswordPolicy.strengthOf('abcdefgh'), PasswordStrength.weak);
      expect(PasswordPolicy.strengthOf('abcdefgh12'), PasswordStrength.weak);
      expect(PasswordPolicy.strengthOf('abcdefghij12'), PasswordStrength.fair);
      expect(PasswordPolicy.strengthOf('Southpaw-Jab-42'),
          PasswordStrength.strong);
    });
  });

  group('PasswordPolicy validation', () {
    test('only length blocks a new password', () {
      expect(PasswordPolicy.validateNew(''), isNotNull);
      expect(PasswordPolicy.validateNew('1234567'), isNotNull);
      expect(PasswordPolicy.validateNew('abcdefgh'), isNull);
    });

    test('confirmation must repeat the password exactly', () {
      expect(PasswordPolicy.validateConfirmation('abcdefgh', ''), isNotNull);
      expect(PasswordPolicy.validateConfirmation('abcdefgh', 'abcdefgH'),
          isNotNull);
      expect(
          PasswordPolicy.validateConfirmation('abcdefgh', 'abcdefgh'), isNull);
    });
  });

  test('validateEmailAddress accepts real shapes and trims', () {
    expect(validateEmailAddress(''), isNotNull);
    expect(validateEmailAddress('fighter@'), isNotNull);
    expect(validateEmailAddress('fighter@gym'), isNotNull);
    expect(validateEmailAddress('  fighter@gym.com '), isNull);
  });
}
