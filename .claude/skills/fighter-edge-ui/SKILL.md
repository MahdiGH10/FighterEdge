---
name: fighter-edge-ui
description: The Fighter Edge V2 design contract — a Liquid Glass-informed fighter brand mapped onto this repo's real Dart tokens. Load BEFORE writing or changing any Flutter UI in lib/ — screens, widgets, theme, glass, motion, haptics, or layout. Use when adding a screen, restyling one, adding a sheet, header or card, adding animation or transitions, choosing a color/size/spacing value, or reviewing UI for premium feel. Prevents one-off styles, raw magic numbers, blur in the wrong place, and AI-slop motion.
---

# Fighter Edge UI contract (V2)

Fighter Edge is a dark, athletic, premium instrument for combat athletes: a
near-black ground with a soft static glow, saturated crimson and ember, glass
only where content scrolls underneath. It is **Liquid Glass-informed, not a 2020
frosted look and not an Apple clone**: take the chassis (type hierarchy, 4pt
spacing, Dynamic Type, 48dp targets, restrained motion) and keep the
crimson/black fight-night identity.

It should feel like a calm fight-camp instrument, never a generic fitness dashboard.

The approved reference is the V2 mockup design-system board (colour roles, glass
spec, measured contrast). Where this file and the board disagree, the board wins
and this file is out of date.

## Rule 0 — never invent a value

Every size, color, radius, duration and curve already has a name. If you are
typing a raw number or a `Color(0x…)` into a widget, you are doing it wrong.
Find the token. If genuinely none fits, add a named token to the theme file
and use it — do not inline the value.

## The vocabulary (verified against source)

| Need | Use | File |
|---|---|---|
| Type | `AppType.<role>()` | `lib/theme/app_typography.dart` |
| Spacing | `Insets.xxs…xxxl` (2·4·8·12·16·20·28·40) | `lib/theme/app_theme.dart` |
| Radii | `Radii.hero` / `Radii.sheet` 24 · `card` 12 · `button` 10 · `tile` 8 · `chip` 100 | `lib/theme/app_theme.dart` |
| Color | `AppColors.*` | `lib/theme/app_colors.dart` |
| Glass tokens + text rule | `GlassColors.*`, `GlassKind` | `lib/theme/app_colors.dart` |
| Glass level | `GlassPolicy.of(context)` → `GlassLevel` | `lib/theme/glass_policy.dart` |
| Glass nav layer | `GlassSurface` | `lib/widgets/glass_surface.dart` |
| Glass hero card | `GlassCard` | `lib/widgets/glass_surface.dart` |
| Glass sheet | `showGlassSheet` | `lib/widgets/glass_sheet.dart` |
| Ground + glow | `AppBackground` | `lib/widgets/premium_effects.dart` |
| Motion | `MotionTokens.*` | `lib/theme/app_theme.dart` |
| Haptics | `AppHaptics.*` | `lib/theme/app_haptics.dart` |
| Tap feedback | `PressScale` | `lib/widgets/press_scale.dart` |
| Entrance | `PremiumReveal(index: n)` | `lib/widgets/premium_effects.dart` |
| Accessibility | `AppAccessibility.*` | `lib/theme/app_accessibility.dart` |

### Type — ask for a role, never a size

**Oswald** (brand voice, numbers and titles): `stageNumeral` 160 (read from the
floor — drill countdown only) · `heroNumeral` 64 · `display` 52 ·
`largeTitle` 30 · `title1` 22 · `title2` 18.
**Barlow** (everything readable): `headline` 17/w600 · `body` 17 · `callout` 16 ·
`subhead` 14 · `micro` 12 uppercase+tracked.

- 12 is the floor. Nothing renders smaller.
- Both families are bundled (`assets/fonts`). Do not add another family.
  Oswald is variable (`wght` stops at 700 — asking for more gets a synthesized
  fake); Barlow ships static 400/500/600/700.
- `headline` and `body` are both 17 on purpose — **weight carries emphasis, not scale.**
- `scaledDisplay`/`scaledBody` are escape hatches for proportionally scaled
  marks only (e.g. `BrandLogo`). Never use them to dodge picking a role.

