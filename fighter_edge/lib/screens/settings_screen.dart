import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../notifications/reminder_gateway.dart';
import '../notifications/training_reminder_schedule.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_haptics.dart';
import '../routing/app_navigation.dart';
import '../routing/app_router.dart';
import '../state/app_state.dart';
import '../state/locale_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';
import '../widgets/stat_card.dart';
import 'change_password_sheet.dart';
import 'legal_screen.dart';
import 'paywall_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final state = context.watch<AppState>();
    final reminders = context.watch<ReminderGateway>();
    final user = auth.user;

    // Signing out or deleting the account makes the router take this page
    // away, but it is still on screen for the length of its exit transition.
    // Render nothing account-shaped in that window rather than a placeholder
    // identity that looks like someone is still signed in.
    final l = L.of(context);
    if (user == null) {
      return ScreenScaffold(
        title: l.settingsTitle,
        showBack: false,
        body: const SizedBox.shrink(),
      );
    }

    return ScreenScaffold(
      title: l.settingsTitle,
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
                        user.displayName.isNotEmpty
                            ? user.displayName
                            : user.email.split('@').first,
                        style: AppType.body(weight: FontWeight.w800),
                      ),
                      const SizedBox(height: Insets.xxs),
                      Text(
                        user.email,
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
          _SectionLabel(l.settingsSectionApp),
          _SettingsRow(
            icon: Icons.translate,
            title: l.settingsLanguage,
            subtitle: _languageLabel(context, l),
            onTap: () => _pickLanguage(context),
          ),
          const SizedBox(height: Insets.xl),
          _SectionLabel(l.settingsSectionSubscription),
          _SettingsRow(
            icon: Icons.workspace_premium_outlined,
            title: auth.isPro ? l.settingsManagePro : l.settingsUpgradePro,
            subtitle: auth.isPro
                ? l.settingsManageProSubtitle
                : l.settingsUpgradeProSubtitle,
            onTap: () => AppNavigation.push(
              context,
              AppRoutes.paywall,
              extra: const PaywallRouteArgs(trigger: PaywallTrigger.settings),
              fallbackBuilder: (_) => const PaywallScreen(
                trigger: PaywallTrigger.settings,
              ),
            ),
          ),
          const SizedBox(height: Insets.xl),
          _SectionLabel(l.settingsSectionTraining),
          _SwitchRow(
            icon: Icons.straighten,
            title: l.settingsMetricUnits,
            subtitle: state.useMetricUnits
                ? l.settingsMetricUnitsKg
                : l.settingsMetricUnitsLb,
            value: state.useMetricUnits,
            onChanged: state.setUseMetricUnits,
          ),
          _SwitchRow(
            icon: Icons.vibration,
            title: l.settingsTimerHaptics,
            subtitle: l.settingsTimerHapticsSubtitle,
            value: state.timerHaptics,
            onChanged: state.setTimerHaptics,
          ),
          _SwitchRow(
            icon: Icons.notifications_active_outlined,
            title: l.settingsCampReminders,
            subtitle: !reminders.isAvailable
                ? l.settingsCampRemindersUnavailable
                : state.campReminders
                    ? l.settingsCampRemindersOn(
                        TrainingReminderSchedule.defaultTime.format(context))
                    : l.settingsCampRemindersOff,
            value: state.campReminders,
            onChanged: reminders.isAvailable
                ? (value) => _setCampReminders(context, state, reminders, value)
                : null,
          ),
          const SizedBox(height: Insets.xl),
          _SectionLabel(l.settingsSectionSafety),
          _SwitchRow(
            icon: Icons.health_and_safety_outlined,
            title: l.settingsSafeCut,
            subtitle: l.settingsSafeCutSubtitle,
            value: state.safeCutGuidance,
            onChanged: state.setSafeCutGuidance,
          ),
          const _TrustCard(),
          const SizedBox(height: Insets.xl),
          _SectionLabel(l.settingsSectionAccount),
          _SettingsRow(
            icon: Icons.lock_outline,
            title: l.settingsChangePassword,
            subtitle: auth.canChangePassword
                ? l.settingsChangePasswordSubtitle
                : l.settingsChangePasswordGoogle,
            onTap: auth.isBusy ? null : () => _changePassword(context),
          ),
          _SettingsRow(
            icon: Icons.description_outlined,
            title: l.settingsTerms,
            subtitle: l.settingsTermsSubtitle,
            onTap: () => _openLegal(context, LegalDocument.terms),
          ),
          _SettingsRow(
            icon: Icons.privacy_tip_outlined,
            title: l.settingsPrivacy,
            subtitle: l.settingsPrivacySubtitle,
            onTap: () => _openLegal(context, LegalDocument.privacy),
          ),
          _SettingsRow(
            icon: Icons.delete_outline,
            title: l.settingsDeleteAccount,
            subtitle: l.settingsDeleteAccountSubtitle,
            onTap: auth.isBusy ? null : () => _confirmDeleteAccount(context),
          ),
          const SizedBox(height: Insets.lg),
          GhostButton(
            auth.isBusy ? l.commonSigningOut : l.commonSignOut,
            icon: Icons.logout,
            expand: true,
            onPressed: auth.isBusy ? null : auth.signOut,
          ),
        ],
      ),
    );
  }

  /// Turning reminders on asks for permission first — a switch that looks
  /// on while the OS is silently refusing every notification would be worse
  /// than not offering the feature. Denied permission flips the switch back
  /// off rather than leaving it lit with nothing behind it.
  Future<void> _setCampReminders(
    BuildContext context,
    AppState state,
    ReminderGateway reminders,
    bool enabled,
  ) async {
    if (!enabled) {
      await state.setCampReminders(false);
      await reminders.cancelAll();
      return;
    }
    final granted = await reminders.requestPermission();
    if (!granted) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Notifications are turned off for Fighter Edge. Enable them in '
          'your device settings to get camp reminders.',
        ),
      ));
      return;
    }
    await state.setCampReminders(true);
    await reminders.scheduleTrainingReminders(
      weekdays: TrainingReminderSchedule.weekdaysFor(state.sessions),
      time: TrainingReminderSchedule.defaultTime,
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final auth = context.read<AuthController>();
    if (!auth.canChangePassword) {
      _showInfo(
        context,
        'Signed in with Google',
        'This account has no Fighter Edge password. Your Google account '
            'handles sign-in, so change your password there.',
      );
      return;
    }
    final changed = await showChangePasswordSheet(context);
    if (!changed || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password updated.')),
    );
  }

  void _openLegal(BuildContext context, LegalDocument doc) {
    AppNavigation.push(
      context,
      AppRoutes.legal(doc),
      fallbackBuilder: (_) => LegalScreen(document: doc),
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
  final ValueChanged<bool>? onChanged;

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
              L.of(context).settingsTrustNote,
              style: AppType.subhead(
                  color: AppAccessibility.textSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }
}

String _languageLabel(BuildContext context, L l) {
  final locale = context.watch<LocaleController>().locale;
  return switch (locale?.languageCode) {
    'de' => l.settingsLanguageGerman,
    'en' => l.settingsLanguageEnglish,
    _ => l.settingsLanguageSystem,
  };
}

/// Language choices, in the language they name — someone looking for
/// "Deutsch" should not have to read English to find it.
Future<void> _pickLanguage(BuildContext context) async {
  final controller = context.read<LocaleController>();
  final l = L.of(context);
  final current = controller.locale?.languageCode;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, Insets.sm),
            child: Text(l.settingsLanguage, style: AppType.title1()),
          ),
          for (final option in [
            (null, l.settingsLanguageSystem),
            ('en', l.settingsLanguageEnglish),
            ('de', l.settingsLanguageGerman),
          ])
            _LanguageOption(
              label: option.$2,
              selected: current == option.$1,
              onTap: () {
                AppHaptics.selection();
                controller
                    .setLocale(option.$1 == null ? null : Locale(option.$1!));
                Navigator.of(sheetContext).pop();
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.xl, Insets.sm, Insets.xl, Insets.lg),
            child: Text(
              l.settingsLanguageBeta,
              style: AppType.subhead(
                  color: AppAccessibility.textSecondary(context)),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: AppAccessibility.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.xl, vertical: Insets.md),
            child: Row(
              children: [
                Expanded(child: Text(label, style: AppType.body())),
                if (selected)
                  const Icon(Icons.check, color: AppColors.accentText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
