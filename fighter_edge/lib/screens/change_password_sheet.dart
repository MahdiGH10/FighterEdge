import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_repository.dart';
import '../auth/password_policy.dart';
import '../controllers/auth_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_haptics.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_text_field.dart';
import '../widgets/password_strength_meter.dart';
import '../widgets/primary_button.dart';
import 'auth/auth_widgets.dart';

/// Opens the change-password sheet. Resolves to true once the password has
/// actually changed.
Future<bool> showChangePasswordSheet(BuildContext context) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
    ),
    builder: (_) => const ChangePasswordSheet(),
  );
  return changed ?? false;
}

/// Asks for the current password alongside the new one.
///
/// The current password is the reauthentication: providers refuse a password
/// change without a recent sign-in, and one extra field here is far gentler
/// than signing the user out to get it.
class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _attempted = false;

  /// Set from the server's answer, so it sits on the field it is about.
  String? _currentError;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? get _nextError {
    if (!_attempted) return null;
    final base = PasswordPolicy.validateNew(_next.text);
    if (base != null) return base;
    if (_next.text == _current.text) {
      return 'Pick a password different from your current one.';
    }
    return null;
  }

  String? get _confirmError {
    final settled = _attempted ||
        (_confirm.text.isNotEmpty && _confirm.text.length >= _next.text.length);
    return settled
        ? PasswordPolicy.validateConfirmation(_next.text, _confirm.text)
        : null;
  }

  Future<void> _submit() async {
    setState(() {
      _attempted = true;
      _currentError =
          _current.text.isEmpty ? 'Enter your current password.' : null;
    });
    if (_currentError != null || _nextError != null || _confirmError != null) {
      AppHaptics.warning();
      return;
    }
    try {
      await context.read<AuthController>().changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      // The two beats play while the sheet closes; waiting for them would
      // hold the sheet on screen for no reason.
      unawaited(AppHaptics.success());
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (!mounted) return;
      AppHaptics.warning();
      if (e.code == 'wrong-password') {
        setState(() => _currentError = e.message);
      } else {
        showAuthError(context, e);
      }
    } catch (e) {
      if (mounted) showAuthError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AuthController>().isBusy;
    final toggle = IconButton(
      tooltip: _obscure ? 'Show passwords' : 'Hide passwords',
      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
          color: AppColors.textMuted, size: 20),
      onPressed: () => setState(() => _obscure = !_obscure),
    );
    return Padding(
      // Rides above the keyboard instead of disappearing under it.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Insets.xl),
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Change password', style: AppType.title1()),
                const SizedBox(height: Insets.xs),
                Text(
                  'Confirm your current password first — it keeps anyone '
                  'holding your phone from locking you out.',
                  style: AppType.subhead(color: AppColors.textSecondary),
                ),
                const SizedBox(height: Insets.xl),
                AppTextField(
                  controller: _current,
                  label: 'Current password',
                  icon: Icons.lock_outline,
                  obscure: _obscure,
                  autofocus: true,
                  autofillHints: const [AutofillHints.password],
                  errorText: _currentError,
                  onChanged: (_) {
                    if (_currentError != null) {
                      setState(() => _currentError = null);
                    }
                  },
                  suffix: toggle,
                ),
                const SizedBox(height: Insets.md),
                AppTextField(
                  controller: _next,
                  label: 'New password',
                  icon: Icons.lock_reset,
                  obscure: _obscure,
                  autofillHints: const [AutofillHints.newPassword],
                  errorText: _nextError,
                  onChanged: (_) => setState(() {}),
                ),
                PasswordStrengthMeter(password: _next.text),
                const SizedBox(height: Insets.md),
                AppTextField(
                  controller: _confirm,
                  label: 'Confirm new password',
                  icon: Icons.lock_reset,
                  obscure: _obscure,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  errorText: _confirmError,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: Insets.xl),
                PrimaryButton(
                  busy ? 'Updating…' : 'Update password',
                  expand: true,
                  onPressed: busy ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
