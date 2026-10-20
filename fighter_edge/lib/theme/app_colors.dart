import 'package:flutter/material.dart';

/// Central palette for FIGHTER EDGE — dark, athletic, crimson accent.
///
/// V2 values (the approved mockups): a near-black violet ground, saturated
/// crimson and ember, a pink-red danger, gold for Pro only and green for "done"
/// only. Glass (tint, rim, inner light) lives in [GlassColors] at the bottom of
/// this file.
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
/// [surfaceElevated] (`#26222F`, the lightest solid surface text sits on) and
/// clears the WCAG AA 4.5:1 floor for normal-sized text. Anything not marked
/// text-safe is a *fill*: use it behind content, not as content. Text on glass
/// has a stricter rule: see [GlassColors.allowsText].
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------------

  static const Color background = Color(0xFF08070C);
  static const Color backgroundRaised = Color(0xFF0E0C13);
  static const Color surface = Color(0xFF14121A);
  static const Color surfaceAlt = Color(0xFF1C1923);
  static const Color surfaceElevated = Color(0xFF26222F);

  /// Dims everything except what a coach mark is pointing at. Dark enough
  /// that the lit target is unmistakably the subject, light enough that the
  /// user still sees where they are.
  static const Color scrim = Color(0xC7050508);

  static const Color border = Color(0xFF29272F);
  static const Color borderStrong = Color(0xFF3A383F);

  // ---------------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------------

  static const Color primary = Color(0xFFE0222B);
  static const Color primaryBright = crimson400;

  /// Accent for *small* text (below 18pt, or 14pt bold).
  ///
  /// [primary] measures 3.2:1 on [surfaceElevated] — under the 4.5:1 WCAG AA
  /// floor for normal-sized text. This is the same hue at 5.3:1. Use [primary]
  /// for fills and large display type; use this anywhere the accent is set on
  /// body-sized text. Not for glass: see [GlassColors.allowsText].
  static const Color accentText = crimson400;
  static const Color primaryDark = crimson700;

  /// A red fill that carries white text: the primary button.
  ///
  /// White on the top of the mockup's button gradient (`#EC2B34`) measures
  /// 4.2:1, under AA for the button's label, so the button stays flat on a fill
  /// that passes on its own: [crimson600] is the bottom of that gradient, 5.9:1.
  static const Color primaryFill = crimson600;
  static const Color primarySoft = Color(0x22E0222B);
  static const Color primaryGlow = Color(0x38E0222B);

  /// Gold. Pro and trial surfaces only, never decoration.
  static const Color premium = Color(0xFFF2C879);

  /// Ember: the warm end of the crimson-to-ember ramp, progress fills and the
  /// top glow core. A fill, not text.
  static const Color ember = ember500;

  /// Small ember text, text-safe on solid surfaces and on every glass kind
  /// (see [GlassColors.allowsText]). Eyebrows over tinted glass use this.
  static const Color emberSoft = ember300;

  /// Progress / week-strip / ring ramp: crimson to ember, left to right.
  static const Color rampStart = Color(0xFFD8182A);
  static const Color rampEnd = ember500;
  static const LinearGradient progressRamp = LinearGradient(
    colors: [rampStart, rampEnd],
  );

  /// Top of the primary button's highlight gradient (`ctaTop` to
  /// [primaryFill]). Use for a gradient or pressed-state hint only: white text
  /// on this colour alone is 4.2:1, so a label must not sit on the top edge.
  static const Color ctaTop = Color(0xFFEC2B34);

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  /// White foreground on primary/semantic fills, and opaque shader masks.
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color maskOpaque = Color(0xFFFFFFFF);
  static const Color transparent = Color(0x00000000);

  /// Google's approved light sign-in button palette.
  static const Color googleSurface = Color(0xFFFFFFFF);
  static const Color googleText = Color(0xFF1F1F1F);
  static const Color googleBorder = Color(0xFF747775);

  static const Color textPrimary = Color(0xFFF7F5FA);
  static const Color textSecondary = Color(0xFFBDB8C7);
  static const Color textMuted = Color(0xFF9892A5);

  // ---------------------------------------------------------------------------
  // Semantic
  // ---------------------------------------------------------------------------

  /// Done, and "on a safe path". Nothing else is green.
  static const Color positive = Color(0xFF46C287);
  static const Color warning = Color(0xFFF5A623);

  /// Danger pink-red. Distinct from brand crimson on purpose: crimson means
  /// "do this", this means "something is wrong", and always comes with an icon
  /// and words. Not for small text on glass.
  static const Color negative = Color(0xFFFF4F7B);

  // ---------------------------------------------------------------------------
  // Chart helpers
  // ---------------------------------------------------------------------------

  static const Color track = Color(0xFF2B2832);
  static const Color carbs = Color(0xFF4A9EF0);
  static const Color fats = Color(0xFFF0A93B);

  /// Violet since V2: green is reserved for "done".
  static const Color protein = Color(0xFFB58CFF);

  // ===========================================================================
  // Crimson ramp
  //
  // The V2 brand hue (~357 degrees), more saturated than before. [crimson500]
  // is exactly [primary]; the rest are the tones gradients and hover/pressed
  // states draw from.
  //
  // On a dark ground the ramp reads inverted from a light-theme ramp: the low
  // numbers are *foreground* accents (bright enough to read as text), the high
  // numbers are *fills* (deep enough to sit under content).
  // ===========================================================================

  /// Text-safe. Near-white crimson tint — highest-emphasis accent text.
  static const Color crimson50 = Color(0xFFFFEDEC);

  /// Text-safe. Quiet accent text where [accentText] is too loud.
  static const Color crimson100 = Color(0xFFFFCFCC);

  /// Text-safe.
  static const Color crimson200 = Color(0xFFFFAAA4);

  /// Text-safe.
  static const Color crimson300 = Color(0xFFFF857C);

  /// Text-safe (5.3:1). The mockup's "accent text". The darkest step on this
  /// ramp that still clears AA on [surfaceElevated] — one step deeper and it
  /// drops below the floor, which is why [primary] itself cannot carry body
  /// text.
  static const Color crimson400 = Color(0xFFFF6358);

  /// The brand red. Fills and large display type only — 3.2:1 on
  /// [surfaceElevated], not text-safe at body size. Identical to [primary].
  static const Color crimson500 = Color(0xFFE0222B);

  /// Pressed/active state for [primary] fills; the bottom of the primary
  /// button gradient, and the flat button fill (white on it is 5.9:1).
  static const Color crimson600 = Color(0xFFC7131E);

  /// Deep fill. The mockup's "crimson deep": pressed, ramp start.
  static const Color crimson700 = Color(0xFFB3121C);

  /// Deep fill — gradient ends, tinted backgrounds.
  static const Color crimson800 = Color(0xFF8A0E16);

  /// Deepest fill. Reads as a dark ground with brand temperature.
  static const Color crimson900 = Color(0xFF5E0A10);

  // ===========================================================================
  // Ember ramp
  //
  // The warm partner of crimson (~20 degrees): the end of the progress ramp,
  // the top glow core and eyebrows on glass. Same rules as the crimson ramp:
  // low numbers are text-safe foregrounds, high numbers are fills.
  // ===========================================================================

  /// Text-safe.
  static const Color ember50 = Color(0xFFFFF1E8);

  /// Text-safe.
  static const Color ember100 = Color(0xFFFFDCC4);

  /// Text-safe.
  static const Color ember200 = Color(0xFFFFC09A);

  /// Text-safe (7.0:1 on [surfaceElevated]). The mockup's "ember soft".
  static const Color ember300 = Color(0xFFFF9248);

  /// Text-safe.
  static const Color ember400 = Color(0xFFFF7C36);

  /// The mockup's "ember". Ramp end and glow core. Fill.
  static const Color ember500 = Color(0xFFFF6A2B);

  /// Fill.
  static const Color ember600 = Color(0xFFE5521A);

  /// Fill.
  static const Color ember700 = Color(0xFFB83F12);

  /// Fill.
  static const Color ember800 = Color(0xFF8A2F0E);

  /// Fill.
  static const Color ember900 = Color(0xFF5C200A);

  // ===========================================================================
  // Neutral ramp
  //
  // The app's elevation scale, formalised. The existing surface/text/border
  // roles are drawn from these steps — the aliases below are exact, so this
  // ramp documents the system rather than replacing it. Note the slight
  // blue-violet cast: neutrals here are not pure grey, which is what keeps the
  // dark UI from looking muddy next to the warm crimson.
  // ===========================================================================

  static const Color neutral0 = textPrimary; // #F7F5FA
  static const Color neutral50 = Color(0xFFD9D5E0);
  static const Color neutral100 = textSecondary; // #BDB8C7
  static const Color neutral200 = textMuted; // #9892A5
  static const Color neutral300 = Color(0xFF6F6A7C);
  static const Color neutral400 = Color(0xFF55515F);
  static const Color neutral500 = borderStrong; // #3A383F
  static const Color neutral600 = border; // #29272F
  static const Color neutral700 = surfaceElevated; // #26222F
  static const Color neutral800 = surfaceAlt; // #1C1923
  static const Color neutral850 = surface; // #14121A
  static const Color neutral900 = backgroundRaised; // #0E0C13
  static const Color neutral950 = background; // #08070C

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

  static const Color positiveSoft = Color(0x2246C287);

  /// Text-safe. [positive] already measures 6.9:1, so this is the same value —
  /// named separately so call sites stay symmetrical across semantic families.
  static const Color positiveStrong = positive;

  static const Color warningSoft = Color(0x22F5A623);

  /// Text-safe (7.87:1).
  static const Color warningStrong = warning;

  static const Color negativeSoft = Color(0x22FF4F7B);

  /// Text-safe (4.9:1 on [surfaceElevated]). Prefer it at `w600`+ on body copy.
  static const Color negativeStrong = negative;

  /// Informational accent — the cool counterweight to the brand red. Shares
  /// its value with [carbs] so charts and info surfaces agree.
  static const Color info = carbs;
  static const Color infoSoft = Color(0x224A9EF0);

  /// Text-safe (5.5:1).
  static const Color infoStrong = info;

  /// Tinted ground for Pro/premium surfaces. Gold marks entitlement only —
  /// never decoration.
  static const Color premiumSoft = Color(0x22F2C879);

  /// Text-safe. [premium] is already light enough to read on dark surfaces.
  static const Color premiumStrong = premium;

  /// Deep gold, for gradient ends and pressed states on premium fills.
  static const Color premiumDeep = Color(0xFFC9973F);

  // ===========================================================================
  // Chart series
  //
  // Ordered, visually distinct, and all text-safe on [surfaceElevated] so a
  // series label can take its series colour. Protein, carbs and fats keep their
  // macro colours (series 1, 3 and 4); green is not a series colour because it
  // means "done". Adjacent series are kept visually apart.
  //
  // Use [chartSeries] when the number of series is data-driven; reach for the
  // macro-named tokens when the series *is* protein/carbs/fats.
  // ===========================================================================

  static const Color series1 = protein; // violet
  static const Color series2 = Color(0xFF4ACFC4); // teal
  static const Color series3 = carbs; // blue
  static const Color series4 = fats; // amber
  static const Color series5 = Color(0xFFF07EA8); // pink
  static const Color series6 = Color(0xFF9FB4FF); // periwinkle

  static const List<Color> chartSeries = [
    series1,
    series2,
    series3,
    series4,
    series5,
    series6,
  ];
}

