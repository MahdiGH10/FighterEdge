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
///   Barlow carries everything readable. It is a sturdy, slightly squared
///   grotesque drawn after road signage: it reads as sport and as a working
///   instrument, and (unlike the default UI sans) it does not look like every
///   other app. It runs a little small for its size, so the readable ladder is
///   one point larger than the usual 17/15/13.
class AppType {
  AppType._();

  /// Provider-owned typography for the official Google sign-in treatment.
  static TextStyle googleSignIn() => const TextStyle(
        fontFamily: 'GoogleSans',
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w500,
        color: AppColors.googleText,
      );

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

  static TextStyle _barlow(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? spacing,
    double height = 1.35,
  }) {
    return TextStyle(
      fontFamily: 'Barlow',
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.textPrimary,
      letterSpacing: spacing,
      height: height,
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
  // Barlow — everything readable
  // ---------------------------------------------------------------------------

  /// 17/w600 · Emphasized rows and list titles. Same size as [body] by design:
  /// weight carries the emphasis, not scale.
  static TextStyle headline({Color? color, double? spacing}) => _barlow(17,
      weight: FontWeight.w600, color: color, spacing: spacing, height: 1.3);

  /// 17 · Default body copy. iOS sets body at 17 for a reason — this is the
  /// comfortable reading size the app previously had no role for.
  static TextStyle body({FontWeight? weight, Color? color, double? spacing}) =>
      _barlow(17,
          weight: weight ?? FontWeight.w500,
          color: color,
          spacing: spacing,
          height: 1.4);

  /// 16 · Secondary copy, supporting descriptions.
  static TextStyle callout(
          {FontWeight? weight, Color? color, double? spacing}) =>
      _barlow(16,
          weight: weight ?? FontWeight.w500,
          color: color,
          spacing: spacing,
          height: 1.35);

  /// 14 · Metadata, timestamps, captions. The app's densest working size.
  static TextStyle subhead(
          {FontWeight? weight, Color? color, double? spacing}) =>
      _barlow(14,
          weight: weight ?? FontWeight.w500,
          color: color,
          spacing: spacing,
          height: 1.3);

  /// 12 · Uppercase eyebrow labels only, always tracked. This is the floor —
  /// nothing in the app renders below 12.
  static TextStyle micro({FontWeight? weight, Color? color, double? spacing}) =>
      _barlow(12,
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

  /// Barlow at a computed size. Same rule as [scaledDisplay]: proportionally
  /// scaled marks only.
  static TextStyle scaledBody(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? spacing,
  }) =>
      _barlow(size, weight: weight, color: color, spacing: spacing);
}
