# FIGHTER EDGE — Design System & UI/UX Plan

_Written 2026-09-16. Every number below was measured against the code in `lib/`,
not estimated. 96 Dart files, ~16,000 lines, 18 screens._

**Guiding order: fix the chassis → then the feel → then the surfaces.**
Tokens before components, components before screens, golden tests before the screen pass.

---

## 0. The thesis

The ask was "Apple-style design system." Applied literally that would kill this app:
Apple's system is calm, deferential and content-first; FIGHTER EDGE is dark, crimson,
condensed-uppercase and says "The Grind Never Lies." Those are not the same product.

**What we take from Apple is the chassis, not the skin:** the type scale, the 8pt grid,
spring-based motion, 44pt targets, Dynamic Type, real material depth, and the discipline
of spending attention in few places. What stays is the brand: crimson accent, Oswald
condensed display type, fight-night backdrop.

The premium feeling in Whoop / Strava / Fitness+ does not come from more gradients.
It comes from **restraint plus responsiveness** — few type sizes, generous body text,
one loud element per screen, and every single touch answering back within 100ms with
motion and haptics. This app currently has the gradients and not the responsiveness.

---

## 1. What the audit found

### Already good — do not "fix" these

| Area | Evidence |
|---|---|
| Spacing discipline | 595 `Insets.*` uses vs 39 raw numerics, **0** raw `EdgeInsets` literals |
| Color token discipline | Only 11 hardcoded `Color(0x…)` literals outside `lib/theme/` |
| Reduced-motion support | `MediaQuery.disableAnimationsOf` respected in page transitions, `PremiumReveal`, nav |
| Contrast (most colors) | `textSecondary` 8.64:1, `premium` 12.60:1, `positive` 9.97:1 on background — AAA |
| Layering architecture | `features/edge_fuel/**` is cleanly domain/data/presentation |

### The real problems

**1. There is no type scale — there are 19 font sizes across 266 call sites.**

```
13pt ×55   12pt ×47   14pt ×28   11pt ×23   22pt ×14   18pt ×11   20pt ×9
16pt ×9    15pt ×9    30pt ×5    24pt ×5    10pt ×5     9pt ×3    34pt ×2
28pt ×2    64pt ×1    52pt ×1    38pt ×1    17pt ×1
```

`AppTheme.display(double)` / `AppTheme.body(double)` accept *any* number, so every call
site invents its own. Three near-identical small sizes (11/12/13) do overlapping jobs.
9pt and 10pt text is below the iOS 11pt legibility floor. And iOS body text is 17pt —
this app uses 17pt exactly **once**, so every screen reads small and cramped next to a
native app. This is the single largest cause of "it doesn't feel premium."

**2. Both variable fonts are mis-declared, so weights are being faked.**

```yaml
- family: Oswald
  fonts:
    - asset: assets/fonts/Oswald-Variable.ttf
      weight: 700          # ← tells Flutter this file IS the 700 face
- family: Inter
  fonts:
    - asset: assets/fonts/Inter-Variable.ttf   # ← no range declared
```

The code asks for `w500`, `w600`, `w700`, `w800`. With a single declared face, Flutter
matches the nearest file and synthesizes the rest instead of driving the font's `wght`
axis. Text is subtly muddy everywhere. Since Flutter 3.41 `FontWeight` drives the `wght`
axis directly — this is nearly a one-line fix with a visible quality jump.

**3. Interaction feel is Material, not premium.**

- **Haptics in 2 files out of 96** (`round_timer_screen`, `serving_stepper`). Nothing on
  tab changes, card taps, filter chips, logging a weigh-in, completing a session.
- `PressScale` — the correct press response — **exists and is used exactly once**
  (`recipe_card.dart`). Everything else uses Material `InkWell` ripple, which is the
  single clearest "this is an Android app" tell on a dark premium surface.
- The bottom nav's `surfaceGlass` (`0xF216161E`) is **opaque paint pretending to be
  glass** — there is no `BackdropFilter` anywhere in the app.

**4. The stagger animation is subtly wrong.** `dashboard_screen` stages reveals with
durations 420 / 500 / 580ms. Different *durations*, identical *start times* — so
everything moves at once and finishes raggedly. A stagger is a shared duration with
offset *delays*.

**5. Two screens are fully built and unreachable.** `TechniqueLibraryScreen` (309 lines)
and `CornerCoachScreen` have **zero inbound navigation edges**. The technique library —
arguably the app's most distinctive feature — is dead code in the nav graph, while
nutrition owns a whole tab.

