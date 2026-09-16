import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import 'auth_widgets.dart';

class MagicLinkScreen extends StatefulWidget {
  const MagicLinkScreen({super.key});

  @override
  State<MagicLinkScreen> createState() => _MagicLinkScreenState();
}

class _MagicLinkScreenState extends State<MagicLinkScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final auth = context.read<AuthController>();
    try {
      await auth.sendMagicLink(_email.text);
      if (mounted) setState(() => _codeSent = true);
    } catch (e) {
      if (mounted) showAuthError(context, e);
    }
  }

  Future<void> _verify() async {
    final auth = context.read<AuthController>();
    try {
      await auth.verifyMagicCode(_email.text, _code.text);
      if (mounted) Navigator.of(context).pop(); // AuthGate swaps to the app
    } catch (e) {
      if (mounted) showAuthError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final hint = auth.devMagicHint;
    return ScreenScaffold(
      title: 'Email Sign-In',
      showBack: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            Insets.xl, Insets.lg, Insets.xl, Insets.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.mail_lock_outlined,
                size: 48, color: AppColors.primary),
            const SizedBox(height: Insets.lg),
            Text(_codeSent ? 'Enter your code' : 'Passwordless sign-in',
                textAlign: TextAlign.center, style: AppType.title1()),
            const SizedBox(height: Insets.sm),
            Text(
              _codeSent
                  ? 'We sent a 6-digit code to ${_email.text.trim()}.'
                  : 'We\'ll email you a one-time code — no password needed.',
              textAlign: TextAlign.center,
              style: AppType.subhead(color: AppColors.textSecondary),
            ),
            const SizedBox(height: Insets.xl),
            if (!_codeSent) ...[
              AppTextField(
                controller: _email,
                label: 'Email',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _sendCode(),
              ),
              const SizedBox(height: Insets.lg),
              PrimaryButton(
                auth.isBusy ? 'Sending…' : 'Send Code',
                expand: true,
                onPressed: auth.isBusy ? null : _sendCode,
              ),
            ] else ...[
              AppTextField(
                controller: _code,
                label: '6-digit code',
                icon: Icons.pin_outlined,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofocus: true,
                onSubmitted: (_) => _verify(),
              ),
              if (hint != null) ...[
                const SizedBox(height: Insets.sm),
                Container(
                  padding: const EdgeInsets.all(Insets.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(Radii.button),
                  ),
                  child: Text('Demo mode — your code is $hint',
                      textAlign: TextAlign.center,
                      style: AppType.subhead(
                          weight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                ),
              ],
              const SizedBox(height: Insets.lg),
              PrimaryButton(
                auth.isBusy ? 'Verifying…' : 'Verify & Continue',
                expand: true,
                onPressed: auth.isBusy ? null : _verify,
              ),
              const SizedBox(height: Insets.sm),
              TextButton(
                onPressed: () => setState(() => _codeSent = false),
                child: Text('Use a different email',
                    style: AppType.subhead(
                        weight: FontWeight.w600, color: AppColors.accentText)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
