# UI polish audit: removing the template look (2026-09-25)

Read-only audit. No code was changed. Scope: every main screen on the offline
build (`-t lib/main_local.dart`) at 390 px, plus a code sweep of `lib/`
(151 UI files) against the `fighter-edge-ui` contract.

**Verdict.** The foundations are good: typography is fully tokenised, motion is
restrained and honours reduced motion almost everywhere, and haptics are used
sparingly. What makes the app read as template-built is not the tokens but how
often they are stacked: glows, gradients, coloured borders, icon tiles and
cards on nearly every element, so nothing stands out. Profile already shows the
fix: grouped rows, hairline dividers, one accent. The work is mostly
subtraction.

## What is already right (keep it)

| Area | Evidence |
|---|---|
| Type | 0 raw `fontSize`, 1 `TextStyle(` outside the theme. Every text uses an `AppType` role. |
| Accent contrast | 0 cases of `AppColors.primary` used as body text colour. |
| Motion | 1 `AnimationController` in the app (skeleton). `PremiumReveal` stagger is correct. Only 2 files animate without a reduced-motion check. |
| Haptics | 34 calls, spread across `success/commit/selection/warning/tap`. No haptic spam. |
| Profile screen | Grouped list with dividers, one accent. This is the reference pattern. |

## Findings, ranked by visual impact

### P1: app-wide, fix once in a shared component

1. **Background glow on every screen.** `PremiumBackground` (`lib/widgets/premium_effects.dart:11`)
   paints a red radial glow top-right and a blue one bottom-left behind all
   screens, via the scaffold. It is decoration that explains nothing.
   *Fix:* flat `AppColors.background`; depth comes from the surface steps.

2. **Every card shouts.** `AppCard` has 67 call sites; 32 pass a coloured
   `accent:` border, 8 pass their own gradient, 6 add a shadow. Three red-bordered
   cards sit on the dashboard alone. When every card is outlined, none is.
   *Fix:* default `AppCard` to no border on `surface`; allow at most one
   accented element per screen (the primary action or live state).

3. **The icon-tile pattern.** 29 places draw a 40–48 px rounded square filled with
   `primarySoft`/`surfaceElevated` holding an icon, then title, subtitle and
   chevron. It is the most recognisable generated-UI layout.
   *Fix:* use leading icons only where they identify something (a discipline,
   a food group); drop them from settings, stats and summary rows.

4. **Cards inside cards.** Onboarding option cards sit inside a bordered card
   (three outlines deep); the dashboard nests the EdgeFuel card inside Today's
   focus; Fuel nests meal suggestions inside the Meals card.
   *Fix:* one container level. Inner content becomes rows.

5. **Stock and custom components mixed.** 6 stock `AlertDialog`s, 7 raw
   `SnackBar` constructions, a stock `FloatingActionButton` (weight tracker),
   next to fully branded sheets. *Fix:* shared `AppDialog`, `AppSnackBar`,
   and replace the FAB with a header action.

6. **Glow under buttons.** `PrimaryButton` casts a red `BoxShadow`
   (`lib/widgets/primary_button.dart`). Apple's filled buttons are flat.
   *Fix:* remove the shadow; keep the pressed-scale feedback.

### P2: screen structure