**6. The chrome is inconsistent on exactly the screens users see most.** `ScreenScaffold`
(which supplies `PremiumBackground` + shared header) is used by 13 files, but
`dashboard`, `nutrition`, `training_camp`, `technique_library`, `more` and `home_shell`
all hand-roll a raw `Scaffold`.

**7. Component drift.** 55 bespoke `BoxDecoration`s vs 40 `AppCard` uses — more custom
surfaces than system ones. Thirteen distinct near-black shades are in play once the
improvised gradient colors (`0xFF1B1B25`, `0xFF23232A`, `0xFF15141B`, `0xFF121218`…)
are counted alongside the five surface tokens. That is what makes a dark UI read muddy
rather than crisp.

**8. Accessibility gaps.**

- **Dynamic Type is unsupported** — `textScaler` appears 0 times; every size is hardcoded,
  and fixed heights (`126`, `142`, `42`) will clip when a user raises text size.
- `Semantics` on 6 of 18+ raw tap targets, plus ~40 unlabeled `AppCard` taps.
- Measured contrast failure: **`primary #E63328` on `surfaceElevated` = 3.70:1**, below
  the 4.5 AA floor — and `primary` is used for 10pt category labels on elevated cards.

**9. Cold start is a blank dark frame.** `main()` awaits `Firebase.initializeApp()`
*before* `runApp()`, with no error handling. First impression of the app is nothing,
then everything. There is no launch screen continuity.

**10. Navigation is imperative.** `MaterialPageRoute` everywhere + a custom global page
transition. On iOS that overrides `CupertinoPageTransitionsBuilder` and **kills the
interactive swipe-back gesture** — one of the most-felt native affordances.

---

## 2. The target system

### 2.1 Type scale — 22 sizes → 10 roles ✅ SHIPPED

Semantic names, not numbers. Implemented in `lib/theme/app_typography.dart` as `AppType`.

Two corrections to the original draft, both found by measuring rather than guessing:

- The audit counted 19 sizes by grepping integers. There were also **11.5, 12.5 and 13.5** —
  the real figure was **22**.
- `display()` is Oswald and `body()` is Inter, and they barely overlap: Oswald carried
  13 sizes (15→64), Inter carried 8 — **all of them 16 or below.** The app had no
  comfortable reading size at all, which is the specific cause of "cramped."

The two hero numerals stayed separate rather than collapsing into one: 64 is the round
timer and 52 the weight hero, both genuine full-screen moments, and merging them would
have served tidiness over the product.

| Role | Size / weight | Font | Absorbs | Use |
|---|---|---|---|---|
| `heroNumeral` | 64 / w700 | Oswald | 64 | Round timer digits |
| `display` | 52 / w700 | Oswald | 52 | Full-screen hero figures |
| `largeTitle` | 30 / w700 | Oswald | 28, 30, 34, 38 | Screen hero titles |
| `title1` | 22 / w700 | Oswald | 20, 22, 24 | Card titles, step questions |
| `title2` | 18 / w700 | Oswald | 15, 16, 17, 18 | Screen headers |
| `headline` | 17 / w600 | Inter | — | Emphasized rows (weight, not scale) |
| `body` | 17 / w500 | Inter | 16 | **Default body — the app had no such role** |
| `callout` | 15 / w500 | Inter | 13.5, 14, 15 | Secondary copy |
| `subhead` | 13 / w500 | Inter | 11.5, 12, 12.5, 13 | Metadata, captions |
| `micro` | 11 / w700 +0.8 | Inter | 9, 10, 11 | Uppercase eyebrows only |

Sizes were kept close to their originals deliberately: Phase 1 is a *structural* change.
Pushing the dense 13pt tier up to a more generous 14–15 is a visual decision that belongs
in Phase 4, behind golden tests.

**Optical sizing.** Inter ships an `opsz` axis (14–32) that was pinned at its 14 default
for every size in the app — large text was rendering with letterforms drawn for captions.
Flutter maps `FontWeight` onto `wght` automatically but never touches `opsz`, so `AppType`
now sets it per role. Oswald's `wght` axis stops at **700**; one call site asked for w800
and was getting a synthesized fake. `scaledDisplay` now clamps.

### 2.2 Color — roles, not raw values

Keep the palette, add a semantic layer exposed through `ThemeExtension` so widgets read
from `context` rather than importing a static class:

- Surfaces collapse to **3 elevation steps** (`surface` / `surfaceRaised` / `surfaceOverlay`),
  each with one tint rule. The 13 improvised gradient shades fold into these.
