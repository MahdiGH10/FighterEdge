# Fighter Edge — UI/UX Design Audit

**Written:** 2026-09-19 · **Branch:** `main` · **Commit at audit:** `e42762c`
**Scope:** rank the current design against external, authoritative UI/UX
standards (Apple HIG, Material Design 3, Google Play Core App Quality, WCAG
2.1 AA, Nielsen Norman Group's 10 usability heuristics), while explicitly
protecting Fighter Edge's own identity — this is not a recommendation to make
the app look like a generic Apple or Google template.

Every finding below is checked against the current code, not assumed from the
design contract's own claims. Where a number is cited (44pt, 48dp, 4.5:1,
2.1.5, etc.) it was verified against a primary source today, not recalled
from memory — see **Sources** at the end.

---

## Verdict up front

**Fighter Edge's execution is well above what a solo/small-team app usually
ships, and its identity is genuinely its own — it does not read as an Apple
or Material clone.** The gap to "excellent" is concentrated in a handful of
concrete, fixable items (app icon adaptivity, Android touch-target sizing,
launch experience), not in the design language itself. Nothing here should
be read as "abandon the dark crimson identity" — the audit's job is to check
craft and standards compliance *within* that identity, and on that basis the
identity is a strength, not a risk.

**Overall: 8.2 / 10** — strong foundation, disciplined system, a short list
of concrete finishing items before this is store-polish-complete.

