import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../l10n/gen/app_localizations.dart';
import '../legal/legal_links.dart';
import '../screens/legal_screen.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/primary_button.dart';
import 'data_consent.dart';

/// Says exactly what the AI coach sends, and to whom, and asks for explicit
/// consent before the first request. The server refuses AI requests from an
/// account without this consent, so the app can't skip it.
///
/// Keep the wording in step with section 2.3 of the Privacy Policy
/// (`hosting/public/privacy`): if the providers change, both change, and
/// [DataConsentPurpose.aiCoach]'s version goes up so everyone is asked again.
class AiCoachConsentPanel extends StatelessWidget {
  /// Called after consent is recorded, e.g. to close a sheet.
  final VoidCallback? onAgreed;

  const AiCoachConsentPanel({super.key, this.onAgreed});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final auth = context.watch<AuthController>();
    final secondary = AppAccessibility.textSecondary(context);

    return Column(
      key: const ValueKey('ai-coach-consent'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l.aiConsentTitle, style: AppType.title2()),
        ),
        const SizedBox(height: Insets.md),
        Text(l.aiConsentBody, style: AppType.body(color: secondary)),
        const SizedBox(height: Insets.sm),
        Text(l.aiConsentRetention, style: AppType.subhead(color: secondary)),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => LegalLinks.open(context, LegalDocument.privacy),
            child: Text(l.legalPrivacyLink),
          ),
        ),
        Text(
          l.aiConsentStatement,
          style: AppType.subhead(weight: FontWeight.w700),
        ),
        const SizedBox(height: Insets.md),
        PrimaryButton(
          l.aiConsentAgree,
          icon: Icons.check,
          expand: true,
          onPressed: auth.isBusy
              ? null
              : () async {
                  await auth.setDataConsent(
                    DataConsentPurpose.aiCoach,
                    granted: true,
                  );
                  onAgreed?.call();
                },
        ),
        const SizedBox(height: Insets.sm),
        Text(
          l.aiConsentChangeLater,
          style: AppType.micro(color: AppAccessibility.textMuted(context)),
        ),
      ],
    );
  }
}

/// The same disclosure as a sheet, for turning the consent back on from
/// Settings. Dismissing it leaves the consent off.
Future<void> showAiCoachConsentSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceElevated,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.xl),
        child: AiCoachConsentPanel(
          onAgreed: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    ),
  );
}
