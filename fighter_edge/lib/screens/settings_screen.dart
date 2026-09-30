import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../ads/rewarded_ad_gateway.dart';
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
import '../widgets/grouped_list.dart';
import 'change_password_sheet.dart';
import 'delete_account_flow.dart';
import 'legal_screen.dart';
import 'paywall_screen.dart';
import '../legal/legal_links.dart';
import '../models/app_user.dart';
import '../privacy/ai_coach_consent.dart';
import '../privacy/consent.dart';
import '../privacy/data_consent.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final state = context.watch<AppState>();
    final reminders = context.watch<ReminderGateway>();
    final consent = context.watch<ConsentController>();
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
        padding: const EdgeInsets.fromLTRB(
            Insets.lg, Insets.none, Insets.lg, Insets.xxl),
        children: [
          GroupedList(children: [
            GroupedRow(
              title: user.displayName.isNotEmpty
                  ? user.displayName
                  : user.email.split('@').first,
              subtitle: user.email,
              trailing: Text(
                  auth.isPro ? l.settingsProPlan : l.settingsFreePlan,
                  style: AppType.subhead(
                      color: auth.isPro
                          ? AppColors.premium
                          : AppColors.textSecondary)),
            )
          ]),
          const SizedBox(height: Insets.xl),
          _SectionLabel(l.settingsSectionApp),
          GroupedList(children: [
            _SettingsRow(
              title: l.settingsLanguage,
              subtitle: _languageLabel(context, l),
              onTap: () => _pickLanguage(context),
            ),
          ]),
          const SizedBox(height: Insets.xl),
          _SectionLabel(l.settingsSectionSubscription),
          GroupedList(children: [
            _SettingsRow(
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
          ]),
          const SizedBox(height: Insets.xl),
          _SectionLabel(l.settingsSectionTraining),
          GroupedList(children: [
            _SwitchRow(
              title: l.settingsMetricUnits,
              subtitle: state.useMetricUnits
                  ? l.settingsMetricUnitsKg
                  : l.settingsMetricUnitsLb,
              value: state.useMetricUnits,
              onChanged: state.setUseMetricUnits,
            ),
            _SwitchRow(
              title: l.settingsTimerHaptics,
              subtitle: l.settingsTimerHapticsSubtitle,
              value: state.timerHaptics,
              onChanged: state.setTimerHaptics,
            ),
            _SwitchRow(
              title: l.settingsCampReminders,
              subtitle: !reminders.isAvailable
                  ? l.settingsCampRemindersUnavailable
                  : state.campReminders
                      ? l.settingsCampRemindersOn(
                          TrainingReminderSchedule.defaultTime.format(context))
                      : l.settingsCampRemindersOff,
              value: state.campReminders,
              onChanged: reminders.isAvailable
                  ? (value) =>
                      _setCampReminders(context, state, reminders, value)
                  : null,
            ),
          ]),
          const SizedBox(height: Insets.xl),
          _SectionLabel(l.settingsSectionSafety),
          GroupedList(children: [
            _SwitchRow(
              title: l.settingsSafeCut,
              subtitle: l.settingsSafeCutSubtitle,
              value: state.safeCutGuidance,
              onChanged: state.setSafeCutGuidance,
            ),
            const _TrustCard(),
          ]),
          const SizedBox(height: Insets.xl),
          _SectionLabel(l.settingsSectionPrivacy),
          GroupedList(children: [
            _SettingsRow(
              title: l.settingsHealthData,
              subtitle: _healthConsentSummary(context, user),
              onTap: auth.isBusy ? null : () => _withdrawHealthConsent(context),
            ),
            _SwitchRow(
              title: l.settingsAiCoach,
              subtitle: l.settingsAiCoachSubtitle,
              value: user.hasAiCoachConsent,
              onChanged: auth.isBusy
                  ? null
                  : (allowed) => allowed
                      ? showAiCoachConsentSheet(context)
                      : auth.setDataConsent(
                          DataConsentPurpose.aiCoach,
                          granted: false,
                        ),
            ),
            if (context.read<RewardedAdGateway>().privacyOptionsRequired)
              _SettingsRow(
                title: l.settingsAdPrivacy,
                subtitle: l.settingsAdPrivacySubtitle,
                onTap: () =>
                    context.read<RewardedAdGateway>().showPrivacyOptions(),
              ),
            _SwitchRow(
              title: l.settingsAnalytics,
              subtitle: l.settingsAnalyticsSubtitle,
              value: consent.analyticsAllowed,
              onChanged: consent.setAnalytics,
            ),
            _SwitchRow(
              title: l.settingsCrashReports,
              subtitle: l.settingsCrashReportsSubtitle,
              value: consent.crashReportsAllowed,
              onChanged: consent.setCrashReports,
            ),
          ]),
          const SizedBox(height: Insets.xl),
          _SectionLabel(l.settingsSectionAccount),
          GroupedList(children: [
            _SettingsRow(
              title: l.settingsChangePassword,
              subtitle: auth.canChangePassword
                  ? l.settingsChangePasswordSubtitle
                  : l.settingsChangePasswordGoogle,
              onTap: auth.isBusy ? null : () => _changePassword(context),
            ),
            _SettingsRow(
              title: l.settingsTerms,
              subtitle: l.settingsTermsSubtitle,
              onTap: () => _openLegal(context, LegalDocument.terms),
            ),
            _SettingsRow(
              title: l.settingsPrivacy,
              subtitle: l.settingsPrivacySubtitle,
              onTap: () => _openLegal(context, LegalDocument.privacy),
            ),
            _SettingsRow(
              title: l.settingsEthics,
              subtitle: l.settingsEthicsSubtitle,
              onTap: () => _openLegal(context, LegalDocument.ethics),
            ),
            _SettingsRow(
              title: l.settingsDeleteAccount,
              subtitle: l.settingsDeleteAccountSubtitle,
              onTap:
                  auth.isBusy ? null : () => confirmAndDeleteAccount(context),
            ),
          ]),
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

  String _healthConsentSummary(BuildContext context, AppUser user) {
    final l = L.of(context);
    final at =
        user.consents.recordFor(DataConsentPurpose.healthData)?.grantedAt;
    if (at == null) return l.settingsHealthDataGrantedNoDate;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return l.settingsHealthDataGranted(DateFormat.yMMMd(locale).format(at));
  }

  /// The app can't work without health data, so withdrawing that consent
  /// is deleting the account (as the Privacy Policy says). The dialog says
  /// so plainly before handing over to the usual typed confirmation.
  Future<void> _withdrawHealthConsent(BuildContext context) async {
    final l = L.of(context);
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.settingsHealthDataWithdrawTitle),
        content: Text(
          l.settingsHealthDataWithdrawBody,
          style: AppType.subhead(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: Text(l.settingsHealthDataWithdrawConfirm),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;
    await confirmAndDeleteAccount(context);
  }

  void _openLegal(BuildContext context, LegalDocument doc) {
    LegalLinks.open(context, doc);
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
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Text(
        label,
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
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _SettingsRow(
      {required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) =>
      GroupedRow(title: title, subtitle: subtitle, onTap: onTap);
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _SwitchRow(
      {required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => GroupedRow(
      title: title,
      subtitle: subtitle,
      trailing: Semantics(
          label: title,
          child: Switch.adaptive(
              value: value,
              activeTrackColor: AppColors.textSecondary,
              onChanged: onChanged)));
}

class _TrustCard extends StatelessWidget {
  const _TrustCard();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Text(L.of(context).settingsTrustNote,
            style: AppType.subhead(
                color: AppAccessibility.textSecondary(context))),
      );
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
            padding: const EdgeInsets.fromLTRB(
                Insets.xl, Insets.none, Insets.xl, Insets.sm),
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
