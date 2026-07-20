import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/premium_effects.dart';
import '../home_shell.dart';
import '../onboarding_screen.dart';
import 'login_screen.dart';

/// Routes between the auth flow and the app based on [AuthController.status].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthController>().status;
    final user = context.watch<AuthController>().user;
    return switch (status) {
      AuthStatus.unknown => const _Splash(),
      AuthStatus.authenticated => (user?.onboardingComplete ?? false)
          ? const HomeShell()
          : const OnboardingScreen(),
      AuthStatus.unauthenticated => const LoginScreen(),
    };
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
