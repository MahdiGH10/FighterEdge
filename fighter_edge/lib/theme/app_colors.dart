import 'package:flutter/material.dart';

/// Central palette for FIGHTER EDGE — dark, athletic, crimson accent.
///
/// The palette is organised in three layers, and call sites should reach for
/// the most specific one that fits:
///
/// 1. **Role tokens** (`background`, `surface`, `textPrimary`, `primary`,
///    `positive`, …). These name a *job*, not a colour, and are what almost
///    every widget should use. They are unchanged and remain the default.
/// 2. **Semantic families** (`positiveSoft`/`positiveStrong`, …). A tinted
///    fill and a text-safe foreground for each semantic role, so a status
///    surface can be built without hand-mixing alpha at the call site.
/// 3. **Ramps** (`crimson50…crimson900`, `neutral0…neutral950`). The raw tonal
///    scales the roles are drawn from. Reach for these only when a role
///    genuinely does not exist — a new chart series, a bespoke gradient stop —
///    and prefer promoting a new *role* over sprinkling ramp steps through UI.
///
/// ## Contrast
///
/// Every token documented "text-safe" below was measured against
/// [surfaceElevated] (`#21212B`, the lightest surface text sits on) and clears
/// the WCAG AA 4.5:1 floor for normal-sized text. Anything not marked
/// text-safe is a *fill*: use it behind content, not as content.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------------

  static const Color background = Color(0xFF09090D);
  static const Color backgroundRaised = Color(0xFF0E0E14);
  static const Color surface = Color(0xFF14141B);
  static const Color surfaceAlt = Color(0xFF191922);
  static const Color surfaceElevated = Color(0xFF21212B);

  /// Tint laid over a `BackdropFilter` blur (see `AppBottomNav`).
  ///
  /// Deliberately translucent: at the old 95% opacity the blur behind it was
  /// invisible and the "glass" was just paint. 72% lets content register
  /// through the bar while keeping label contrast on a dark ground.
  static const Color surfaceGlass = Color(0xB816161E);

  /// Dims everything except what a coach mark is pointing at. Dark enough
  /// that the lit target is unmistakably the subject, light enough that the
  /// user still sees where they are.
  static const Color scrim = Color(0xC7050508);
  static const Color border = Color(0xFF292933);
  static const Color borderStrong = Color(0xFF3A3A46);

  // ---------------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------------

  static const Color primary = Color(0xFFE63328);
  static const Color primaryBright = Color(0xFFFF4C42);

  /// Accent for *small* text (below 18pt, or 14pt bold).
  ///
  /// [primary] measures 3.70:1 on [surfaceElevated] — under the 4.5:1 WCAG AA
  /// floor for normal-sized text. This is the same hue at 4.83:1. Use [primary]
  /// for fills and large display type; use this anywhere the accent is set on
  /// body-sized text.
  static const Color accentText = primaryBright;
  static const Color primaryDark = Color(0xFFC22A20);
  static const Color primarySoft = Color(0x22E63328);
  static const Color primaryGlow = Color(0x38E63328);
  static const Color premium = Color(0xFFF2C879);

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAB5);
  static const Color textMuted = Color(0xFF8A8A96);

  // ---------------------------------------------------------------------------
  // Semantic
  // ---------------------------------------------------------------------------

  static const Color positive = Color(0xFF3FD07E);
  static const Color warning = Color(0xFFF5A623);
  static const Color negative = Color(0xFFFF3B5C);

  // ---------------------------------------------------------------------------
  // Chart helpers
  // ---------------------------------------------------------------------------

  static const Color track = Color(0xFF2A2A2E);
  static const Color carbs = Color(0xFF4A9EF0);
  static const Color fats = Color(0xFFF5A623);
  static const Color protein = Color(0xFF3FD07E);

  // ===========================================================================
  // Crimson ramp
  //
  // The brand hue (~4°) held constant while lightness moves. [crimson500] is
  // exactly [primary]; the rest are the tones the app previously lacked, which
  // is why gradients and hover/pressed states had to invent one-off colours.
  //
  // On a dark ground the ramp reads inverted from a light-theme ramp: the low
  // numbers are *foreground* accents (bright enough to read as text), the high
  // numbers are *fills* (deep enough to sit under content).
  // ===========================================================================

  /// Text-safe. Near-white crimson tint — highest-emphasis accent text.
  static const Color crimson50 = Color(0xFFFCEAE8);

  /// Text-safe. Quiet accent text where [accentText] is too loud.
  static const Color crimson100 = Color(0xFFF9CBC8);

  /// Text-safe.
  static const Color crimson200 = Color(0xFFF3A19B);

  /// Text-safe.
  static const Color crimson300 = Color(0xFFEE766D);

  /// Text-safe (4.70:1). The darkest step on this ramp that still clears AA —
  /// one step deeper and it drops below the floor, which is why [primary]
  /// itself cannot carry body text.
  static const Color crimson400 = Color(0xFFEB5C52);

  /// The brand red. Fills and large display type only — 3.70:1, not text-safe
  /// at body size. Identical to [primary].
  static const Color crimson500 = primary;

  /// Pressed/active state for [primary] fills.
  static const Color crimson600 = Color(0xFFD22519);

  /// Deep fill. Close to [primaryDark].
  static const Color crimson700 = Color(0xFFAD1F14);

  /// Deep fill — gradient ends, tinted backgrounds.
  static const Color crimson800 = Color(0xFF891810);

  /// Deepest fill. Reads as a dark ground with brand temperature.
  static const Color crimson900 = Color(0xFF64120C);

  // ===========================================================================
  // Neutral ramp
  //
  // The app's elevation scale, formalised. The existing surface/text/border
  // roles are drawn from these steps — the aliases below are exact, so this
  // ramp documents the system rather than replacing it. Note the slight
  // blue-violet cast: neutrals here are not pure grey, which is what keeps the
  // dark UI from looking muddy next to the warm crimson.
  // ===========================================================================

  static const Color neutral0 = textPrimary; // #FFFFFF
  static const Color neutral50 = Color(0xFFD6D6DD);
  static const Color neutral100 = textSecondary; // #AAAAB5
  static const Color neutral200 = textMuted; // #8A8A96
  static const Color neutral300 = Color(0xFF6E6E79);
  static const Color neutral400 = Color(0xFF55555F);
  static const Color neutral500 = borderStrong; // #3A3A46
  static const Color neutral600 = border; // #292933
  static const Color neutral700 = surfaceElevated; // #21212B
  static const Color neutral800 = surfaceAlt; // #191922
  static const Color neutral850 = surface; // #14141B
  static const Color neutral900 = backgroundRaised; // #0E0E14
  static const Color neutral950 = background; // #09090D

  // ===========================================================================
  // Semantic families
  //
  // Each role gets a tinted fill (`*Soft`) and a text-safe foreground
  // (`*Strong`). The base role tokens above are unchanged; these exist so a
  // status chip or banner can be assembled from named parts instead of a
  // hand-written `withValues(alpha: 0.13)` at the call site.
  //
  // The `*Soft` values use the same 0x22 alpha as [primarySoft], so tinted
  // surfaces across the app share one density.
  // ===========================================================================

  static const Color positiveSoft = Color(0x223FD07E);

  /// Text-safe. [positive] already measures 7.99:1, so this is the same value —
  /// named separately so call sites stay symmetrical across semantic families.
  static const Color positiveStrong = positive;

  static const Color warningSoft = Color(0x22F5A623);

  /// Text-safe (7.87:1).
  static const Color warningStrong = warning;

  static const Color negativeSoft = Color(0x22FF3B5C);

  /// Text-safe, but only just (4.58:1). Prefer it at `w600`+ on body copy.
  static const Color negativeStrong = negative;

  /// Informational accent — the cool counterweight to the brand red. Shares
  /// its value with [carbs] so charts and info surfaces agree.
  static const Color info = carbs;
  static const Color infoSoft = Color(0x224A9EF0);

  /// Text-safe (5.65:1).
  static const Color infoStrong = info;

  /// Tinted ground for Pro/premium surfaces. Gold marks entitlement only —
  /// never decoration.
  static const Color premiumSoft = Color(0x22F2C879);

  /// Text-safe. [premium] is already light enough to read on dark surfaces.
  static const Color premiumStrong = premium;

  /// Deep gold, for gradient ends and pressed states on premium fills.
  static const Color premiumDeep = Color(0xFFB8893A);

  // ===========================================================================
  // Chart series
  //
  // Ordered, visually distinct, and all text-safe on [surfaceElevated] so a
  // series label can take its series colour. The first three are the existing
  // macro colours, so nutrition charts keep their established meaning; the
  // rest extend the set for the analytics surfaces that do not exist yet.
  //
  // Use [chartSeries] when the number of series is data-driven; reach for the
  // macro-named tokens when the series *is* protein/carbs/fats.
  // ===========================================================================

  static const Color series1 = protein; // green
  static const Color series2 = carbs; // blue
  static const Color series3 = fats; // amber
  static const Color series4 = Color(0xFFB98CF0); // violet
  static const Color series5 = Color(0xFF4ACFC4); // teal
  static const Color series6 = Color(0xFFF07EA8); // pink

  static const List<Color> chartSeries = [
    series1,
    series2,
    series3,
    series4,
    series5,
    series6,
  ];
}
