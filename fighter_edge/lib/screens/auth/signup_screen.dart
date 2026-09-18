import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../auth/password_policy.dart';
import '../../controllers/auth_controller.dart';
import '../../routing/app_navigation.dart';
import '../../routing/app_router.dart';
import '../../theme/app_accessibility.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_haptics.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/password_strength_meter.dart';
import '../../widgets/primary_button.dart';
import '../legal_screen.dart';
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
  final _confirm = TextEditingController();
  final _emailFocus = FocusNode();
  bool _obscure = true;
  bool _agreed = false;

  /// Errors stay hidden until the user has had a fair chance to finish a
  /// field. Shouting "invalid email" at the first keystroke is noise.
  bool _emailTouched = false;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus && _email.text.isNotEmpty) {
        setState(() => _emailTouched = true);
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  String? get _emailError =>
      _emailTouched || _attempted ? validateEmailAddress(_email.text) : null;

  String? get _passwordError =>
      _attempted ? PasswordPolicy.validateNew(_password.text) : null;

  /// Shown as soon as the confirmation is as long as the password — by then a
  /// mismatch is a real mistake, not a half-typed word.
  String? get _confirmError {
    final settled = _attempted ||
        (_confirm.text.isNotEmpty &&
            _confirm.text.length >= _password.text.length);
    return settled
        ? PasswordPolicy.validateConfirmation(_password.text, _confirm.text)
        : null;
  }

  Future<void> _signUp() async {
    setState(() => _attempted = true);
    final invalid = validateEmailAddress(_email.text) != null ||
        PasswordPolicy.validateNew(_password.text) != null ||
        PasswordPolicy.validateConfirmation(_password.text, _confirm.text) !=
            null;
    if (invalid) {
      AppHaptics.warning();
      return;
    }
    if (!_agreed) {
      AppHaptics.warning();
      showAuthMessage(
          context, 'Please accept the terms to create your account.');
      return;
    }
    final auth = context.read<AuthController>();
    try {
      // No navigation here. Once the session exists the router's auth
      // redirect takes the user off this screen to the gate, which shows
      // onboarding — this screen does not need to know what is underneath it.
      await auth.signUp(_email.text, _password.text, _name.text);
      TextInput.finishAutofillContext();
    } catch (e) {
      if (mounted) showAuthError(context, e);
    }
  }

  void _openLegal(LegalDocument doc) {
    AppNavigation.push(
      context,
      AppRoutes.legal(doc),
      fallbackBuilder: (_) => LegalScreen(document: doc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return ScreenScaffold(
      title: 'Create Account',
      showBack: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, Insets.xxl),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Insets.sm),
              Text('Start your camp', style: AppType.title1()),
              const SizedBox(height: Insets.xs),
              Text('Track training, weight, nutrition and more.',
                  style: AppType.subhead(color: AppColors.textSecondary)),
              const SizedBox(height: Insets.xl),
              AppTextField(
                controller: _name,
                label: 'Name',
                icon: Icons.person_outline,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: Insets.md),
              AppTextField(
                controller: _email,
                focusNode: _emailFocus,
                label: 'Email',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                errorText: _emailError,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Insets.md),
              AppTextField(
                controller: _password,
                label: 'Password',
                icon: Icons.lock_outline,
                obscure: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                errorText: _passwordError,
                onChanged: (_) => setState(() {}),
                suffix: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textMuted, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              PasswordStrengthMeter(password: _password.text),
              const SizedBox(height: Insets.md),
              AppTextField(
                controller: _confirm,
                label: 'Confirm password',
                icon: Icons.lock_outline,
                obscure: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                errorText: _confirmError,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _signUp(),
              ),
              const SizedBox(height: Insets.sm),
              _TermsAgreement(
                agreed: _agreed,
                onChanged: (v) => setState(() => _agreed = v),
                onOpen: _openLegal,
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
      ),
    );
  }
}

/// Checkbox plus the two documents it refers to, each a real link.
///
/// The links are full-height buttons rather than tappable spans inside a
/// sentence: spans can't reach the 44pt target, and a miss would toggle the
/// checkbox instead of opening the page.
class _TermsAgreement extends StatelessWidget {
  final bool agreed;
  final ValueChanged<bool> onChanged;
  final ValueChanged<LegalDocument> onOpen;

  const _TermsAgreement({
    required this.agreed,
    required this.onChanged,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle =
        AppType.subhead(color: AppAccessibility.textSecondary(context));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: agreed,
          activeColor: AppColors.primary,
          semanticLabel: 'I agree to the Terms of Service and Privacy Policy',
          onChanged: (v) {
            AppHaptics.selection();
            onChanged(v ?? false);
          },
        ),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // The checkbox already carries the whole sentence for screen
              // readers; this is only a bigger visual hit area for it.
              ExcludeSemantics(
                child: GestureDetector(
                  onTap: () => onChanged(!agreed),
                  child: Text('I agree to the ', style: textStyle),
                ),
              ),
              _LegalLink(
                label: 'Terms',
                path: AppRoutes.legal(LegalDocument.terms),
                onTap: () => onOpen(LegalDocument.terms),
              ),
              ExcludeSemantics(child: Text(' & ', style: textStyle)),
              _LegalLink(
                label: 'Privacy Policy',
                path: AppRoutes.legal(LegalDocument.privacy),
                onTap: () => onOpen(LegalDocument.privacy),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final String path;
  final VoidCallback onTap;
  const _LegalLink({
    required this.label,
    required this.path,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      // Without a URL, Flutter web renders the link as plain text to
      // assistive tech rather than as a link.
      linkUrl: Uri.parse(path),
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.button),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppAccessibility.minTouchTarget,
          ),
          child: Align(
            widthFactor: 1,
            child: Text(
              label,
              style: AppType.subhead(
                color: AppAccessibility.accentText(context),
                weight: FontWeight.w600,
              ).copyWith(decoration: TextDecoration.underline),
            ),
          ),
        ),
      ),
    );
  }
}
