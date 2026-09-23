import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The FIGHTER EDGE type scale.
///
/// Ten semantic roles replace the 21 arbitrary sizes the app used to pass in at
/// each call site. Call sites ask for a *role* — never a number — so hierarchy
/// stays consistent when a screen changes.
///
/// Two families, two ladders:
///   Oswald (condensed, uppercase-friendly) carries the brand voice — titles,
///   hero numerals. Its `wght` axis stops at 700, which is the weight every
///   display role uses.
///   Inter carries everything readable. Its `opsz` (optical size) axis is set
///   per role: Flutter maps `FontWeight` onto `wght` automatically but never
///   touches `opsz`, so without this every size rendered with letterforms drawn
///   for 14px captions.
class AppType {
  AppType._();

  // Axis ranges read from the shipped font binaries — values outside these are
  // synthesized by the rasterizer rather than drawn by the font.
  static const double _interOpszMin = 14;
  static const double _interOpszMax = 32;

  static TextStyle _oswald(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color? color,
    double? spacing,
    double height = 1.05,
  }) {
    return TextStyle(
      fontFamily: 'Oswald',
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.textPrimary,
      letterSpacing: spacing,
      height: height,
    );
  }

  static TextStyle _inter(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? spacing,
    double height = 1.35,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.textPrimary,
      letterSpacing: spacing,
      height: height,
      fontVariations: [
        FontVariation('opsz', size.clamp(_interOpszMin, _interOpszMax)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Oswald — brand voice
  // ---------------------------------------------------------------------------

  /// 160 · A drill's "get in stance" countdown. The phone is on the floor two
  /// or three metres away, so this is sized like a scoreboard, not a dashboard.
  /// Pair with `AppAccessibility.heroNumeralScaler`, as for [heroNumeral].
  static TextStyle stageNumeral({Color? color}) => _oswald(160, color: color);

  /// 64 · The round timer's digits. The largest thing held in the hand.
  static TextStyle heroNumeral({Color? color, double? spacing}) =>
      _oswald(64, color: color, spacing: spacing);

  /// 52 · Full-screen hero figures — current weight, headline totals.
  static TextStyle display({Color? color, double? spacing}) =>
      _oswald(52, color: color, spacing: spacing);

  /// 30 · Screen hero titles and the large collapsing title.
  static TextStyle largeTitle({Color? color, double? spacing}) =>
      _oswald(30, color: color, spacing: spacing);

  /// 22 · Card titles, setup-step questions, stat values.
  static TextStyle title1({Color? color, double? spacing}) =>
      _oswald(22, color: color, spacing: spacing);

  /// 18 · Screen headers and small card titles.
  static TextStyle title2({Color? color, double? spacing}) =>
      _oswald(18, color: color, spacing: spacing);

  // ---------------------------------------------------------------------------
  // Inter — everything readable
  // ---------------------------------------------------------------------------

  /// 17/w600 · Emphasized rows and list titles. Same size as [body] by design:
  /// weight carries the emphasis, not scale.
  static TextStyle headline({Color? color, double? spacing}) => _inter(17,
      weight: FontWeight.w600, color: color, spacing: spacing, height: 1.3);

  /// 17 · Default body copy. iOS sets body at 17 for a reason — this is the
  /// comfortable reading size the app previously had no role for.
  static TextStyle body({FontWeight? weight, Color? color, double? spacing}) =>
      _inter(17,
          weight: weight ?? FontWeight.w500,
          color: color,
          spacing: spacing,
          height: 1.4);

  /// 15 · Secondary copy, supporting descriptions.
  static TextStyle callout(
          {FontWeight? weight, Color? color, double? spacing}) =>
      _inter(15,
          weight: weight ?? FontWeight.w500,
          color: color,
          spacing: spacing,
          height: 1.35);

  /// 13 · Metadata, timestamps, captions. The app's densest working size.
  static TextStyle subhead(
          {FontWeight? weight, Color? color, double? spacing}) =>
      _inter(13,
          weight: weight ?? FontWeight.w500,
          color: color,
          spacing: spacing,
          height: 1.3);

  /// 11 · Uppercase eyebrow labels only, always tracked. This is the floor —
  /// nothing in the app renders below 11.
  static TextStyle micro({FontWeight? weight, Color? color, double? spacing}) =>
      _inter(11,
          weight: weight ?? FontWeight.w700,
          color: color,
          spacing: spacing ?? 0.8,
          height: 1.2);

  // ---------------------------------------------------------------------------
  // Escape hatch
  // ---------------------------------------------------------------------------

  /// Oswald at a computed size. The *only* legitimate use is a proportionally
  /// scaled mark (see `BrandLogo`), where the size is a multiple of a layout
  /// dimension rather than a role. Everything else takes a role above.
  ///
  /// [weight] is clamped to w700 — Oswald's `wght` axis stops there, and asking
  /// for more gets a synthesized fake rather than a drawn weight.
  static TextStyle scaledDisplay(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color? color,
    double? spacing,
  }) =>
      _oswald(
        size,
        weight: weight.value > 700 ? FontWeight.w700 : weight,
        color: color,
        spacing: spacing,
      );

  /// Inter at a computed size. Same rule as [scaledDisplay]: proportionally
  /// scaled marks only.
  static TextStyle scaledBody(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? spacing,
  }) =>
      _inter(size, weight: weight, color: color, spacing: spacing);
}
