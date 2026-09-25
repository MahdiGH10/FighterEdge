import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/verification_gate.dart';
import '../../controllers/auth_controller.dart';
import '../../theme/app_accessibility.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_haptics.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/premium_effects.dart';
import '../../widgets/primary_button.dart';
import 'auth_widgets.dart';

/// The screen that asks the user to confirm their email address.
///
/// Appears in two situations: reached deliberately from the dashboard banner,
/// and — once the account is [VerificationStage.blocking] — as the thing
/// standing between the user and the app.
///
/// The user never comes back here to tell us they are done. They tap a link in
/// a mail app, which on modern Firebase cannot reliably deep-link back into a
/// running app (Dynamic Links shut down in 2025). So this screen watches
/// instead: while it is open it re-reads the account every few seconds and
/// advances by itself the moment the address goes verified. That is both
/// simpler than deep links and more reliable, because it works no matter where
/// the link was opened — desktop mail client, another phone, anywhere.
class VerifyEmailScreen extends StatefulWidget {
  /// When true the user cannot dismiss this screen; their only ways out are
  /// verifying or signing out. Set for [VerificationStage.blocking].
  final bool blocking;

  const VerifyEmailScreen({super.key, this.blocking = false});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  /// Fast enough that the app feels like it noticed, slow enough not to hammer
  /// the auth backend while someone hunts through their spam folder.
  static const _pollInterval = Duration(seconds: 3);

  Timer? _poll;
  Timer? _cooldownTicker;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimers();
  }

  void _startTimers() {
    _poll = Timer.periodic(_pollInterval, (_) => _check());
    // Drives the countdown label only; the cooldown itself is time-based, so a
    // missed tick cannot desynchronise it.
    _cooldownTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted &&
            context.read<AuthController>().resendCooldownSeconds > 0) {
          setState(() {});
        }
      },
    );
  }

  void _stopTimers() {
    _poll?.cancel();
    _poll = null;
    _cooldownTicker?.cancel();
    _cooldownTicker = null;
  }

  // Polling every 3 seconds is wasted battery and network while the app sits
  // in the background — nobody is watching this screen for the result (audit
  // P-9). Stop on the way out, and check once immediately on the way back in,
  // in case the link was confirmed while backgrounded.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_verified) return;
    if (state == AppLifecycleState.resumed) {
      if (_poll == null) {
        _startTimers();
        unawaited(_check());
      }
    } else if (state == AppLifecycleState.paused) {
      _stopTimers();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimers();
    super.dispose();
  }

  Future<void> _check() async {
    if (!mounted || _verified) return;
    final verified =
        await context.read<AuthController>().refreshVerificationStatus();
    if (!mounted || !verified) return;
    setState(() => _verified = true);
    _poll?.cancel();
    AppHaptics.success();
  }

  Future<void> _resend() async {
    final auth = context.read<AuthController>();
    try {
      await auth.sendEmailVerification();
      if (!mounted) return;
      showAuthMessage(context, 'Verification email sent.');
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      showAuthError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final email = auth.user?.email ?? '';

    return PopScope(
      // A blocking prompt that a back gesture dismisses is not a prompt.
      canPop: !widget.blocking,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: PremiumBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Insets.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _verified
                      ? _VerifiedView(onContinue: _leave)
                      : _WaitingView(
                          email: email,
                          blocking: widget.blocking,
                          isBusy: auth.isBusy,
                          cooldownSeconds: auth.resendCooldownSeconds,
                          onResend: auth.canResendVerification && !auth.isBusy
                              ? _resend
                              : null,
                          onCheckNow: _check,
                          onSignOut: () => auth.signOut(),
                          onNotNow: widget.blocking ? null : () => _leave(),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _leave() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    // When this screen is the blocking gate it is not on a route of its own —
    // the gate rebuilds past it once the user is verified.
  }
}

class _WaitingView extends StatelessWidget {
  final String email;
  final bool blocking;
  final bool isBusy;
  final int cooldownSeconds;
  final VoidCallback? onResend;
  final VoidCallback onCheckNow;
  final VoidCallback onSignOut;
  final VoidCallback? onNotNow;

  const _WaitingView({
    required this.email,
    required this.blocking,
    required this.isBusy,
    required this.cooldownSeconds,
    required this.onResend,
    required this.onCheckNow,
    required this.onSignOut,
    required this.onNotNow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_unread_outlined,
              color: AppColors.primaryBright, size: 28),
        ),
        const SizedBox(height: Insets.xl),
        Text(
          blocking ? 'Confirm your email to continue' : 'Check your inbox',
          style: AppType.title1(),
        ),
        const SizedBox(height: Insets.sm),
        Text(
          email.isEmpty
              ? 'We sent you a verification link. Open it and this screen will continue on its own.'
              : 'We sent a verification link to $email. Open it and this screen will continue on its own.',
          style:
              AppType.callout(color: AppAccessibility.textSecondary(context)),
        ),
        if (blocking) ...[
          const SizedBox(height: Insets.md),
          Text(
            'Your training, weight and fuel logs are safe. Verifying keeps '
            'access to your account if you ever change device.',
            style: AppType.subhead(color: AppAccessibility.textMuted(context)),
          ),
        ],
        const SizedBox(height: Insets.xl),
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.textMuted),
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Text('Waiting for confirmation…',
                  style: AppType.subhead(
                      color: AppAccessibility.textMuted(context))),
            ),
          ],
        ),
        const SizedBox(height: Insets.xl),
        PrimaryButton(
          cooldownSeconds > 0
              ? 'Resend in ${cooldownSeconds}s'
              : 'Resend email',
          expand: true,
          onPressed: onResend,
        ),
        const SizedBox(height: Insets.sm),
        GhostButton(
          'I already confirmed',
          expand: true,
          onPressed: isBusy ? null : onCheckNow,
        ),
        const SizedBox(height: Insets.xl),
        // Always available. Someone who mistyped their address needs a way
        // out that is not "delete the app".
        Center(
          child: TextButton(
            onPressed: onSignOut,
            child: Text(
              'Sign out and use a different email',
              style: AppType.subhead(
                  weight: FontWeight.w600,
                  color: AppAccessibility.textSecondary(context)),
            ),
          ),
        ),
        if (onNotNow != null)
          Center(
            child: TextButton(
              onPressed: onNotNow,
              child: Text('Not now',
                  style: AppType.subhead(
                      weight: FontWeight.w600,
                      color: AppAccessibility.textMuted(context))),
            ),
          ),
      ],
    );
  }
}

class _VerifiedView extends StatelessWidget {
  final VoidCallback onContinue;

  const _VerifiedView({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.positiveSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              color: AppColors.positiveStrong, size: 30),
        ),
        const SizedBox(height: Insets.xl),
        Text('Email confirmed', style: AppType.title1()),
        const SizedBox(height: Insets.sm),
        Text(
          'Your account is secured. Pro and the AI coach are unlocked.',
          style:
              AppType.callout(color: AppAccessibility.textSecondary(context)),
        ),
        const SizedBox(height: Insets.xl),
        PrimaryButton(
          'Back to training',
          icon: Icons.arrow_forward,
          expand: true,
          onPressed: onContinue,
        ),
      ],
    );
  }
}
