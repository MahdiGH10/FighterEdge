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
}
