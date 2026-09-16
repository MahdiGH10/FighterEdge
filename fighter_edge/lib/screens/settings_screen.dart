import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';
import '../widgets/stat_card.dart';
import 'paywall_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final state = context.watch<AppState>();
    final user = auth.user;

    return ScreenScaffold(
      title: 'Settings',
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
        children: [
          AppCard(
            accent: auth.isPro ? AppColors.premium : AppColors.primary,
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    auth.isPro ? Icons.verified : Icons.person_outline,
                    color: auth.isPro ? AppColors.premium : AppColors.primary,
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (user?.displayName.isNotEmpty ?? false)
                            ? user!.displayName
                            : 'Fighter',
                        style: AppType.body(weight: FontWeight.w800),
                      ),
                      const SizedBox(height: Insets.xxs),
                      Text(
                        user?.email ?? 'Signed in',
                        style: AppType.subhead(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _PlanPill(label: auth.isPro ? 'PRO' : 'FREE'),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          const _SectionLabel('Subscription'),
          _SettingsRow(
            icon: Icons.workspace_premium_outlined,
            title: auth.isPro ? 'Manage Pro' : 'Upgrade to Pro',
            subtitle: auth.isPro
                ? 'Refresh status and manage billing once connected'
                : 'Unlock analytics, coaching loops, and full library access',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PaywallScreen()),
            ),
          ),
          const SizedBox(height: Insets.xl),
          const _SectionLabel('Training Preferences'),
          _SwitchRow(
            icon: Icons.straighten,
            title: 'Metric units',
            subtitle: state.useMetricUnits
                ? 'Weights show in kg'
                : 'Weights show in lb',
            value: state.useMetricUnits,
            onChanged: state.setUseMetricUnits,
          ),
          _SwitchRow(
            icon: Icons.vibration,
            title: 'Timer haptics',
            subtitle: 'Round alerts can use vibration feedback',
            value: state.timerHaptics,
            onChanged: state.setTimerHaptics,
          ),
          _SwitchRow(
            icon: Icons.notifications_active_outlined,
            title: 'Camp reminders',
            subtitle:
                'Reminder preference is saved; notification delivery comes next',
            value: state.campReminders,
            onChanged: state.setCampReminders,
          ),
          const SizedBox(height: Insets.xl),
          const _SectionLabel('Safety & Trust'),
          _SwitchRow(
            icon: Icons.health_and_safety_outlined,
            title: 'Safe cut guidance',
            subtitle: 'Show hydration and non-medical weight-cut reminders',
            value: state.safeCutGuidance,
            onChanged: state.setSafeCutGuidance,
          ),
          const _TrustCard(),
          const SizedBox(height: Insets.xl),
          const _SectionLabel('Account'),
          _SettingsRow(
            icon: Icons.lock_outline,
            title: 'Password & security',
            subtitle: 'Password reset is available from the login screen',
            onTap: () => _showInfo(
              context,
              'Security',
              'Password reset is already supported from the login screen. In-app password change should be added before public launch.',
            ),
          ),
          _SettingsRow(
            icon: Icons.description_outlined,
            title: 'Legal',
            subtitle: 'Terms, privacy, and medical disclaimer placeholders',
            onTap: () => _showInfo(
              context,
              'Legal readiness',
              'Before launch, connect real Terms, Privacy Policy, billing terms, and a non-medical training/nutrition disclaimer.',
            ),
          ),
          _SettingsRow(
            icon: Icons.delete_outline,
            title: 'Delete account',
            subtitle: 'Permanently erase your account and all of your data',
            onTap: auth.isBusy ? null : () => _confirmDeleteAccount(context),
          ),
          const SizedBox(height: Insets.lg),
          GhostButton(
            auth.isBusy ? 'Signing out...' : 'Sign out',
            icon: Icons.logout,
            expand: true,
            onPressed: auth.isBusy ? null : auth.signOut,
          ),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context, String title, String message) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppType.title1()),
            const SizedBox(height: Insets.sm),
            Text(
              message,
              style: AppType.subhead(color: AppColors.textSecondary),
            ),
            const SizedBox(height: Insets.lg),
            PrimaryButton(
              'Got it',
              expand: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<AuthController>().deleteAccount();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }
}

/// Requires typing DELETE before the button enables — a deliberate speed
/// bump for an irreversible action, not just a yes/no tap.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _confirmed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This permanently erases your account, weight history, training '
            'sessions, and nutrition data. This cannot be undone.',
            style: AppType.subhead(color: AppColors.textSecondary),
          ),
          const SizedBox(height: Insets.md),
          Text(
            'Type DELETE to confirm.',
            style: AppType.subhead(weight: FontWeight.w700),
          ),
          const SizedBox(height: Insets.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (v) => setState(() => _confirmed = v.trim() == 'DELETE'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _confirmed ? () => Navigator.of(context).pop(true) : null,
          style: TextButton.styleFrom(foregroundColor: AppColors.negative),
          child: const Text('Delete forever'),
        ),
      ],
    );
  }
}

class _PlanPill extends StatelessWidget {
  final String label;
  const _PlanPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 6),
      decoration: BoxDecoration(
        color: label == 'PRO'
            ? AppColors.premium.withValues(alpha: .16)
            : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(
            color: label == 'PRO' ? AppColors.premium : AppColors.primary),
      ),
      child: Text(
        label,
        style: AppType.micro(
          weight: FontWeight.w900,
          color: label == 'PRO' ? AppColors.premium : AppColors.primary,
          spacing: 1.1,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Text(
        label.toUpperCase(),
        style: AppType.micro(
          weight: FontWeight.w800,
          color: AppColors.textMuted,
          spacing: 1,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            _RowIcon(icon),
            const SizedBox(width: Insets.md),
            Expanded(child: _RowText(title: title, subtitle: subtitle)),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: AppCard(
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            _RowIcon(icon),
            const SizedBox(width: Insets.md),
            Expanded(child: _RowText(title: title, subtitle: subtitle)),
            Switch.adaptive(
              value: value,
              activeThumbColor: AppColors.primary,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  final IconData icon;
  const _RowIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: AppColors.primary, size: 21),
    );
  }
}

class _RowText extends StatelessWidget {
  final String title;
  final String subtitle;
  const _RowText({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppType.callout(weight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: AppType.subhead(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.warning,
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 22),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              'Fighter Edge should guide training decisions, not replace a coach, doctor, or licensed nutrition professional. Keep this visible before public launch.',
              style: AppType.subhead(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