- Add the missing state roles: `onAccent`, `accentPressed`, `accentDisabled`, `borderFocus`.
- **Fix the AA failure:** `primaryBright` (4.83:1 on elevated) becomes the token for
  small text on raised surfaces; `primary` stays a *fill* color, not a text color.

### 2.3 Motion — springs, not one cubic curve

| Token | Spec | Use |
|---|---|---|
| `press` | scale 0.97, 90ms | Every tappable surface |
| `snap` | spring, stiffness 380 / damping 28 | Chips, toggles, tab switches |
| `settle` | spring, stiffness 220 / damping 30 | Cards, sheets, reveals |
| `reveal` | 380ms + **40ms per-item delay** | Entrance stagger (fixes the bug above) |

Springs are interruptible; cubic curves are not. That difference is most of what "fluid"
means on iOS.

### 2.4 Haptics — a facade, applied everywhere

| Event | Feedback |
|---|---|
| Tab / filter change | `selectionClick` |
| Card or row tap | `lightImpact` |
| Commit (log weigh-in, start session) | `mediumImpact` |
| Session complete, streak extended | success pattern |
| Destructive / error | `heavyImpact` |

Cheapest premium upgrade in the entire plan.

### 2.5 Material depth — real blur, used sparingly

Bottom nav and sheets get `ClipRRect` + `BackdropFilter(ImageFilter.blur(20, 20))` with a
hairline top border. `BackdropFilter` is expensive: keep it to small, static, tightly
clipped regions and profile on a low-end Android before shipping. Nothing else in the app
gets blur.

---

## 3. Flow / IA changes

**Tabs: Home · Train · Fuel · Profile** (replaces Home / Camp / Fuel / More)

- **Train** absorbs the camp calendar, the technique library and the round timer — this
  gives `TechniqueLibraryScreen` a real home instead of orphan status.
- **Profile** replaces the "More" dumping ground; Settings moves behind the profile
  avatar, where iOS users expect it.
- Weight tracker stays reachable from both the dashboard stat card and Profile.

**Decision required:** `CornerCoachScreen` — wire it into Train, or delete it. It has been
unreachable long enough to be a liability either way.

**Routing:** adopt `go_router` for typed routes, deep links and state restoration, and use
`CupertinoPage` on iOS so **interactive swipe-back works again**. Keep the custom
transition for Android only.

**Headers:** replace the fixed centered uppercase bar with `CustomScrollView` +
a collapsing large title. Keep the uppercase Oswald treatment *as* the large title —
brand preserved, behavior native.

**Cold start:** render the first frame immediately with a branded launch state that matches
the native splash, initialize Firebase after, and handle init failure instead of crashing.

---

## 4. The plan

Each phase is independently mergeable and separately reviewable. Phases 1–2 change almost
nothing visually — that is the point; they make Phase 4 cheap.

### Phase 1 — Chassis (no visual change intended) ✅ DONE 2026-09-16

_46 files changed, 255/255 tests green, analyzer clean._

- [x] Fix both variable-font declarations in `pubspec.yaml` — the explicit `weight: 700`
      on Oswald pinned it to a single face; both are now declared bare
- [x] Add `AppType` with 10 roles (`lib/theme/app_typography.dart`), including per-role
      `opsz` for Inter; `AppTheme.display()`/`body()` kept as `@Deprecated` shims that
      snap any passed size to the nearest role, so nothing breaks mid-migration
- [x] Migrate all 265 call sites across 43 files to roles
- [x] Populate the full `TextTheme` + `ColorScheme` so Material widgets inherit the system
- [x] Add `Insets.xxs = 2` / `Insets.xxxl = 40`; migrate the 28 exact-match raw numerics
- [x] Fix `primary`-on-elevated contrast: new `AppColors.accentText` token applied to the
      12 small-text accent uses (title-sized uses are fine — large text needs only 3:1)
- [x] Add spring motion tokens (`SpringCurve`, `MotionTokens.snap` / `.settle` /
      `.stagger`) ready for Phase 2 to apply
- [~] **`ThemeExtension` deliberately skipped.** Its payoff is theme switching and
      animated theme transitions; with dark-only confirmed there is nothing to switch
      between, so it would add an indirection layer for no behavioral gain. Static
      `AppColors` stays. Revisit only if light mode is ever adopted.

**Left for Phase 4 (each moves pixels, so they want goldens first):** the 11 remaining
off-grid spacing values (3, 5, 14, 38), and raising the dense 13pt tier for generosity.

### Phase 2 — Components ✅ DONE 2026-09-16

_49 files changed, 255/255 tests green, analyzer clean._

