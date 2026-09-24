import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../legal/legal_links.dart';
import '../screens/legal_screen.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/primary_button.dart';
import 'consent.dart';

/// Asks once for analytics and crash-report consent.
///
/// Allow and decline are the same size and the same one tap, and the sheet
/// cannot be swiped away undecided: silence is not consent, and declining
/// must be as easy as allowing.
Future<void> showConsentSheet(
  BuildContext context,
  ConsentController consent,
) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceElevated,
    builder: (sheetContext) => _ConsentSheet(consent: consent),
  );
}

class _ConsentSheet extends StatelessWidget {
  final ConsentController consent;
  const _ConsentSheet({required this.consent});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    void decide(ConsentChoices choices) {
      consent.decide(choices);
      Navigator.of(context).pop();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          key: const ValueKey('consent-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.consentTitle, style: AppType.title2()),
            const SizedBox(height: Insets.md),
            Text(
              l.consentBody,
              style:
                  AppType.body(color: AppAccessibility.textSecondary(context)),
            ),
            const SizedBox(height: Insets.sm),
            TextButton(
              onPressed: () => LegalLinks.open(context, LegalDocument.privacy),
              child: Text(l.legalPrivacyLink),
            ),
            const SizedBox(height: Insets.md),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    l.consentDecline,
                    expand: true,
                    onPressed: () => decide(ConsentChoices.none),
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: GhostButton(
                    l.consentAllow,
                    expand: true,
                    onPressed: () => decide(ConsentChoices.all),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            Text(
              l.consentChangeLater,
              style: AppType.micro(color: AppAccessibility.textMuted(context)),
            ),
          ],
        ),
      ),
    );
  }
}
