import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/theme/app_colors.dart';
import 'package:fighter_edge/widgets/brand_logo.dart';

import '../helpers/test_harness.dart';

double _tagline(WidgetTester tester) {
  final opacity = tester.widget<Opacity>(find
      .ancestor(
        of: find.text('YOUR EDGE. EVERY DAY.'),
        matching: find.byType(Opacity),
      )
      .first);
  return opacity.opacity;
}

void main() {
  group('Splash', () {
    testWidgets('shows the mark on the first frame and settles the name in',
        (tester) async {
      final repo = await makeRepo(signedIn: false);
      await tester.pumpWidget(wrapApp(const BrandSplash(), repo: repo));

      // First frame: the mark is already there, the name is not yet.
      expect(find.byType(BrandMark), findsOneWidget);
      final markAtStart = tester.getCenter(find.byType(BrandMark));
      expect(_tagline(tester), 0);

      await tester.pump(const Duration(milliseconds: 450));
      expect(_tagline(tester), inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 600));
      expect(_tagline(tester), 1);
      expect(find.text('YOUR EDGE. EVERY DAY.'), findsOneWidget);

      // The mark never moves: it stays where the native splash puts it.
      expect(tester.getCenter(find.byType(BrandMark)), markAtStart);
      final screen = tester.getSize(find.byType(Scaffold));
      expect(markAtStart, Offset(screen.width / 2, screen.height / 2));
    });

    testWidgets('a repeat showing is the finished picture, with no entrance',
        (tester) async {
      final repo = await makeRepo(signedIn: false);
      await tester
          .pumpWidget(wrapApp(const BrandSplash(animate: false), repo: repo));
      expect(_tagline(tester), 1);
    });

    testWidgets('reduced motion skips the entrance', (tester) async {
      final repo = await makeRepo(signedIn: false);
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: wrapApp(const BrandSplash(), repo: repo),
      ));
      expect(_tagline(tester), 1);
    });

    testWidgets('uses exactly the native splash colour', (tester) async {
      final repo = await makeRepo(signedIn: false);
      await tester.pumpWidget(wrapApp(const BrandSplash(), repo: repo));
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          AppColors.background);
      // pubspec.yaml's flutter_native_splash.color, which paints the native
      // splash, must be this same colour.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final hex =
          RegExp(r'flutter_native_splash:\s+(?:#.*\s+)*color: "#(\w{6})"')
              .firstMatch(pubspec)!
              .group(1)!;
      expect(
          Color(0xFF000000 | int.parse(hex, radix: 16)), AppColors.background);
    });

    testWidgets('fits a small phone at 200% text without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = await makeRepo(signedIn: false);
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2),
        ),
        child: wrapApp(const BrandSplash(animate: false), repo: repo),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    test('the mark is half the shorter side, within limits', () {
      expect(BrandSplash.markSize(const Size(390, 844)), 195);
      expect(BrandSplash.markSize(const Size(200, 400)), 160);
      expect(BrandSplash.markSize(const Size(1000, 1200)), 240);
    });
  });

  group('Brand assets', () {
    test('the mark loads', () async {
      final data = await rootBundle.load(BrandMark.asset);
      expect(data.lengthInBytes, greaterThan(10000));
      await BrandMark.preload();
    });

    test('the native splash and icons were built from the logo', () {
      // Sizes the generators expect (see tool/brand/build_assets.py).
      expect(_pngSize('assets/brand/splash.png'), (1152, 1152));
      expect(_pngSize('assets/brand/logo_mark.png'), (1024, 1024));
      expect(_pngSize('assets/icon/icon.png'), (1024, 1024));
      expect(_pngSize('assets/icon/foreground.png'), (1024, 1024));
    });

    test('the launcher icon is opaque, as the stores require', () {
      // PNG colour type 2 is RGB with no alpha channel.
      final header = File('assets/icon/icon.png').readAsBytesSync();
      expect(header[25], 2);
    });
  });
}

(int, int) _pngSize(String path) {
  final b = File(path).readAsBytesSync();
  int u32(int o) =>
      (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
  return (u32(16), u32(20));
}