- [x] Promote `PressScale` to `lib/widgets/` (from `edge_fuel/`); apply everywhere a
      surface is tappable — `AppCard`, `PrimaryButton`, `GhostButton`, nav, both chip
      widgets, every auth/setup/onboarding icon button, the recipe card, the paywall
      plan toggle
- [x] Remove Material ripple app-wide: `splashFactory: NoSplash.splashFactory` in
      `AppTheme.dark()`, and **every** `InkWell`/`GestureDetector` in `lib/` converted to
      `PressScale` first (12 call sites) — setting `NoSplash` alone would have made any
      surviving `InkWell` give zero feedback, worse than the ripple it replaced
- [x] Add `AppHaptics` facade (`lib/theme/app_haptics.dart`) with the five events; wired
      at every `PressScale` call site plus the real commit/success moments the plan
      named — logging a weigh-in, completing a session (both the round-timer and the
      manual camp-screen path), and the round timer's own phase alerts, which were
      raw `HapticFeedback.heavyImpact()`/`mediumImpact()` calls now routed through the
      facade (heavyImpact was actually the session-complete *success* case misusing the
      warning weight — fixed to `AppHaptics.success()`'s two-beat pattern)
- [x] Add spring motion tokens (shipped in Phase 1); `PremiumReveal` now takes an
      `index` and delays by `index × MotionTokens.stagger` instead of varying duration
- [x] Give the bottom nav a real `BackdropFilter` (`ImageFilter.blur`, clipped to the
      bar's own rounded bounds) — also fixed `surfaceGlass` from 95% to 72% opacity,
      since at the old value the blur behind it was invisible and the "glass" was
      just paint
- [x] Add `Semantics` to every tap target found missing one: 6 → 20 `Semantics(`
      sites. Notably `RecipeCard` (title + description + 3 macros + allergen warning
      were 6+ separate fragments to a screen reader on every list item), `StatCard`
      (merged so "Weight, 184.2 lbs, 1.2 lbs" reads as one measurement), the paywall
      plan toggle (now announces selected state), and three icon-only +/- steppers
      that had no accessible name at all (food/training setup, onboarding day-picker)
- [x] Audit tap targets to 44pt: fixed the camp screen's circular start button
      (40→44) and, more significantly, found the **app's most-used segmented
      control** (`FilterChips`, driving technique-library/weight-tracker/round-timer
      tabs) had no minimum height at all — text + padding alone landed near 37px
- [ ] **BoxDecoration count deferred, and the number moved the wrong way on paper:**
      65 now vs 55 at audit time. Converting `Material(color:) + InkWell` to
      `DecoratedBox(decoration: BoxDecoration(color:))` is mechanically one
      `BoxDecoration` literal where a bare color prop stood before — a side effect of
      killing the ripple, not the "surface soup" the audit meant. The actual
      consolidation (fewer *bespoke, one-off* surfaces bypassing `AppCard`) is
      unstarted and stays a Phase 4 job behind goldens, since it moves pixels.
- [ ] **Low-end-device blur profiling not done.** No physical device or emulator was
      available this session — the nav's `BackdropFilter` is implemented per the
      plan (small, static, tightly clipped) but its frame cost is unverified. Do this
      before Phase 4 ships more blur anywhere else.

### Phase 3 — Safety net (before touching screens) ✅ DONE 2026-09-16

_Added component goldens before the Phase 4 screen pass._

- [x] Golden tests for shared primitives through
      `test/golden/component_gallery_golden_test.dart`: `AppCard`, `PrimaryButton`,
      `GhostButton`, `FilterChips`, `StatCard`, `PressScale`, `ProgressRing`,
      `PremiumBadge`, and `AppBottomNav`
- [x] Dark-only baselines captured at default text scale and 1.6x text scale. The
      original "light + dark" note was reduced because dark-only was already
      decided; adding fake light goldens would protect no real product surface.
- [x] A debug-only `/gallery` route renders the same component gallery used by
      the goldens, without adding Widgetbook or another dependency to the MVP
- [x] CI fails on golden diff through the existing `flutter test` job, because
      golden assertions are part of the normal test suite
- [x] The first golden run caught a real bottom-nav overflow. `AppBottomNav`
      now keeps labels inside the reserved tab height by fitting long or scaled
      labels instead of clipping.

### Phase 4 — Screens

- [x] Move `dashboard`, `nutrition`, `training_camp`, `more` onto `ScreenScaffold`
      — started 2026-09-16 with `ScreenScaffold.tab`, so tab pages share the
      premium background/header without nesting another full scaffold inside
      `HomeShell`. The helper falls back to a local `Scaffold` when a tab
      screen is rendered standalone in widget tests.
- [x] Collapsing large-title header, applied to all tab screens
      — implemented in `ScreenScaffold.tab` as a shared tab-only header that
      listens to vertical scroll notifications and collapses from the large
      brand title to the compact header.
- [x] Dashboard: one loud element (Today's Focus), everything else quieted; kill the
      fixed 126/142 sizes so it survives Dynamic Type
      — stat cards now adapt between a three-column row and stacked cards
      instead of living inside a fixed-height horizontal rail.
- [ ] Re-IA the tabs to Home / Train / Fuel / Profile; wire the technique library in
- [ ] Decide and act on `CornerCoachScreen`
- [x] Adopt `go_router`; restore iOS swipe-back via `CupertinoPage`
      — app shell now uses `MaterialApp.router` with named `go_router` routes
      backed by `CupertinoPage`. Static routes (auth subpages, paywall, More
      tools, EdgeFuel plan/setup/recipes) use named routes with test-safe
      fallback navigation; object-carrying detail routes use `CupertinoPageRoute`.
- [x] Onboarding: one question per screen, skippable, progress visible
      — global account onboarding is now a four-step flow with visible progress,
      one focused question per step, back navigation, and skip paths that start
      a fresh camp without forcing a starting weigh-in.
- [ ] Paywall: value before price, honest trial framing, single primary action

### Phase 5 — Accessibility & polish

- [ ] Dynamic Type support end to end; clamp scaling only on `heroNumeral`
- [ ] Verify at 200% text size — no clipping, no overflow
- [ ] Respect `MediaQuery.boldTextOf` and `highContrastOf`
- [ ] Branded cold-start; Firebase init moved off the boot-blocking path
- [ ] Profile on a low-end Android: blur regions, gradient repaints, list jank

---

## 5. Skills, plugins and tooling

### Use from this session (already available)

| Tool | Use it for |
|---|---|
| `/code-review` | Every phase PR — it is diff-scoped, which suits mechanical migrations |
| `/simplify` | After Phase 1 and Phase 2, to catch the shims and duplication left behind |
| `design` skill (Claude Design canvas) | Mock the re-IA'd tab bar and new dashboard *before* writing Dart |
| `artifact-design` | Producing the spec/report collateral for review |
| `find-skills` | Locating the Flutter design-system skills below |
| Playwright MCP | Only useful against `flutter run -d chrome`; golden tests are the better fit |

### Worth installing

- **Frontend Design** — Anthropic's official plugin, the most-installed in the directory
  (~277k installs); wires the agent into design tokens, screenshots and layout reasoning.
  This is the highest-value single install for this work.
- **Flutter UI Design Systems** / **Flutter UI Development** (marketplace skills) —
  Flutter-specific patterns for Material 3 + Cupertino, ~1,700 lines of curated patterns.
- **Widgetbook** (a Flutter package, not a plugin) — the component gallery for Phase 3.

### The real visual-regression tool

For Flutter, **golden tests are the answer**, not browser screenshot diffing.
`flutter test --update-goldens` produces reference images; CI fails on drift. Build them in
Phase 3 *before* the screen pass, or Phase 4 will be unreviewable.

---

## 6. Approach

1. **Tokens first, and ship them invisible.** Phases 1–2 should produce almost no visual
   diff. If reviewers see nothing change, the migration was correct.
2. **One mechanical PR per concern.** The 266-call-site type migration is a single
   reviewable diff; mixing it with visual changes makes both unreviewable.
3. **Golden tests before screens.** Non-negotiable — it is the only way to change 18
   screens without regressions.
4. **Spend the loudness budget deliberately.** One loud element per screen. Everything
   else recedes. This is the whole difference between "aggressive" and "cheap."
5. **Verify on device, at 200% text, on a low-end Android.** Blur and gradients are where
   premium ambitions meet frame budgets.

---

## 7. Open decisions for Mahdi

1. **`CornerCoachScreen`** — wire into Train, or delete?
2. **Technique library content** — the screen still shows "Video playback unlocks once
   real sources are connected." The re-IA gives it a home; it needs content to justify one.
3. **Tab rename** — is "Camp" → "Train" acceptable, given "fight camp" is the domain term?
4. ~~**Light mode**~~ — **decided 2026-09-16: dark-only.** It is the brand, there was no
   light-mode code to preserve, and the token layer is structured so a light palette could
   be added later without reworking call sites. This is why `ThemeExtension` was skipped
   in Phase 1.