7. **Dashboard does everything at once** (`lib/screens/dashboard_screen.dart`).
   10 stacked blocks. The same next session appears twice (Today's focus and
   Next Session), each with its own red start button. Streak appears three
   times. A static "Why this target matters" explainer shows on every visit.
   4 bespoke gradient cards use raw `Color(0x…)` values (lines 180, 300, 816, 962).
   *Fix:* one hero (today's session and one Start), one compact stats row,
   then this week. Move the explainer behind an info tap.

8. **Fuel repeats the target three times** (`lib/screens/nutrition_screen.dart`).
   "2160 kcal · 2160 left", the ring "0 / 2160", and "2160 kcal left today",
   plus the macros twice (pills and ring bars).
   *Fix:* the ring is the hero; the target card and the "left today" card merge
   into it; the recipe link becomes a row.

9. **Settings uses one card per row**, while Profile groups rows.
   *Fix:* grouped sections like Profile.

10. **Onboarding carries the full logo and tagline on every step**, and each
    step has a red uppercase eyebrow ("FRESH ACCOUNT", "NUTRITION GOAL"), a
    bordered card, and a full-width BACK button competing with CONTINUE.
    *Fix:* logo on the welcome page only; progress bar at top; back as a header
    chevron; the question as the heading, no eyebrow.

11. **Plan-ready screen puts the Pro upsell above "Open dashboard"** on first
    run, and lays out the macro tiles 1-then-3.
    *Fix:* primary action first; the upsell below it, quieter; 4 equal tiles or
    one line of numbers.

12. **Train week: four red play circles** in one view. When every row has the
    brightest element on screen, there is no next action.
    *Fix:* red only on today's (or the next) session.

### P3: template tells and copy

13. **Sparkle icon** (`Icons.auto_awesome`) in 8 places, including the
    onboarding summary and plan-ready upsell. It is the generic "AI" glyph.
    Keep it only on the AI coach entry point, or replace with a product icon.
14. **Welcome page hero:** glowing ringed icon above the headline with green-check
    "feature pills". The glow is clipped into a visible square edge.
15. **Login:** a tiled "FIGHTER EDGE CAMP" watermark baked into
    `assets/images/login_background.webp`; a plain letter "G" instead of Google's
    official mark (Google's sign-in branding rules require the mark).
16. **`GradientText`** ("React-Bits-style", `premium_effects.dart:79`) exists only
    in the component gallery. Dead code; delete.
17. **Gold outside Pro:** the dashboard streak card and the Fuel target card use
    the gold/amber border. The contract reserves `premium` gold for Pro.
18. **Copy:** debug-style joins ("4-day Beginner camp - Maintain - Build
    fight-camp structure"); an enum inside a sentence ("a starting point for
    lose fat"); marketing lines ("Unlock your full edge", "Watch the edge
    build.", "Food you can actually cook"). Plain and specific reads as more
    premium.
19. **Uppercase everywhere:** 20 `toUpperCase()` calls plus uppercase button
    and section styles. Keep Oswald uppercase for screen titles and big numbers;
    sentence case for buttons and section labels.
20. **Truncation:** dashboard stat card cuts "Add weigh-in" to "Add weig…" at
    390 px.

### P4: token hygiene (mechanical)

- Radii off the scale: `BorderRadius.circular(12)` ×12, `18` ×5, `10` ×4,
  `11` ×3 (tokens are 14/16/24/100). Add a `Radii.tile` or map to existing.
- 42 raw `EdgeInsets` numbers and 8 raw `SizedBox` sizes outside `Insets`.
- 11 raw `Color(0x…)` in `dashboard_screen.dart`, `paywall_screen.dart`,
  `bottom_nav.dart`, `premium_effects.dart`; 15 raw `Colors.white/black`.
- 4 raw `Duration(milliseconds:)` and 4 `Curves.*` outside `MotionTokens`.
- Reduced motion missing in `edge_fuel_setup_screen.dart:207`
  (`AnimatedContainer`) and `onboarding_screen.dart:155` (`AnimatedSwitcher`).

## Proposed slices (one per session)

**Status:** slice 1 done 2026-09-26 (see CLAUDE_CODE_HANDOFF.md).
Task slice D (audit slice 4) done 2026-09-26: quiet welcome, progress/back
header, plain options/summary and dashboard-first plan ready; 675 tests pass.
Task slice C (audit slice 3) done 2026-09-26: one Fuel hero, segmented tabs,
divided meal rows and one highlighted training start. 671 tests, 3 goldens.
Task slice B (audit slice 2) done 2026-09-26: one hero, compact checklist,
readable stats and grouped week/activity. 667 tests, 3 unchanged goldens.
Task slice A done 2026-09-26: injected streak clock, fixed Wednesday tests,
Saturday at-risk coverage. 664 tests and 3 unchanged goldens pass.

| # | Slice | Touches | Risk |
|---|---|---|---|
| 1 | **Shared components:** flat background, quiet `AppCard` default, flat `PrimaryButton`, `AppDialog`, `AppSnackBar`, delete `GradientText`, radius tokens | `lib/widgets/`, `lib/theme/`, goldens | Changes every screen at once; goldens must be reviewed by eye |
| 2 | **Dashboard:** one hero, dedupe session/streak, explainer behind a tap | `dashboard_screen.dart` | Several widget tests assert on current text |
| 3 | **Fuel + Train:** single calorie hero; red only on today's session | `nutrition_screen.dart`, `training_camp_screen.dart` | Moderate |
| 4 | **Onboarding + plan-ready + welcome:** remove eyebrows/logo repetition/nested cards, reorder CTA, fix copy | `lib/screens/onboarding/` | Integration test walks this flow; re-run on CI |
| 5 | **Settings grouping, login mark, copy pass, token hygiene** | various | Low |

Each slice: no behaviour changes, goldens regenerated and reviewed, the full
suite (662 tests) green, and a browser pass at 390 px and 320 px.

## Not covered by this audit

- 200% text scale and high-contrast mode (the contract requires both; check in slice 1).
- EdgeFuel setup and coach screens, recipe detail, round timer, paywall at depth.
- Real devices; iOS rendering; light mode (the app is dark-only by design).