### Color — meaning first

- **Ground** `background` (`#08070C`), then the surfaces climb:
  `backgroundRaised` → `surface` → `surfaceAlt` → `surfaceElevated`.
- **Crimson means "do this"**: `primary` is a fill and large display type only
  (3.2:1 on `surfaceElevated`). The primary button is the flat `primaryFill`
  (white on it passes). **Small crimson text is `accentText`.**
- **Ember joins crimson in progress and the glow**: `AppColors.progressRamp`
  (crimson to ember) for fills, the week strip and rings. `emberSoft` is the
  small ember text colour (eyebrows on glass).
- **Danger is pink-red** (`negative`), distinct from crimson, and always comes
  with an icon and words.
- **Gold (`premium`) is Pro and trial only.** Never decorative.
- **Green (`positive`) means done or a safe path. Nothing else is green.**
  Protein is violet, carbs blue, fat amber.
- Ramps (`crimson50…900`, `ember50…900`, `neutral…`) are for a bespoke gradient
  stop or chart series. Prefer a role.
- Under high contrast use `AppAccessibility.textSecondary/textMuted/border/accentText(context)`.

### Glass — three layers, one rule

1. **Ground**: `AppBackground`, a near-black violet with a static glow (crimson
   core at the top, cool violet-blue pool bottom-left), painted once inside a
   `RepaintBoundary`. Never animate it.
2. **Navigation glass** (`GlassSurface`): real blur, sigma 16, only where content
   scrolls underneath — bottom nav, collapsed header, sheets, the session control
   bar. A tint, a 1px hairline and an inner light over the blur.
3. **Hero tint** (`GlassCard`): a translucent tint over the glow, a 1px gradient
   rim, an inner light. **No blur.** For a few hero blocks: Today, weekly target,
   review recommendation. Gold tone is for trial/Pro only.

Lists, rows and text blocks stay **crisp and solid** (`surface` / `surfaceAlt`).
V2 wants about 30% fewer containers: let rows and type do the work.

**Budget (hard):** at most 3 real blurs on a screen (nav + collapsed header + one
sheet); never in a list item or a card; never animated — show or hide the whole
surface, never fade it or animate the sigma. `GlassBlurBudget` reports the fourth in debug.
One `BackdropGroup` sits at `HomeShell`; use `BackdropFilter.grouped`
(`GlassSurface` does).

**Levels:** `GlassPolicy.of(context)` returns `full` / `tinted` (no blur) /
`solid`. It drops when the "Reduce transparency" setting is on or
`MediaQuery.highContrast` is on (solid), or the frame probe measured p90 raster
above 16 ms in the first 120 frames (tinted). Build the layout so all three
levels have the same geometry. Never branch on the level yourself; use
`GlassSurface` / `GlassCard`.

**Text on glass:** contrast is judged at the brightest glow corner
(`GlassColors.worstCaseBackdrop`). On hero and sheet glass small text may only
use **Text, Text 2, Ember soft, Gold, Done green.** Text 3 (`textMuted`), Accent
text and Danger go on the ground or on solid surfaces, or at 18px bold and
above. Gold hero is stricter still (no Danger at all). Apply it with
`GlassColors.text(kind, color, largeBold: …)`; it asserts in debug and falls back
to `textSecondary` in release. `test/unit/color_contrast_test.dart` pins the table.

### Motion

`press` 90ms · `fast` 160ms · `standard` 260ms · `reveal` 380ms · `stagger` 40ms/item.
Curves: `snap` (spring 380/28) for chips, toggles, tab switches.
`settle` (spring 220/30) for cards, sheets, reveals. `emphasized` is legacy —
do not reach for it in new work.

Motion rules:
1. **Motion must explain a relationship** — where something came from, where it
   went, what changed. Decoration that explains nothing is slop; delete it.
2. Stagger = one shared duration with offset *delays* (`PremiumReveal(index:)`).
   Never vary durations to fake a sequence — that reads as jitter.
3. Springs over cubics for anything that should feel physical.
4. Nothing bounces that represents a real quantity (weight, calories, timers).
5. **Always honor `MediaQuery.disableAnimationsOf(context)`** — return the
   static child. `PremiumReveal` already does; anything you hand-roll must too.