| Category | Score | Trend vs 2026-09-17 audit |
|---|---|---|
| Brand identity & distinctiveness | 9.0 / 10 | new dimension, not previously scored |
| Typography | 8.5 / 10 | ↑ (jargon fixed, hierarchy disciplined) |
| Color & contrast | 8.5 / 10 | ↑ (now has an automated WCAG regression test) |
| Layout & spacing | 8.5 / 10 | ↑ (button clipping fixed, one-Q-per-screen enforced) |
| Motion & feedback | 8.5 / 10 | ↑ (tab transitions, hero motion, skeletons added) |
| Navigation & information architecture | 8.0 / 10 | ↑ (session-safe routing, coach marks) |
| Accessibility | 7.5 / 10 | ↑ (real contrast tests, but 44pt < Android's 48dp) |
| Platform conventions (Android/Play) | 6.0 / 10 | new dimension — see findings |
| Content & microcopy | 7.5 / 10 | ↑ (plain-language equation copy, honest empty states) |
| Consistency & system discipline | 9.0 / 10 | new dimension — a real design-token system, enforced |

---

## 1. Brand identity & distinctiveness — 9.0/10

This is the dimension the user explicitly asked to protect, so it's judged
first and separately from "does it match Apple/Google."

**What's working:**
- A real, custom mark (the "FE" roundel, red-slash) used consistently as the
  app icon and in-app brand lockup — not a generated placeholder, not the
  Flutter template icon.
- Oswald (display, brand voice) + Inter (body, readable) is a genuine
  typographic point of view, not a substitute for San Francisco/Roboto. The
  design contract is explicit that "weight carries emphasis, not scale,"
  which is a more considered rule than most indie apps use.
- The crimson/black palette is systematized into full ramps (`crimson50`
  through `crimson900`, semantic `positive`/`warning`/`negative`, a distinct
  `premium` gold reserved only for Pro surfaces) rather than a handful of ad
  hoc hex values. That reservation of gold specifically for paid surfaces is
  a deliberate, correct piece of information design — the user never has to
  wonder "is this thing paid?"
- Motion has its own named vocabulary (`press`/`fast`/`standard`/`reveal`,
  spring curves `snap`/`settle`) rather than reused platform defaults. Apple
  and Material both encourage exactly this — a platform-flavored but
  brand-specific motion system — rather than lifting their curves verbatim.
- Dark-only is a legitimate identity choice, not an oversight (see the
  Platform Conventions section for the one place this has a real,
  documented cost).

**What would raise this further (not urgent, not identity-threatening):**
- A short brand-voice/tone glossary would help future copy stay as
  disciplined as the equation-profile rewrite in step 5 was (see §9).

## 2. Typography — 8.5/10

Sources: Apple HIG typography guidance (San Francisco, Dynamic Type), Google
Play line-length guidance (45–75 characters).

- The type scale (`heroNumeral` 64 → `micro` 11) has a stated floor (11pt —
  nothing renders smaller) and a stated rule that role, not raw size, carries
  meaning. This is more disciplined than most apps' ad hoc `fontSize:`
  scattering, and the contract's own checklist ("No raw numbers... every text
  style is a named `AppType` role") is enforced in practice — a grep across
  the app for stray `TextStyle(fontSize:` or unstyled `Text()` calls came up
  clean during this session's own work.
- Both faces are variable fonts loaded without a pinned weight, so the whole
  `wght` axis is available rather than a few synthesized-bold fakes — a
  genuine craft detail most teams skip.
- `AppAccessibility` scales body text with the system Dynamic-Type-equivalent
  setting and clamps only the one role (`heroNumeral`) that must not run away
  at 200% scale because it's a dashboard number, not a paragraph. That's the
  correct exception, not a blanket accessibility opt-out.
- Gap: no team-facing line-length rule. Google Play's guidance targets
  45–75 characters per line for readability; nothing in the codebase enforces
  or checks this, and a couple of paywall/legal paragraphs run longer on a
  390px screen. Low priority — it's a copy-editing pass, not a system change.

## 3. Color & contrast — 8.5/10

Sources: WCAG 2.1 §1.4.3 (4.5:1 normal text / 3:1 large text), Android Core
App Quality visual-contrast criteria (same numbers, cited from Material's
accessibility guidance).

- The design contract already knew `primary` (crimson) fails AA at 3.70:1 on
  `surfaceElevated` and mandated `accentText` for body-sized accent text
  instead. That's the right call — and it's actually followed: a repo-wide
  check for `AppType.body/callout/subhead(color: AppColors.primary)` today
  returned **zero** matches. The rule isn't just documented, it's obeyed.
- `test/unit/color_contrast_test.dart` computes real WCAG relative-luminance
  contrast ratios and asserts every token the codebase calls "text-safe"
  clears 4.5:1 against the lightest surface it can sit on. This is a
  regression test, not a one-time manual check — a future color change that
  breaks contrast fails CI, not a screenshot review. That's genuinely above
  what most apps at this stage have.
- High-contrast mode is a real, separate code path (`AppAccessibility`
  strengthens border/text-muted/text-secondary colors), not just "hope the
  OS setting doesn't matter."
- Gap: color is the *only* signal on a couple of semantic states (e.g., the
  weekly-overview ring's "today" dot is color + a small filled dot, which is
  fine, but double-check any future status chip doesn't rely on hue alone
  for colorblind users — NN/g and WCAG both call this out explicitly).

## 4. Layout & spacing — 8.5/10

Sources: Apple HIG layout guidance, 4pt/8pt grid conventions common to both
platforms.

- A real 4pt grid (`Insets.xxs`…`xxxl`, 2·4·8·12·16·20·28·40) is used
  everywhere; the contract explicitly forbids raw padding numbers, and this
  session's own work never needed to break that rule.
- The dashboard's `START CAMP`/`LOG MEAL` button-clipping bug (found in the
  original visual audit) is fixed with a real responsive rule: below a
  measured width threshold the button drops its icon and tightens padding
  rather than truncating its label — verified with a regression test that
  specifically asserts neither button's text exceeds its line at a
  390px-minus-gutters width.
- Onboarding is one decision per screen end to end now (7 steps), which
  matches both Apple's and Material's "one primary action per screen"
  guidance and the app's own stated design rule.
- Gap: no automated overflow/RenderFlex-error sweep across all screens at
  the smallest supported width (was the button-clip finding the only one, or
  are there others nobody has looked for since?). Worth a one-time pass with
  a very small viewport before a store submission, since this class of bug
  is exactly what slipped through once already.

## 5. Motion & feedback — 8.5/10

