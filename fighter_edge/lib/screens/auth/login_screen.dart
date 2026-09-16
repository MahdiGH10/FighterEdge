import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../routing/app_navigation.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/primary_button.dart';
import 'auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'magic_link_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final auth = context.read<AuthController>();
    try {
      await auth.signIn(_email.text, _password.text);
    } catch (e) {
      if (mounted) showAuthError(context, e);
    }
  }

  Future<void> _social(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) showAuthError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final hasSecondaryAuth =
        auth.supportsGoogle || auth.supportsApple || auth.supportsMagicLink;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login_background.png',
            fit: BoxFit.cover,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.background.withValues(alpha: 0.55),
                  AppColors.background.withValues(alpha: 0.88),
                  AppColors.background,
                ],
                stops: const [0.0, 0.45, 0.85],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Insets.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: Insets.xl),
                      const BrandLogo(scale: 1.1),
                      const SizedBox(height: Insets.xxl),
                      Text('Welcome back',
                          textAlign: TextAlign.center, style: AppType.title1()),
                      const SizedBox(height: Insets.xs),
                      Text('Sign in to continue your camp',
                          textAlign: TextAlign.center,
                          style:
                              AppType.subhead(color: AppColors.textSecondary)),
                      const SizedBox(height: Insets.xl),
                      AppTextField(
                        controller: _email,
                        label: 'Email',
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: Insets.md),
                      AppTextField(
                        controller: _password,
                        label: 'Password',
                        icon: Icons.lock_outline,
                        obscure: _obscure,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _signIn(),
                        suffix: IconButton(
                          icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.textMuted,
                              size: 20),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => AppNavigation.push(
                            context,
                            AppRoutes.forgotPassword,
                            fallbackBuilder: (_) =>
                                const ForgotPasswordScreen(),
                          ),
                          child: Text('Forgot password?',
                              style: AppType.subhead(
                                  weight: FontWeight.w600,
                                  color: AppColors.accentText)),
                        ),
                      ),
                      const SizedBox(height: Insets.sm),
                      PrimaryButton(
                        auth.isBusy ? 'Signing in…' : 'Sign In',
                        expand: true,
                        onPressed: auth.isBusy ? null : _signIn,
                      ),
                      if (hasSecondaryAuth) ...[
                        const SizedBox(height: Insets.xl),
                        const OrDivider(),
                        const SizedBox(height: Insets.xl),
                        if (auth.supportsGoogle) ...[
                          SocialButton(
                            icon: Icons.g_mobiledata,
                            label: 'Continue with Google',
                            onPressed: auth.isBusy
                                ? null
                                : () => _social(auth.signInWithGoogle),
                          ),
                          const SizedBox(height: Insets.md),
                        ],
                        if (auth.supportsApple) ...[
                          SocialButton(
                            icon: Icons.apple,
                            label: 'Continue with Apple',
                            onPressed: auth.isBusy
                                ? null
                                : () => _social(auth.signInWithApple),
                          ),
                          const SizedBox(height: Insets.md),
                        ],
                        if (auth.supportsMagicLink)
                          SocialButton(
                            icon: Icons.mail_lock_outlined,
                            label: 'Email me a sign-in code',
                            onPressed: auth.isBusy
                                ? null
                                : () => AppNavigation.push(
                                      context,
                                      AppRoutes.magicLink,
                                      fallbackBuilder: (_) =>
                                          const MagicLinkScreen(),
                                    ),
                          ),
                      ],
                      const SizedBox(height: Insets.xl),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("New here? ",
                              style: AppType.subhead(
                                  color: AppColors.textSecondary)),
                          PressScale(
                            onTap: () => AppNavigation.push(
                              context,
                              AppRoutes.signup,
                              fallbackBuilder: (_) => const SignupScreen(),
                            ),
                            child: Text('Create account',
                                style: AppType.subhead(
                                    weight: FontWeight.w700,
                                    color: AppColors.accentText)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
