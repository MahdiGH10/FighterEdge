import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import 'auth_widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _agreed = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_agreed) {
      showAuthMessage(
          context, 'Please accept the terms to create your account.');
      return;
    }
    final auth = context.read<AuthController>();
    try {
      await auth.signUp(_email.text, _password.text, _name.text);
      if (mounted) Navigator.of(context).pop(); // AuthGate swaps to the app
    } catch (e) {
      if (mounted) showAuthError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return ScreenScaffold(
      title: 'Create Account',
      showBack: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, Insets.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Insets.sm),
            Text('Start your camp', style: AppTheme.display(22)),
            const SizedBox(height: Insets.xs),
            Text('Track training, weight, nutrition and more.',
                style: AppTheme.body(13, color: AppColors.textSecondary)),
            const SizedBox(height: Insets.xl),
            AppTextField(
              controller: _name,
              label: 'Name',
              icon: Icons.person_outline,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: Insets.md),
            AppTextField(
              controller: _email,
              label: 'Email',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: Insets.md),
            AppTextField(
              controller: _password,
              label: 'Password (min 6 characters)',
              icon: Icons.lock_outline,
              obscure: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _signUp(),
              suffix: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textMuted, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: Insets.sm),
            Row(
              children: [
                Checkbox(
                  value: _agreed,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                ),
                Expanded(
                  child: Text('I agree to the Terms & Privacy Policy',
                      style: AppTheme.body(12, color: AppColors.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            PrimaryButton(
              auth.isBusy ? 'Creating…' : 'Create Account',
              expand: true,
              onPressed: auth.isBusy ? null : _signUp,
            ),
          ],
        ),
      ),
    );
  }
}