/// What a piece of glass is, for the contrast rule in [GlassColors.allowsText].
enum GlassKind {
  /// Tinted hero card (no blur) over the static glow. Ember and cool tones.
  hero,

  /// Tinted hero card in the gold tone (trial and Pro surfaces).
  heroGold,

  /// Bottom nav, collapsed header, session control bar (real blur).
  nav,

  /// Bottom sheet (real blur).
  sheet,
}

/// The layers of one tinted hero card: base, 158 degree tint, top-left
/// highlight, 135 degree rim and the inner light. [GlassColors] has three.
@immutable
class GlassHeroPalette {
  const GlassHeroPalette({
    required this.base,
    required this.tintStart,
    required this.tintMid,
    required this.tintEnd,
    required this.highlight,
    required this.rimStart,
    required this.rimMid,
    required this.rimFade,
    required this.rimEnd,
    required this.innerLightTop,
    required this.innerLightBottom,
  });

  final Color base;
  final Color tintStart;
  final Color tintMid;
  final Color tintEnd;
  final Color highlight;
  final Color rimStart;
  final Color rimMid;
  final Color rimFade;
  final Color rimEnd;
  final Color innerLightTop;
  final Color innerLightBottom;
}

/// Glass tokens: the tint, rim and inner light of the V2 surfaces, the static
/// ground glow they sit on, and the one rule for text over them.
///
/// ## Three layers
///
/// 1. **Ground**: [AppColors.background] with a static glow ([glowTop] and the
///    others), painted once by `AppBackground`.
/// 2. **Navigation glass** ([navFill], [sheetFill]): real blur, only where
///    content scrolls underneath. Without blur ([navFillTinted],
///    [sheetFillTinted]) the fill is nearly opaque so content below does not
///    compete with the label.
/// 3. **Hero tint** ([heroEmber], [heroCool], [heroGold]): no blur at all; a
///    translucent tint, a 1px gradient rim and an inner light.
///
/// The solid fallback ([solidFill]) keeps the same layout with opaque surfaces.
///
/// ## Text on glass
///
/// Contrast over glass depends on what is behind it, so it is judged at the
/// brightest case, not the average one: [worstCaseBackdrop]. A colour may carry
/// small text on a kind of glass only if it clears 4.5:1 there; at 18px bold
/// and above, 3:1 is enough. For the hero and the sheet that leaves Text,
/// Text 2, Ember soft, Gold and Done green. Text 3, Accent text and Danger are
/// for the ground and solid surfaces. Use [text] to apply the rule.
class GlassColors {
  GlassColors._();

