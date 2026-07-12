import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import 'auth_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final auth = context.read<AuthController>();
    try {
      await auth.sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) showAuthError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return ScreenScaffold(
      title: 'Reset Password',
      showBack: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            Insets.xl, Insets.lg, Insets.xl, Insets.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(_sent ? Icons.mark_email_read_outlined : Icons.lock_reset,
                size: 48, color: AppColors.primary),
            const SizedBox(height: Insets.lg),
            Text(_sent ? 'Check your inbox' : 'Forgot your password?',
                textAlign: TextAlign.center, style: AppTheme.display(20)),
            const SizedBox(height: Insets.sm),
            Text(
              _sent
                  ? 'If an account exists for ${_email.text.trim()}, a reset link is on its way.'
                  : 'Enter your email and we\'ll send you a link to reset it.',
              textAlign: TextAlign.center,
              style: AppTheme.body(13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: Insets.xl),
            if (!_sent) ...[
              AppTextField(
                controller: _email,
                label: 'Email',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _send(),
              ),
              const SizedBox(height: Insets.lg),
              PrimaryButton(
                auth.isBusy ? 'Sending…' : 'Send Reset Link',
                expand: true,
                onPressed: auth.isBusy ? null : _send,
              ),
            ] else
              PrimaryButton(
                'Back to Sign In',
                expand: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}