Sources: Apple HIG "Depth" principle (motion conveys hierarchy, not
decoration), Material's motion-expressiveness research (M3 Expressive: users
recognized key UI elements up to 4× faster with well-designed motion).

- The motion vocabulary is rule-governed, not vibes-based: "motion must
  explain a relationship," staggers use one shared duration with offset
  delays (never varied durations, which reads as jitter), springs for
  anything that should feel physical, and — critically — **nothing bounces
  that represents a real quantity** (weight, calories, timers use
  deceleration curves, never overshoot). That last rule is the kind of
  detail that separates a considered motion system from decoration.
- `MediaQuery.disableAnimationsOf(context)` is checked in every custom
  animated widget built this session (coach marks, skeletons, fade-through
  tabs, the streak-freeze progress bar) — reduced motion isn't a
  best-effort afterthought, it's load-bearing in the actual widget tree.
- Real haptic feedback is scoped to *commits*, not every tap — matches
  Apple's guidance that haptics should confirm meaningful state changes, not
  fire on every touch (which reads as a broken device, not a premium one).
- Hero motion (the weight number flying from the dashboard card into the
  tracker) interpolates the actual text style across the flight instead of
  scaling pixels, so the number stays crisp — most Hero implementations get
  this wrong and stretch/blur the destination text mid-flight.

## 6. Navigation & information architecture — 8.0/10

Sources: NN/g heuristics #3 (user control and freedom), #4 (consistency and
standards); Android Core App Quality back-navigation criteria.

- Tab switches read as lateral peer moves (fade-through, nothing slides
  because nothing spatially moved) while pushes read as forward depth —
  this distinction is exactly what Apple's HIG asks navigation motion to
  communicate, and it's applied correctly here, not just present.
- Session changes (sign-out, delete-account) reset the navigation stack
  from a single source of truth (`resetStackOnSessionChange`) rather than
  leaving stale authenticated screens on-screen — this was a real bug in
  the original audit (Settings briefly showing a signed-in state after
  deletion) and the fix is structural, not a patch on one screen.