  // ---- Ground glow (static) -------------------------------------------------

  /// Crimson core at the top edge, alpha .55.
  static const Color glowTop = Color(0x8CE0222B);

  /// Ember halo around [glowTop], alpha .22.
  static const Color glowEmber = Color(0x38FF6A2B);

  /// Cool violet-blue pool bottom-left, alpha .40. Complementary to crimson, so
  /// the crimson above reads richer; an ember low glow would turn the whole
  /// screen orange-red.
  static const Color glowLow = Color(0x663A2CC4);

  /// Violet accent bottom-right, alpha .17.
  static const Color glowViolet = Color(0x2B8222AA);

  // ---- Navigation glass -----------------------------------------------------

  /// Bottom nav and collapsed header, alpha .78, over a sigma 16 blur.
  static const Color navFill = Color(0xC70D0A13);

  /// The same fill when blur is off: alpha .94.
  static const Color navFillTinted = Color(0xF00D0A13);

  /// 1px edge facing the content, alpha .10.
  static const Color navHairline = Color(0x1AFFFFFF);

  /// Inner light along the nav top edge, alpha .04.
  static const Color navInnerLight = Color(0x0AFFFFFF);

  /// Sheet fill, alpha .80, over a sigma 16 blur.
  static const Color sheetFill = Color(0xCC1B1725);