6. Never animate more than one property class per element at once
   (position OR scale OR opacity pairs, not all three plus rotation).
7. **Glass does not animate.** No fading a `GlassSurface`, no animated sigma, no
   animating anything inside a `BackdropFilter` subtree.

### Haptics — name the event, not the waveform

`selection()` peer movement · `tap()` open/activate · `commit()` user changed
something real · `success()` a goal landed (two beats) · `warning()` refused
or destructive.

Spend haptics on moments that mean something. Firing on scroll ticks or
rebuilds makes the device feel broken, not alive.

### Accessibility — non-negotiable

- Minimum touch target **48×48** (`AppAccessibility.minTouchTarget`). Wrap small
  icons rather than shrinking targets.
- Respect Dynamic Type everywhere. Only scoreboard-sized objects are clamped
  (`AppAccessibility.heroNumeralScaler`, capped at 1.25): `heroNumeral`,
  `stageNumeral`, and a reaction drill's live calls. They are already far
  larger than body text, not paragraph text.
- When side-by-side controls stop fitting (`AppAccessibility.isLargeText`,
  ≥ 140%), stack or wrap them — never truncate a label or push an option
  off-screen.
- Every interactive element needs a semantic label. Icon-only buttons always.
- High contrast means solid glass. "Reduce transparency" is a setting.

## Layout

- 4pt grid via `Insets`. Screen gutter is `Insets.lg` (16) at 320 wide, `Insets.xl`
  (20) otherwise; gap between blocks 20.
- **Tab screens sit behind the glass nav** (`HomeShell` uses `extendBody`): list
  bottom padding must clear it. Use `ScreenScaffold.tabBottomPadding(context)`
  (`MediaQuery.paddingOf(context).bottom`, which the Scaffold folds the nav height
  into, plus `Insets.xxl`), not a fixed number.
- **Header glass only where content scrolls under it.** `ScreenScaffold.tab(
  scrollsUnderHeader: true)` (Home, Profile: one scrolling list) runs the body
  behind the header and turns the header to glass once scrolled; the list takes
  `MediaQuery.paddingOf(context).top` as its top padding (read it in a `Builder`
  inside the body). Tabs that pin controls above their list keep the flat header.
- One primary action per screen, anchored in the safe area. Secondary actions are
  visually quieter, not merely smaller.
- Empty states teach the next action — never apologize, never dead-end.
- Loading uses skeletons shaped like the content, not centered spinners.
- Long screens: `ListView` with `PremiumReveal(index:)` on top-level children.
- Sheets use `showGlassSheet`, not a bare `showModalBottomSheet`.

## Before you call UI work done

- [ ] No raw numbers, no raw `Color(0x…)`, no `TextStyle(fontSize:)` at call sites
- [ ] Every text style is a named `AppType` role
- [ ] Small crimson text uses `accentText`; small text on glass follows `GlassColors.text`
- [ ] Gold only on Pro/trial, green only for done
- [ ] Touch targets ≥ 48
- [ ] At most 3 blurs on screen, none in a list item or card, none animated
- [ ] Looks right at `full`, `tinted` and `solid`, and at 200% text, high contrast, 320px
- [ ] Reduced-motion path returns the static widget
- [ ] Haptic fires on commits/successes, not on every tap of everything
- [ ] `flutter analyze` clean; goldens in `test/golden/` regenerated if shared components changed (Windows renderer: `flutter test --tags golden --update-goldens`)
- [ ] New shared components added to `lib/debug/component_gallery_screen.dart`
- [ ] Anything that blurs was looked at in profile mode on a real phone (`integration_test/glass_frame_benchmark_test.dart`)

## Companion skills

For HIG *principles* reach for `ios-hig-design` / `mobile-ios-design` — but note
they emit SwiftUI. Translate their intent through the tokens above; never copy
their code. For motion critique use `design-motion-principles` (audit mode is
good at catching slop). For layout mechanics use `flutter-build-responsive-layout`
and `flutter-fix-layout-issues`.
