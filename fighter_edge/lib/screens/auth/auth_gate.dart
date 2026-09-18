import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/verification_gate.dart';
import '../../controllers/auth_controller.dart';
import '../../models/app_user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/premium_effects.dart';
import '../home_shell.dart';
import '../onboarding/onboarding_screen.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

/// Routes between the auth flow and the app based on [AuthController.status].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final status = auth.status;
    final user = auth.user;
    return switch (status) {
      AuthStatus.unknown => const _Splash(),
      AuthStatus.authenticated => _authenticated(auth, user),
      AuthStatus.unauthenticated => const LoginScreen(),
    };
  }

  Widget _authenticated(AuthController auth, AppUser? user) {
    // Onboarding comes first even when verification is overdue: a brand-new
    // account cannot be overdue, and interrupting setup to demand an email
    // would strand the user with nothing to come back to.
    if (!(user?.onboardingComplete ?? false)) return const OnboardingScreen();

    // Long overdue. The free loop stayed open for a week; past that the app
    // asks the user to resolve it before continuing.
    if (auth.verificationStage == VerificationStage.blocking) {
      return const VerifyEmailScreen(blocking: true);
    }

    return const HomeShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: PremiumBackground(
        child: Center(
          child: PremiumReveal(child: BrandLogo(scale: 1.2)),
        ),
      ),
    );
  }
}
