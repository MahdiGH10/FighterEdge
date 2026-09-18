import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/controllers/auth_controller.dart';
import 'package:fighter_edge/routing/app_router.dart';
import 'package:fighter_edge/screens/legal_screen.dart';

void main() {
  group('authRedirect', () {
    test('waits while the session is still unknown', () {
      expect(authRedirect(AuthStatus.unknown, AppRoutes.settings), isNull);
    });

    test('sends a signed-out user off app screens', () {
      for (final route in [
        AppRoutes.settings,
        AppRoutes.profile,
        AppRoutes.paywall,
        AppRoutes.verifyEmail,
        AppRoutes.fuelPlan,
      ]) {
        expect(authRedirect(AuthStatus.unauthenticated, route), AppRoutes.root,
            reason: route);
      }
    });

    test('lets a signed-out user reach the auth and legal screens', () {
      for (final route in [
        AppRoutes.root,
        AppRoutes.signup,
        AppRoutes.forgotPassword,
        AppRoutes.magicLink,
        AppRoutes.legal(LegalDocument.terms),
        AppRoutes.legal(LegalDocument.privacy),
      ]) {
        expect(authRedirect(AuthStatus.unauthenticated, route), isNull,
            reason: route);
      }
    });

    test('moves a user who just signed in off the signed-out screens', () {
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.signup),
          AppRoutes.root);
      expect(authRedirect(AuthStatus.authenticated, AppRoutes.magicLink),
          AppRoutes.root);
    });

    test('leaves a signed-in user where they are otherwise', () {
      expect(
          authRedirect(AuthStatus.authenticated, AppRoutes.settings), isNull);
      expect(
        authRedirect(
            AuthStatus.authenticated, AppRoutes.legal(LegalDocument.terms)),
        isNull,
      );
    });
  });
}
