import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../routing/app_navigation.dart';
import '../routing/app_router.dart';
import '../screens/legal_screen.dart';

/// Where each legal document is published.
///
/// Supplied at build time so the text can change without an app release:
/// `--dart-define=TERMS_URL=https://… --dart-define=PRIVACY_URL=https://…`.
/// App Review (3.1.2) and Google Play require working links to both next to
/// any subscription offer, so release builds must set them (CI checks).
class LegalLinks {
  LegalLinks._();

  static const _terms = String.fromEnvironment('TERMS_URL');
  static const _privacy = String.fromEnvironment('PRIVACY_URL');

  static Uri? hostedUrl(LegalDocument doc) => switch (doc) {
        LegalDocument.terms => _parse(_terms),
        LegalDocument.privacy => _parse(_privacy),
        // Published next to the terms (hosting/public/ethics), so it needs
        // no build setting of its own.
        LegalDocument.ethics => siblingOf(_parse(_terms), doc.slug),
      };

  /// The page [slug] in the same folder as [page]:
  /// `https://x.web.app/terms` gives `https://x.web.app/ethics`.
  @visibleForTesting
  static Uri? siblingOf(Uri? page, String slug) => page?.resolve(slug);

  static Uri? _parse(String raw) {
    final uri = raw.isEmpty ? null : Uri.tryParse(raw);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty ? uri : null;
  }

  /// Opens the published document, or the in-app page when no URL was
  /// configured for this build (or the browser could not be opened).
  static Future<void> open(BuildContext context, LegalDocument doc) async {
    final url = hostedUrl(doc);
    if (url != null) {
      try {
        if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
      } catch (_) {
        // Fall through to the in-app page.
      }
    }
    if (!context.mounted) return;
    await AppNavigation.push<void>(
      context,
      AppRoutes.legal(doc),
      fallbackBuilder: (_) => LegalScreen(document: doc),
    );
  }
}
