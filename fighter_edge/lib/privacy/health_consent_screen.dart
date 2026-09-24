import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../l10n/gen/app_localizations.dart';
import '../legal/legal_links.dart';
import '../screens/delete_account_flow.dart';
import '../screens/legal_screen.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/premium_effects.dart';
import '../widgets/primary_button.dart';
import '../widgets/stat_card.dart';
import 'data_consent.dart';

/// Asks for explicit consent to process health data (Art. 9(2)(a) GDPR)
/// before the app collects any of it: new accounts see it before onboarding
/// asks for body data, and accounts created before it existed see it once
/// before the home screen.
///
/// There is no "continue without" path, because every plan is built from
/// this data. Declining is still one tap: sign out, or, for an account that
/// already holds data, delete it.
class HealthConsentScreen extends StatelessWidget {
  /// Whether the account may already hold health data (it finished setup
  /// before this screen existed), so deleting it is offered.
  final bool existingAccount;

  const HealthConsentScreen({super.key, this.existingAccount = false});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final auth = context.watch<AuthController>();
    final secondary = AppAccessibility.textSecondary(context);

    return Scaffold(
      key: const ValueKey('health-consent-screen'),
      backgroundColor: AppColors.background,
      body: PremiumBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                Insets.lg, Insets.xl, Insets.lg, Insets.xxl),
            children: [
              Icon(Icons.health_and_safety_outlined,
                  size: 40, color: AppAccessibility.accentText(context)),
              const SizedBox(height: Insets.md),
              Semantics(
                header: true,
                child: Text(l.healthConsentTitle, style: AppType.title1()),
              ),
              const SizedBox(height: Insets.sm),
              Text(l.healthConsentIntro, style: AppType.body(color: secondary)),
              const SizedBox(height: Insets.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Point(
                      title: l.healthConsentWhatTitle,
                      body: l.healthConsentWhat,
                    ),
                    _Point(
                      title: l.healthConsentWhyTitle,
                      body: l.healthConsentWhy,
                    ),
                    _Point(
                      title: l.healthConsentWhereTitle,
                      body: l.healthConsentWhere,
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.md),
              Text(
                l.healthConsentWithdraw,
                style: AppType.subhead(color: secondary),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () =>
                      LegalLinks.open(context, LegalDocument.privacy),
                  child: Text(l.legalPrivacyLink),
                ),
              ),
              const SizedBox(height: Insets.md),
              Text(
                l.healthConsentStatement,
                style: AppType.subhead(weight: FontWeight.w700),
              ),
              const SizedBox(height: Insets.md),
              PrimaryButton(
                l.healthConsentAgree,
                icon: Icons.check,
                expand: true,
                onPressed: auth.isBusy
                    ? null
                    : () => auth.setDataConsent(
                          DataConsentPurpose.healthData,
                          granted: true,
                        ),
              ),
              const SizedBox(height: Insets.sm),
              GhostButton(
                l.healthConsentSignOut,
                icon: Icons.logout,
                expand: true,
                onPressed: auth.isBusy ? null : auth.signOut,
              ),
              if (existingAccount) ...[
                const SizedBox(height: Insets.sm),
                TextButton(
                  onPressed: auth.isBusy
                      ? null
                      : () => confirmAndDeleteAccount(context),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.negative),
                  child: Text(l.healthConsentDeleteAccount),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final String title;
  final String body;
  final bool last;

  const _Point({required this.title, required this.body, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppType.headline()),
          const SizedBox(height: Insets.xs),
          Text(
            body,
            style:
                AppType.subhead(color: AppAccessibility.textSecondary(context)),
          ),
        ],
      ),
    );
  }
}
