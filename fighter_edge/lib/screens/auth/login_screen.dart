import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/brand_logo.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                      textAlign: TextAlign.center, style: AppTheme.display(22)),
                  const SizedBox(height: Insets.xs),
                  Text('Sign in to continue your camp',
                      textAlign: TextAlign.center,
                      style: AppTheme.body(13, color: AppColors.textSecondary)),
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
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textMuted,
                          size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen())),
                      child: Text('Forgot password?',
                          style: AppTheme.body(12,
                              weight: FontWeight.w600,
                              color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  PrimaryButton(
                    auth.isBusy ? 'Signing in…' : 'Sign In',
                    expand: true,
                    onPressed: auth.isBusy ? null : _signIn,
                  ),
                  const SizedBox(height: Insets.xl),
                  const OrDivider(),
                  const SizedBox(height: Insets.xl),
                  SocialButton(
                    icon: Icons.g_mobiledata,
                    label: 'Continue with Google',
                    onPressed: auth.isBusy
                        ? null
                        : () => _social(auth.signInWithGoogle),
                  ),
                  const SizedBox(height: Insets.md),
                  SocialButton(
                    icon: Icons.apple,
                    label: 'Continue with Apple',
                    onPressed:
                        auth.isBusy ? null : () => _social(auth.signInWithApple),
                  ),
                  const SizedBox(height: Insets.md),
                  SocialButton(
                    icon: Icons.mail_lock_outlined,
                    label: 'Email me a sign-in code',
                    onPressed: auth.isBusy
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const MagicLinkScreen())),
                  ),
                  const SizedBox(height: Insets.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("New here? ",
                          style: AppTheme.body(13,
                              color: AppColors.textSecondary)),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SignupScreen())),
                        child: Text('Create account',
                            style: AppTheme.body(13,
                                weight: FontWeight.w700,
                                color: AppColors.primary)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