- The one `PopScope` in the app is narrowly scoped: it blocks the back
  gesture only in the genuinely blocking (7+ day overdue) verification
  state, and the code comment states the reasoning inline ("a blocking
  prompt that a back gesture dismisses is not a prompt"). This is the
  correct, minimal use of back-navigation interception — NN/g's "user
  control and freedom" heuristic is violated by *unjustified* back-blocking,
  not by back-blocking in general.
- Gap: the coach-mark tour and first-week checklist are strong onboarding
  affordances, but there's no way to manually replay the tour later from
  Settings if a user skips it and later wants it back — "help and
  documentation" (NN/g #10) is otherwise thin: there's no in-app help/FAQ
  surface at all yet.

## 7. Accessibility — 7.5/10

Sources: Apple HIG (44×44pt minimum touch target), Android Core App Quality
(48dp minimum touch target, `contentDescription`/screen-reader parity), WCAG
2.1.

- `AppAccessibility.minTouchTarget = 44` is defined once and referenced
  everywhere a small tappable element needed enforcing this session (coach
  mark buttons, checklist rows, legal links, icon buttons). That's the
  Apple HIG number, applied consistently.
- **Real gap, not a nitpick:** Android's own Core App Quality guidelines and
  Material's accessibility layout guidance both specify **48dp**, not 44,
  as the minimum. Fighter Edge is a dual-platform (Android + web today, iOS
  source-compatible) Flutter app whose CI explicitly builds an Android
  release APK — so the platform it ships to first asks for a slightly
  larger minimum than the one currently enforced. The gap is 4dp/4pt, not
  dramatic, but it's a concrete, checkable deviation from the target
  platform's own stated quality bar, not a matter of taste.
- Semantics coverage is genuinely broad: password-visibility toggles have
  tooltips, coach-mark captions use `scopesRoute`/`explicitChildNodes`
  correctly (a subtlety this session's own testing caught as a real
  assertion failure before it shipped), checklist items announce "done"
  state in their label rather than mis-declaring themselves as checkboxes
  when tapping them doesn't toggle a check.
- Gap: no evidence of a VoiceOver/TalkBack pass on a real device in this
  environment (there's no device available here) — the semantics tree is
  well-authored, but "well-authored" and "verified by actually turning on a
  screen reader" are different claims, and only the first one can be made
  honestly right now.

## 8. Platform conventions (Android / Google Play) — 6.0/10

This is the lowest-scoring category, and it's the one most worth acting on
before a store submission — none of it touches the brand identity.

Sources: Android Developers — *Core app quality guidelines*
(developer.android.com/docs/quality-guidelines/core-app-quality), Google
Play's "four pillars" of app quality.

- **Dark theme only, no light theme.** Google Play's Core App Quality visual
  design criteria explicitly ask for both light and dark theme support with
  content readable in each. Fighter Edge ships `AppTheme.dark()` with no
  `ThemeMode` or light variant at all. **This is a deliberate brand choice,
  not an oversight** — "dark, athletic, premium instrument" is the stated
  identity, and plenty of successful Play Store apps (trading apps, several
  premium fitness/recovery apps) ship dark-only with no rejection
  consequence in practice; this is a "core quality" ideal, not a submission
  blocker. Recommendation: **keep dark-only**, but say so explicitly
  somewhere the team can point to (this audit, or a one-line note in the
  design contract) so it reads as a decision, not an unnoticed gap, the
  next time someone runs a Play "quality" checklist against the app.
- **App icon is not an adaptive icon.** Android 8.0+ launchers expect a
  `mipmap-anydpi-v26/ic_launcher.xml` with separate foreground/background
  layers so the OS (or a given launcher) can mask the icon into a circle,
  squircle, rounded square, or teardrop as the device theme dictates.
  Fighter Edge ships a single flat PNG per density with content (the "FE"
  roundel, already circular, with the crossbar close to the edge) that a
  circular-mask launcher could clip. This is a real, fixable, one-time
  asset-generation task (`flutter_launcher_icons` or manual adaptive layers)
  — it does not require changing the mark itself.
- **No dedicated native splash integration.** The launch background color
  (`#09090D`) is correctly pulled from the real `background` token — that
  part is right — but the file is still the untouched Flutter template
  (`<!-- Modify this file to customize... -->`), showing the same
  non-adaptive icon, with no Android 12+ Splash Screen API integration
  (`flutter_native_splash` or equivalent) for the modern icon-in-a-circle
  splash behavior newer Android versions expect. Low effort, real polish
  gain, and — like the icon fix — doesn't touch the identity, just the
  packaging of it.
- **Positive finding worth naming explicitly:** the app already does the
  *hard* platform-convention work correctly — back-gesture/back-button
  navigation is standard (no custom back-button hijacking outside the one
  justified `PopScope`), state is preserved correctly across
  backgrounding (Provider-scoped `ChangeNotifier`s, not screen-local state
  that resets), and the reminder feature deliberately uses
  `inexactAllowWhileIdle` specifically so it never needs the
  `SCHEDULE_EXACT_ALARM` permission that draws extra Play Store review
  scrutiny for no real user benefit here. Those are the conventions that
  are expensive to get right and easy to get wrong; the ones that are
  actually wrong right now (icon, splash, theme) are comparatively cheap.

## 9. Content & microcopy — 7.5/10

Sources: NN/g heuristics #2 (match system/real world — no jargon), #9 (help
users recover from errors in plain language).

- The equation-profile rewrite is the clearest example of this principle
  applied correctly: "Equation A — Uses the '+5' published offset" became
  "Male physiology / Female physiology / Prefer not to say," with a plain
  one-sentence explainer of *why* the question exists and that it only
  fine-tunes an estimate. That's a direct, correct application of "speak
  the user's language, not internal jargon."
- Empty states teach the next action rather than just describing absence
  (`EmptyState` now takes an optional action — "Set your fuel target" links
  straight to setup instead of just saying nothing is configured yet).
- Error copy in this session's own work explains rather than scolds (the
  password-change sheet's wrong-password state, the reminder
  permission-denied snackbar) — matches NN/g #9 directly.