  /// The same fill when blur is off: alpha .94.
  static const Color sheetFillTinted = Color(0xF01B1725);

  /// Sheet top rim, alpha .18.
  static const Color sheetRim = Color(0x2EFFFFFF);

  /// Sheet inner light, alpha .06.
  static const Color sheetInnerLight = Color(0x0FFFFFFF);

  /// Grabber handle on a sheet, alpha .28.
  static const Color sheetGrabber = Color(0x47FFFFFF);

  // ---- Hero tint ------------------------------------------------------------

  /// Warm tint: Today card, weekly target, review recommendation.
  static const GlassHeroPalette heroEmber = GlassHeroPalette(
    base: Color(0xAD0C0810), // rgba(12,8,16,.68)
    tintStart: Color(0x1AFF6A2B), // ember .10
    tintMid: Color(0x426E121E), // crimson .26
    tintEnd: Color(0x80160C1E), // dark .50
    highlight: Color(0x1DFFFFFF), // white .115 at the top-left corner
    rimStart: Color(0x9EFFFFFF), // .62
    rimMid: Color(0x24FFFFFF), // .14
    rimFade: Color(0x0DFFFFFF), // .05
    rimEnd: Color(0x57FF9678), // warm .34
    innerLightTop: Color(0x1FFFFFFF), // .12
    innerLightBottom: Color(0x33FF6A2B), // ember .20
  );

  /// Cool tint: secondary hero cards (weekly review, fuel).
  static const GlassHeroPalette heroCool = GlassHeroPalette(
    base: Color(0xAD0C0810),
    tintStart: Color(0x247864FF), // violet .14
    tintMid: Color(0x423C2278), // .26
    tintEnd: Color(0x80120C1E), // .50
    highlight: Color(0x1AFFFFFF), // .105
    rimStart: Color(0x9EFFFFFF),
    rimMid: Color(0x24FFFFFF),
    rimFade: Color(0x0DFFFFFF),
    rimEnd: Color(0x578C78FF), // cool .34
    innerLightTop: Color(0x1FFFFFFF),
    innerLightBottom: Color(0x338C78FF),
  );

