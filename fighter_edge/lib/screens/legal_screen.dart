import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../legal/legal_links.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';

/// The legal documents the app links to. The slug is the route segment.
enum LegalDocument {
  terms('terms', 'Terms of Service'),
  privacy('privacy', 'Privacy Policy');

  final String slug;
  final String title;
  const LegalDocument(this.slug, this.title);

  static LegalDocument? fromSlug(String? slug) {
    for (final doc in values) {
      if (doc.slug == slug) return doc;
    }
    return null;
  }
}

/// Shows one legal document.
///
/// The final texts have not been written yet, and inventing legal terms in
/// code would be worse than admitting that. So this says plainly that the
/// document is a draft, and is the one place to drop the real text into —
/// every link in the app (signup, Settings) already points here.
class LegalScreen extends StatelessWidget {
  final LegalDocument document;
  const LegalScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: document.title,
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, Insets.xxl),
        children: [
          const SizedBox(height: Insets.sm),
          Text(
            'Fighter Edge is in early access. The full ${document.title} '
            'will be published here before public launch.',
            style: AppType.body(color: AppAccessibility.textSecondary(context)),
          ),
          const SizedBox(height: Insets.lg),
          Text(
            'Fighter Edge guides training and nutrition decisions. It does not '
            'replace a coach, doctor, or licensed nutrition professional.',
            style: AppType.callout(color: AppColors.textSecondary),
          ),
          if (LegalLinks.hostedUrl(document) != null) ...[
            const SizedBox(height: Insets.lg),
            GhostButton(
              L.of(context).legalOpenPublished,
              icon: Icons.open_in_new,
              expand: true,
              onPressed: () => LegalLinks.open(context, document),
            ),
          ],
        ],
      ),
    );
  }
}