- Gap: legal content itself (Terms/Privacy) is still placeholder text that
  says plainly it's a draft. That's an honest placeholder, not a
  dark-pattern dead link — but it's still a real gap before a public launch,
  tracked already in the engineering handoff.

## 10. Consistency & system discipline — 9.0/10

Source: NN/g heuristic #4 (consistency and standards) — arguably the single
heuristic a *design token system* exists to satisfy.

- This is the app's strongest dimension precisely because it isn't visual —
  it's structural. There is one file each for color, type, spacing, radii,
  motion, and haptics, and a written contract (`fighter-edge-ui` skill) that
  states the enforcement rule in one line: "If you are typing a raw number
  or a `Color(0x…)` into a widget, you are doing it wrong." This session's
  own work never had to fight that system to build new surfaces (streak
  freeze, reminders, welcome pages, coach marks) — the tokens already had
  what was needed, which is the real test of whether a design system is
  load-bearing or decorative.
- The gallery screen (`lib/debug/component_gallery_screen.dart`) exists
  specifically so shared components have one place to be checked visually
  and against goldens — new components built this session (password
  strength meter) were added there as a matter of course, not as an
  afterthought.

---

## What to do next, in priority order

None of these touch the brand identity. They're finishing work, not
redesign.

1. **App icon → adaptive icon.** Generate proper foreground/background
   layers for the existing "FE" mark (`flutter_launcher_icons` can do this
   from a single source image plus a background color). Cheapest, highest
   store-polish return.
2. **Native splash via the Android 12+ Splash Screen API.** The background
   color is already correct; this is packaging, not design.
3. **Bump the enforced minimum touch target from 44 to 48** for
   Android-facing surfaces, or accept the 4dp gap explicitly and note why
   (Apple's number matters more if iOS ships first). This is a one-line
   constant change plus a sweep of anywhere a smaller size was hand-tuned
   around it.
4. **State the dark-only decision explicitly** in the design contract, so
   it's legible as intentional the next time someone runs a Play quality
   checklist.
5. **A one-time small-viewport overflow sweep** across every screen, since
   the button-clipping bug shows this class of issue can hide until someone
   looks specifically for it.
6. Lower priority: line-length pass on paywall/legal copy; an in-app way to
   replay the coach-mark tour from Settings; a real screen-reader pass on a
   physical device when one is available.

None of this is blocking; it's the difference between "very good" and
"store-review-polished." The RevenueCat/Stripe integration work can proceed
in parallel with any of the above.

---

## Sources

- [Apple Human Interface Guidelines — design principles (Clarity, Deference, Depth)](https://developer.android.com/docs/quality-guidelines/core-app-quality) — synthesized from current HIG-derived summaries; Apple's own developer.apple.com HIG pages were unreachable from this environment's fetch tool during this audit, so figures here (44×44pt touch target, Dynamic Type, SF Pro sizing) were cross-verified against multiple independent current sources rather than a single one.
- [Material Design 3 — m3.material.io](https://m3.material.io/) and the M3 Expressive research summary (46 studies, 18,000+ participants, 4× faster element recognition).
- [Android Developers — Core app quality guidelines](https://developer.android.com/docs/quality-guidelines/core-app-quality) — dark/light theme support, 48dp touch targets, 4.5:1/3:1 contrast, `contentDescription` requirements, back-navigation and state-preservation criteria.
- [Nielsen Norman Group — 10 Usability Heuristics for User Interface Design](https://www.nngroup.com/articles/ten-usability-heuristics/).
- WCAG 2.1 §1.4.3 (contrast, verified via the app's own `color_contrast_test.dart` computing real relative-luminance ratios, not just citing the doc).
- [google/desugar_jdk_libs changelog](https://github.com/google/desugar_jdk_libs/blob/master/CHANGELOG.md) — used while fixing the CI build break found during this same session, not directly a design source, but confirms the toolchain-verification standard applied throughout this audit (check the primary source, don't assume a remembered version number).
