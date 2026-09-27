import 'dart:io';

import 'package:fighter_edge/legal/legal_links.dart';
import 'package:fighter_edge/screens/legal_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the ethical guidelines are published next to the terms', () {
    expect(
      LegalLinks.siblingOf(
              Uri.parse('https://fighter-edge-app.web.app/terms'), 'ethics')
          .toString(),
      'https://fighter-edge-app.web.app/ethics',
    );
    expect(
      LegalLinks.siblingOf(
              Uri.parse('https://example.com/fighter-edge/terms?v=1#top'),
              'ethics')
          .toString(),
      'https://example.com/fighter-edge/ethics',
    );
    expect(LegalLinks.siblingOf(null, 'ethics'), isNull);
  });

  test('without build settings every document opens in the app', () {
    for (final doc in LegalDocument.values) {
      expect(LegalLinks.hostedUrl(doc), isNull, reason: doc.slug);
    }
  });

  test('every document the app links to is hosted in English and German', () {
    const german = {
      LegalDocument.terms: 'nutzungsbedingungen',
      LegalDocument.privacy: 'datenschutz',
      LegalDocument.ethics: 'ethik',
    };
    for (final doc in LegalDocument.values) {
      for (final path in [doc.slug, 'de/${german[doc]}']) {
        final page = File('hosting/public/$path/index.html');
        expect(page.existsSync(), isTrue, reason: page.path);
        final html = page.readAsStringSync();
        expect(html, contains('<link rel="stylesheet" href="/legal.css">'),
            reason: page.path);
        expect(html, isNot(contains('<script')), reason: 'pages stay static');
      }
    }
  });
}
