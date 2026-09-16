# DESIGN SYSTEM HANDOFF — after Phase 3

Written 2026-09-16, by the sessions that did Phases 1, 2, and 3. Read this, then
`docs/DESIGN_SYSTEM_PLAN.md` for the actual task list — this doc is the
situational knowledge that plan file doesn't carry: what's already true in the
code, what to reuse instead of reinventing, and what looks like a bug but isn't.

This project's own house rule (`docs/START_HERE.md` PART 0) applies here too:
**one phase at a time, run the Definition of Done, commit, stop.** Phases 1 and
2 were each done and pushed as one commit before starting the next. Phase 3 is
now the visual safety net for Phase 4: keep it green before touching screens.

---

## Repo state right now

- Branch `main`, pushed through commit `40f0fec` (Phase 2). `f7d17e7` is Phase 1.
  Both pushed directly to `main` — no PR was opened for either. If you're
  expected to use branches/PRs instead, that's a question for Mahdi, not an
  assumption to make either way.
- Working tree is otherwise clean except two things that are **not part of
  this work** and shouldn't be touched or committed as part of it:
  `.playwright-mcp/` (tool scratch) and `docs/SESSION_HANDOFF.md` (a different,
  earlier handoff — unrelated content, don't merge or overwrite it).
- Phase 3 adds component goldens and may raise the test count above the old
  255/255 baseline. Trust the latest `flutter test` result over this historical
  number.

## Environment

- Flutter lives at `C:\src\flutter\bin`, **not on PATH**. Every command needs
  it prefixed, e.g. (PowerShell): `$env:PATH = "C:\src\flutter\bin;$env:PATH"`.
- This machine has Flutter 3.47.2 / Dart 3.13.2. `docs/START_HERE.md` PART 6
  says CI runs 3.47 vs a laptop's 3.12 and has caught real bugs local analysis
  missed — if your environment is older, don't trust a clean local analyze as
  the final word; let CI have the last say.
- **Definition of Done, every phase, before every commit** (from
  `docs/START_HERE.md` PART 6 — this is the project's standing rule, not
  something specific to this initiative):
  ```bash
  export PATH="/c/src/flutter/bin:$PATH"
  dart format .
  flutter analyze          # must say "No issues found"
  flutter test             # must be all green
  ```
- No device or emulator was available this session. Phase 2's `BackdropFilter`
  blur on the bottom nav is implemented per the plan (small, static, tightly
  clipped) but its real frame cost is **unverified**. If you have a low-end
  Android available, profile it before Phase 4 adds blur anywhere else.

## What Phase 1–3 actually did (summary — full detail is in the plan file)

Phases 1–3 are marked `✅ DONE` in `docs/DESIGN_SYSTEM_PLAN.md` with complete
task lists, deviations, and reasoning. Read those sections, not just this
summary, before starting Phase 4. Highlights that change how you should write
new code:

**Phase 1 — chassis.** The app now has a real type scale. Both variable fonts
were mis-declared (Oswald pinned to a single weight; Inter's `opsz` axis never
set) and are fixed. Contrast failure on small accent text is fixed via a new
color token. Full `TextTheme`/`ColorScheme` populated.

**Phase 2 — components.** Every tappable surface uses `PressScale`, not
Material's `InkWell`/ripple — `splashFactory: NoSplash` is set globally, so an
`InkWell` anywhere now gives **zero** feedback, not a ripple. `AppHaptics` is
the single vocabulary for physical feedback. `Semantics` coverage went 6→20
sites but is still not exhaustive.

**Phase 3 — safety net.** `lib/debug/component_gallery_screen.dart` renders the
shared component gallery used by `test/golden/component_gallery_golden_test.dart`.
The app exposes it through `/gallery` in debug builds only. Goldens cover the
default text scale, 1.6x text scale, and a pressed `PressScale` state. The first
run caught and fixed a real `AppBottomNav` overflow, so do not delete these
tests when they feel inconvenient; they are already paying rent.

## The vocabulary you must reuse — do not reinvent any of this

| Need | Use | Not |
|---|---|---|
| Any text size | `AppType.<role>()` (`lib/theme/app_typography.dart`) — 10 roles | A raw `fontSize:`, or `AppTheme.display()/body()` (deprecated shims, kept only so old code doesn't break) |
| Any tappable surface | `PressScale` (`lib/widgets/press_scale.dart`) | `InkWell`, `GestureDetector`, or `Material`+ink for feedback |
| Physical feedback | `AppHaptics.<event>()` (`lib/theme/app_haptics.dart`) — `selection/tap/commit/success/warning` | Raw `HapticFeedback.*` calls |
| A card/surface | `AppCard` (`lib/widgets/stat_card.dart`) first | A bespoke `BoxDecoration` — only reach for one when `AppCard` genuinely doesn't fit, and say why in a comment |
| Entrance animation | `PremiumReveal(index: n)` for a staggered group | A `TweenAnimationBuilder` with a hand-tuned duration per item |
| Motion curve/duration | `MotionTokens.*` (`lib/theme/app_theme.dart`) — `press/fast/standard/reveal/stagger`, `snap`/`settle` springs | A literal `Duration(milliseconds: …)` or `Curves.*` |
| Spacing | `Insets.*` | A raw number |
| Small accent-colored text | `AppColors.accentText` | `AppColors.primary` — it fails AA contrast below ~18pt |

If you find a gap in this vocabulary (a motion or feedback case that doesn't
fit), extend the facade — don't route around it with a one-off. The entire
point of Phases 1–2 was to make this the only vocabulary in the app.

## Known, accepted debt — don't "fix" these as if they're accidents

- **Bespoke `BoxDecoration` count went 55→65**, the wrong direction on paper.
  This is a *mechanical* side effect of converting `Ink`/`Material`+`InkWell`
  to `DecoratedBox`+`BoxDecoration` while killing the ripple — not the surface
  sprawl the original audit meant. The real consolidation (fewer bespoke
  one-off surfaces that should just be `AppCard`) is unstarted and is
  explicitly a **Phase 4** job, because it moves pixels and wants goldens
  first. Don't spend Phase 3 time on it.
- Eleven raw spacing values (3, 5, 14, 38) were deliberately left off the
  `Insets` grid in Phase 1 — snapping them moves pixels, same reasoning.
- The dense 13pt (`subhead`) tier reads tight; raising it for generosity is a
  visual call, deferred to Phase 4.

## What's next

### Phase 3 — Safety net ✅ DONE

Keep the gallery and golden baselines updated when shared components change.
CI already runs `flutter test`, so golden diffs fail the normal Flutter job.

### Phase 4 — Screens (in progress)

First slice is done: `dashboard`, `nutrition`, `training_camp`, and `more`
now use `ScreenScaffold.tab`, which keeps the shared premium background/header
without adding nested app chrome inside `HomeShell`. `ScreenScaffold.tab` still
falls back to a local `Scaffold` when a tab screen is rendered standalone in
widget tests, so SnackBars and secondary screen tests keep working.

Remaining headline items: collapsing large-title header everywhere; reduce the
dashboard to one loud element; re-IA the tabs to Home/Train/Fuel/Profile with
the technique library wired in; `go_router` + `CupertinoPage` to restore iOS
swipe-back.

**This phase is blocked on decisions only Mahdi can make** (see below) — don't
guess at the Corner Coach question or the tab rename and build around a guess.

### Phase 5 — Accessibility & polish

Dynamic Type end to end (verify at 200%, no clipping), bold-text/high-contrast
support, branded cold start with Firebase off the boot-blocking path, and the
low-end-device blur profiling flagged above if it wasn't done earlier.

## Open decisions — blocking Phase 4, not yet answered

Ask Mahdi before building around any of these:

1. **`CornerCoachScreen`** — wire it into the new Train tab, or delete it?
   It has had zero inbound navigation for at least two phases now.
2. **Technique library content** — the screen still says "Video playback
   unlocks once real sources are connected." The Phase 4 re-IA gives it a
   tab; it still needs actual content to justify one.
3. **"Camp" → "Train"** rename — acceptable, given "fight camp" is the
   established domain term in this app?

One decision **is** already made and should not be re-litigated: **dark-only,
confirmed 2026-09-16.** This is why Phase 1 skipped `ThemeExtension` — its
whole payoff is switching between themes, and there's nothing to switch to.
Don't add a light palette or `ThemeExtension` machinery without Mahdi
reopening this.

## If something looks wrong

Read the two commit messages (`git show f7d17e7`, `git show 40f0fec`) before
assuming a bug — several things that look like oversights are deliberate and
explained there (e.g., why `PrimaryButton`'s haptic is `commit` not `tap`, why
`ServingStepper`'s buttons pass `haptic: null` instead of the `PressScale`
default). If it's still wrong after reading those, it's a real bug — fix it
and note it in the plan file the same way this session did.
