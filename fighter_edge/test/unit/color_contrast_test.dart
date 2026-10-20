import 'dart:math' as math;
import 'dart:ui';

import 'package:fighter_edge/theme/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the contrast promises written into `app_colors.dart`.
///
/// Every token that file documents as "text-safe" must clear the WCAG AA 4.5:1
/// floor for normal-sized text against the lightest surface text actually sits
/// on. Doc comments drift; this does not.

/// WCAG relative luminance. Alpha is ignored — these are opaque foregrounds.
double _luminance(Color c) {
  double channel(double v) {
    final s = v; // already 0..1
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color fg, Color bg) {
  final a = _luminance(fg);
  final b = _luminance(bg);
  final lighter = math.max(a, b);
  final darker = math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  // The lightest surface body text renders on. Passing here implies passing on
  // every darker surface in the ramp.
  const bg = AppColors.surfaceElevated;

  group('tokens documented text-safe clear WCAG AA (4.5:1)', () {
    const textSafe = <String, Color>{
      'accentText': AppColors.accentText,
      'textPrimary': AppColors.textPrimary,
      'textSecondary': AppColors.textSecondary,
      'crimson50': AppColors.crimson50,
      'crimson100': AppColors.crimson100,
      'crimson200': AppColors.crimson200,
      'crimson300': AppColors.crimson300,
      'crimson400': AppColors.crimson400,
      'ember50': AppColors.ember50,
      'ember100': AppColors.ember100,
      'ember200': AppColors.ember200,
      'ember300': AppColors.ember300,
      'ember400': AppColors.ember400,
      'emberSoft': AppColors.emberSoft,
      'textMuted': AppColors.textMuted,
      'positiveStrong': AppColors.positiveStrong,
      'warningStrong': AppColors.warningStrong,
      'negativeStrong': AppColors.negativeStrong,
      'infoStrong': AppColors.infoStrong,
      'premiumStrong': AppColors.premiumStrong,
    };

    textSafe.forEach((name, color) {
      test('$name on surfaceElevated', () {
        final ratio = _contrast(color, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name measures ${ratio.toStringAsFixed(2)}:1, '
              'below the 4.5:1 AA floor it is documented to clear.',
        );
      });
    });
  });

  group('chart series are all readable as their own labels', () {
    test('every series colour clears AA on surfaceElevated', () {
      for (var i = 0; i < AppColors.chartSeries.length; i++) {
        final ratio = _contrast(AppColors.chartSeries[i], bg);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'chartSeries[$i] measures ${ratio.toStringAsFixed(2)}:1.',
        );
      }
    });

    test('adjacent series are distinguishable from each other', () {
      // Neighbouring series sit side by side in legends and stacked bars, so
      // they need separation from each other, not just from the background.
      for (var i = 1; i < AppColors.chartSeries.length; i++) {
        final ratio =
            _contrast(AppColors.chartSeries[i - 1], AppColors.chartSeries[i]);
        expect(
          ratio,
          greaterThan(1.2),
          reason: 'chartSeries[${i - 1}] and chartSeries[$i] are too close '
              '(${ratio.toStringAsFixed(2)}:1).',
        );
      }
    });
  });

  group('documented non-text tokens stay honest', () {
    test('primary is NOT text-safe, which is why accentText exists', () {
      // If this ever starts passing, the accentText token has become redundant
      // and the comment in app_colors.dart is wrong.
      expect(_contrast(AppColors.primary, bg), lessThan(4.5));
    });
  });

  group('ramp aliases match the roles they document', () {
    test('neutral ramp aliases are exact', () {
      expect(AppColors.neutral0, AppColors.textPrimary);
      expect(AppColors.neutral100, AppColors.textSecondary);
      expect(AppColors.neutral200, AppColors.textMuted);
      expect(AppColors.neutral500, AppColors.borderStrong);
      expect(AppColors.neutral600, AppColors.border);
      expect(AppColors.neutral700, AppColors.surfaceElevated);
      expect(AppColors.neutral800, AppColors.surfaceAlt);
      expect(AppColors.neutral850, AppColors.surface);
      expect(AppColors.neutral900, AppColors.backgroundRaised);
      expect(AppColors.neutral950, AppColors.background);
    });

    test('crimson500 is the brand red', () {
      expect(AppColors.crimson500, AppColors.primary);
    });

    test('ember ramp gets monotonically darker', () {
      const ramp = [
        AppColors.ember50,
        AppColors.ember100,
        AppColors.ember200,
        AppColors.ember300,
        AppColors.ember400,
        AppColors.ember500,
        AppColors.ember600,
        AppColors.ember700,
        AppColors.ember800,
        AppColors.ember900,
      ];
      for (var i = 1; i < ramp.length; i++) {
        expect(
          _luminance(ramp[i]),
          lessThan(_luminance(ramp[i - 1])),
          reason: 'ember ramp step $i is not darker than step ${i - 1}.',
        );
      }
    });

    test('accent aliases point at the ramps', () {
      expect(AppColors.accentText, AppColors.crimson400);
      expect(AppColors.primaryFill, AppColors.crimson600);
      expect(AppColors.emberSoft, AppColors.ember300);
      expect(AppColors.ember, AppColors.ember500);
    });

    test('neutral ramp gets monotonically darker', () {
      const ramp = [
        AppColors.neutral0,
        AppColors.neutral50,
        AppColors.neutral100,
        AppColors.neutral200,
        AppColors.neutral300,
        AppColors.neutral400,
        AppColors.neutral500,
        AppColors.neutral600,
        AppColors.neutral700,
        AppColors.neutral800,
        AppColors.neutral850,
        AppColors.neutral900,
        AppColors.neutral950,
      ];
      for (var i = 1; i < ramp.length; i++) {
        expect(
          _luminance(ramp[i]),
          lessThan(_luminance(ramp[i - 1])),
          reason: 'neutral ramp step $i is not darker than step ${i - 1}.',
        );
      }
    });

    test('crimson ramp gets monotonically darker', () {
      const ramp = [
        AppColors.crimson50,
        AppColors.crimson100,
        AppColors.crimson200,
        AppColors.crimson300,
        AppColors.crimson400,
        AppColors.crimson500,
        AppColors.crimson600,
        AppColors.crimson700,
        AppColors.crimson800,
        AppColors.crimson900,
      ];
      for (var i = 1; i < ramp.length; i++) {
        expect(
          _luminance(ramp[i]),
          lessThan(_luminance(ramp[i - 1])),
          reason: 'crimson ramp step $i is not darker than step ${i - 1}.',
        );
      }
    });
  });

  group('text over glass is judged at the brightest case', () {
    // The text roles of the design system board, by name.
    const roles = <String, Color>{
      'Text': AppColors.textPrimary,
      'Text 2': AppColors.textSecondary,
      'Text 3': AppColors.textMuted,
      'Accent text': AppColors.accentText,
      'Ember soft': AppColors.emberSoft,
      'Gold': AppColors.premium,
      'Done green': AppColors.positive,
      'Danger': AppColors.negative,
    };

    // What the rule must come out as. A token change that flips a cell has to
    // flip this table on purpose.
    const smallTextOnGlass = <GlassKind, Set<String>>{
      GlassKind.hero: {'Text', 'Text 2', 'Ember soft', 'Gold', 'Done green'},
      GlassKind.heroGold: {'Text', 'Text 2', 'Gold'},
      GlassKind.nav: {
        'Text',
        'Text 2',
        'Text 3',
        'Accent text',
        'Ember soft',
        'Gold',
        'Done green',
        'Danger',
      },
      GlassKind.sheet: {'Text', 'Text 2', 'Ember soft', 'Gold', 'Done green'},
    };

    for (final kind in GlassKind.values) {
      final backdrop = GlassColors.worstCaseBackdrop(kind);
      roles.forEach((name, color) {
        final expectAllowed = smallTextOnGlass[kind]!.contains(name);
        test('$name on ${kind.name} glass at its brightest', () {
          final ratio = _contrast(color, backdrop);
          expect(GlassColors.allowsText(kind, color), expectAllowed,
              reason: '$name measures ${ratio.toStringAsFixed(2)}:1.');
          if (expectAllowed) {
            expect(ratio, greaterThanOrEqualTo(4.5));
          } else {
            expect(ratio, lessThan(4.5));
          }
        });
      });
    }

    test('18px bold text may use the roles small text may not (hero, sheet)',
        () {
      for (final kind in [GlassKind.hero, GlassKind.sheet]) {
        for (final name in ['Text 3', 'Accent text', 'Danger']) {
          expect(
            GlassColors.allowsText(kind, roles[name]!, largeBold: true),
            isTrue,
            reason: '$name at 18px bold on ${kind.name}: '
                '${_contrast(roles[name]!, GlassColors.worstCaseBackdrop(kind)).toStringAsFixed(2)}:1',
          );
        }
      }
    });

    test('the gold hero is stricter: Danger fails even at 18px bold', () {
      expect(
        GlassColors.allowsText(GlassKind.heroGold, AppColors.negative,
            largeBold: true),
        isFalse,
      );
      expect(
        GlassColors.allowsText(GlassKind.heroGold, AppColors.negative),
        isFalse,
      );
    });

    test('text() hands back an allowed colour untouched', () {
      expect(GlassColors.text(GlassKind.hero, AppColors.emberSoft),
          AppColors.emberSoft);
      expect(
          GlassColors.text(GlassKind.hero, AppColors.negative, largeBold: true),
          AppColors.negative);
    });

    test('text() refuses a disallowed colour in debug builds', () {
      expect(
        () => GlassColors.text(GlassKind.hero, AppColors.accentText),
        throwsAssertionError,
      );
    });

    test('the near-opaque fills used without blur are no worse than blurred',
        () {
      final navTinted =
          Color.alphaBlend(GlassColors.navFillTinted, AppColors.ember);
      final sheetTinted =
          Color.alphaBlend(GlassColors.sheetFillTinted, AppColors.ember);
      for (final entry in roles.entries) {
        expect(_contrast(entry.value, navTinted), greaterThanOrEqualTo(4.5),
            reason: '${entry.key} on nav, tinted level');
        expect(_contrast(entry.value, sheetTinted), greaterThanOrEqualTo(4.5),
            reason: '${entry.key} on sheet, tinted level');
      }
    });

    test('every text role clears AA on the solid fallbacks', () {
      for (final kind in GlassKind.values) {
        final solid = GlassColors.solidFill(kind);
        for (final entry in roles.entries) {
          expect(_contrast(entry.value, solid), greaterThanOrEqualTo(4.5),
              reason: '${entry.key} on the ${kind.name} solid fallback');
        }
      }
    });

    test('white on the primary button fill and on primary clears AA', () {
      expect(_contrast(AppColors.onPrimary, AppColors.primaryFill),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(AppColors.onPrimary, AppColors.primary),
          greaterThanOrEqualTo(4.5));
    });
  });
}