  /// Gold tint: trial and Pro only.
  static const GlassHeroPalette heroGold = GlassHeroPalette(
    base: Color(0xAD0C0810),
    tintStart: Color(0x24F2C879), // gold .14
    tintMid: Color(0x38784F1E), // .22
    tintEnd: Color(0x85160E0E), // .52
    highlight: Color(0x1DFFECBE), // .115
    rimStart: Color(0xB3FFEEC8), // .70
    rimMid: Color(0x2EF2C879), // .18
    rimFade: Color(0x0FF2C879), // .06
    rimEnd: Color(0x61F2C879), // .38
    innerLightTop: Color(0x1FFFFFFF),
    innerLightBottom: Color(0x33F2C879),
  );

  /// Where the hero tint gradient stops sit (158 degrees).
  static const List<double> heroTintStops = [0, .4, 1];

  /// Where the hero rim gradient stops sit (135 degrees).
  static const List<double> heroRimStops = [0, .26, .58, 1];

  // ---- Solid fallback -------------------------------------------------------

  /// 1px line of a solid hero, alpha .16.
  static const Color solidLine = Color(0x29FFFFFF);

  /// The opaque surface that replaces a [kind] of glass at the solid level.
  static Color solidFill(GlassKind kind) => switch (kind) {
        GlassKind.hero || GlassKind.heroGold => AppColors.surfaceAlt,
        GlassKind.nav => AppColors.surface,
        GlassKind.sheet => AppColors.surfaceElevated,
      };

  // ---- Contrast rule --------------------------------------------------------

  /// The ground at the glow core: [glowTop] over [AppColors.background].
  static Color get glowCore => Color.alphaBlend(glowTop, AppColors.background);

  /// The brightest opaque colour that can sit behind text on [kind].
  ///
  /// Hero: the card is assumed to sit on the crimson glow core, at its
  /// top-left highlight (real layouts sit lower, so this is a lower bound).
  /// Nav and sheet: content scrolling underneath is as bright as ember.
  static Color worstCaseBackdrop(GlassKind kind) {
    Color hero(GlassHeroPalette p) => Color.alphaBlend(
          p.highlight,
          Color.alphaBlend(p.tintStart, Color.alphaBlend(p.base, glowCore)),
        );
    return switch (kind) {
      GlassKind.hero => hero(heroEmber),
      GlassKind.heroGold => hero(heroGold),
      GlassKind.nav => Color.alphaBlend(navFill, AppColors.ember),
      GlassKind.sheet => Color.alphaBlend(sheetFill, AppColors.ember),
    };
  }

  /// WCAG 2.x contrast ratio of an opaque [foreground] on an opaque
  /// [background].
  static double contrast(Color foreground, Color background) {
    final a = foreground.computeLuminance();
    final b = background.computeLuminance();
    final lighter = a > b ? a : b;
    final darker = a > b ? b : a;
    return (lighter + .05) / (darker + .05);
  }

  /// Whether [color] may carry text on [kind] of glass: 4.5:1 at the worst
  /// case, or 3:1 when the text is [largeBold] (18px bold and above).
  static bool allowsText(GlassKind kind, Color color,
          {bool largeBold = false}) =>
      contrast(color, worstCaseBackdrop(kind)) >= (largeBold ? 3.0 : 4.5);

  /// [color] for text on [kind] of glass, or a safe stand-in.
  ///
  /// Debug builds assert when the colour fails the rule, so the mistake is
  /// seen where it is made. Release builds fall back to
  /// [AppColors.textSecondary] rather than ship unreadable text.
  static Color text(GlassKind kind, Color color, {bool largeBold = false}) {
    final ok = allowsText(kind, color, largeBold: largeBold);
    assert(
      ok,
      'Text colour $color is not readable on ${kind.name} glass at its '
      'brightest. Use textPrimary, textSecondary, emberSoft, premium or '
      'positive, or move this text onto the ground or a solid surface.',
    );
    return ok ? color : AppColors.textSecondary;
  }
}
