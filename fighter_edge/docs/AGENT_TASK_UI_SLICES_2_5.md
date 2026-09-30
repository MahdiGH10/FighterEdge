# Agent task: finish the Fighter Edge polish pass and add a beginner learning path

You are working in the Fighter Edge repository (`MahdiGH10/FighterEdge`): a
Flutter mobile app for combat athletes (MMA, boxing, wrestling, BJJ, Muay Thai),
with Firebase Cloud Functions in `fighter_edge/functions/` (TypeScript, backend
only). The product UI is Flutter only. The users are fighters, from a first-week
beginner to someone in fight camp. The app must feel like a calm, premium,
Apple-grade training instrument, never a generic template-built fitness app.

This is a large task. Do it as **six bounded slices, in order, one commit
each**. Verify every slice before starting the next. If a slice turns out
bigger than expected, stop and report rather than cutting corners.

## 0. Before you touch anything

1. Run `git status --short` and `git branch --show-current`. The working tree
   must be clean apart from untracked audit/reference files (`docs/*_AUDIT_*`,
   `drills.png`, `Fighters_Edge_Product_AI_Technical_Blueprint.md`,
   `google-services.json`, `.playwright-mcp/`). If tracked files are modified,
   **stop and ask**. Never commit those untracked files.
2. Create a branch: `feat/ui-polish-slices-2-5`.
3. Read, in this order:
   - `CLAUDE.md` (repo root): non-negotiable rules.
   - `fighter_edge/docs/CLAUDE_CODE_HANDOFF.md`: the top two sections describe
     the current state (QA fixes and UI slice 1).
   - `fighter_edge/docs/UI_POLISH_AUDIT_20260925.md`: the ranked findings this
     task finishes. Slice 1 is done.
   - `.claude/skills/fighter-edge-ui/SKILL.md`: **the design contract. Every
     UI change must follow it.** Read the token files it names
     (`lib/theme/app_theme.dart`, `app_colors.dart`, `app_typography.dart`,
     `app_accessibility.dart`, `app_haptics.dart`).
   - `lib/widgets/stat_card.dart` (`AppCard`), `primary_button.dart`,
     `app_scaffold.dart`, `empty_state.dart`, `premium_effects.dart`
     (`PremiumReveal`, `AppBackground`).
4. If your environment has design or Flutter skills or plugins (Apple HIG,
   mobile design, motion audit, Flutter layout/testing, Dart analysis), load
   them and use them. Where one emits SwiftUI or web code, **translate its
   intent through this repo's tokens**; never paste its code.

## Rules that apply to every slice

- **No raw values.** No `Color(0x…)`, `Colors.*`, `fontSize:`, `TextStyle(`,
  raw `EdgeInsets`/`SizedBox` numbers, raw `BorderRadius.circular(n)`, raw
  `Duration`/`Curves` at call sites. Use `AppColors`, `AppType.<role>()`,
  `Insets`, `Radii`, `MotionTokens`. If no token fits, add a named, documented
  token to the theme file.
- **Depth comes from surfaces** (`background` < `surface` < `surfaceAlt` <
  `surfaceElevated`), never from glows, gradients or shadows.
- **Colour means something.** Red is for the one primary action per screen, the
  active tab and live state. Gold (`premium`) is for Pro only. `positive`,
  `warning` and `negative` mean what they say. `AppCard(accent:)` is only for
  selection, warning or Pro, never decoration.
- **Accent text uses `AppColors.accentText`**, never `primary` (3.70:1 fails AA).
  White on a red fill uses `AppColors.primaryFill`.
- **One primary action per screen.** Secondary actions are visually quieter.
- **Motion explains a relationship or it goes.** Always honour
  `MediaQuery.disableAnimationsOf(context)`. Nothing bounces that is a real
  quantity (weight, calories, time).
- **Accessibility:** touch targets ≥ 48 (`AppAccessibility.minTouchTarget`);
  every icon-only control has a semantic label; layouts hold at 200% text
  (`AppAccessibility.isLargeText` → stack, never truncate a label); contrast
  ≥ 4.5:1 for body text.
- **Copy:** plain, specific, sentence case for buttons and section labels
  (keep Oswald uppercase only for screen titles and big numbers). No marketing
  lines, no internal enum names in sentences, no " - " string joins. Every new
  user-facing string goes in `lib/l10n/app_en.arb` **and** `app_de.arb`, then
  `flutter gen-l10n`.
- **Architecture:** `lib/features/edge_fuel/domain/` and any new domain code
  stay pure Dart (no Flutter, Firebase, platform or clock imports; inject
  `DateTime Function()` for time). Keep Provider as the state pattern. Do not
  introduce new packages without a reason written in the commit message.
- **Never** log or commit secrets, prompts, measurements, meal text, emails or
  Firebase UIDs. The client never grants Pro. Do not change Firestore rules,
  Cloud Functions or billing in this task.
- **Behaviour:** slices 2–5 are visual and structural. If you must change
  behaviour, say so in the commit message and cover it with a test.

## Verification gate (run after every slice, from `fighter_edge/`)

```
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --exclude-tags golden --reporter compact
flutter test --tags golden --reporter compact
```

- If goldens change, look at the old and new images and accept them only if
  the diff is exactly what you intended (`--update-goldens`).
- Then run the app offline (`flutter run -d chrome -t lib/main_local.dart` or
  `-d web-server`), create a throwaway local account, and look at every screen
  you touched at **390×844 and 320×568**, plus once at a large text scale.
  Check the console for errors. Screenshots or it didn't happen.
- Report failures honestly. Do not skip, weaken or delete a test to get green;
  fix the cause or explain why the test was wrong.

## Slice A: make the date-dependent dashboard tests deterministic

`test/widget/dashboard_test.dart` "shows the fighter, sections and live weight"
and "streak freeze is not shown when nothing is at risk" pass Mon–Thu and fail
Fri–Sun. `AppState()` with no repository seeds Mon–Thu demo sessions, so late in
the week the demo streak is "at risk", a banner appears and pushes Weekly
Overview out of the lazy list.

Fix it at the source: let the dashboard's streak computation receive the same
injectable clock `AppState` already takes (`AppState(clock:)`), and have
`StreakEngine`/`StreakController` use it instead of `DateTime.now()`. Pin the
tests to a fixed Wednesday. Add one test that proves the at-risk banner does
appear on a Saturday with the demo data, so the behaviour is covered rather
than hidden. **Done when** the full suite passes regardless of the machine's
weekday.

## Slice B: dashboard (`lib/screens/dashboard_screen.dart`)

Currently 10 stacked blocks. The next session appears twice (Today's focus and
Next Session) with two red start buttons, the streak appears three times, a
static "Why this target matters" explainer shows every visit, and the weight
stat truncates "Add weigh-in" to "Add weig…".

Target layout, top to bottom:
1. Compact header: name, goal. Drop the meaningless "CAMP MODE" pill.
2. First-week checklist (only while incomplete, as today).
3. **One hero:** today's session (or "rest day" / "week done" / "no plan yet")
   with the screen's only red button. Under it one line of fuel status (kcal
   left, or "Set a fuel target").
4. **One stats row:** weight, sessions, streak. Each appears once in the whole
   screen. No truncation at 320 px or 200% text.
5. This week: the day strip merged with fuel-this-week, one container.
6. Recent activity as plain rows (see "rows, not cards" below).

Move the "why this target matters" explainer behind an info button on the fuel
line. Keep every banner that means something (email verification, streak at
risk), but they must not push the hero off the first screen at 390×844.
Update the widget tests that assert on removed text; do not delete coverage.

## Slice C: Fuel and Train

**Fuel** (`lib/screens/nutrition_screen.dart`): the target appears three times
(target card, ring, "kcal left today" card) and macros twice. Make the ring the
single hero with calories left inside it and the three macro bars under it.
Remove the separate target card and fold "recipes that fit" into one quiet row.
Meals become rows with hairline dividers inside one group, not a card per meal
nested in a card. Replace the date chevrons + tab chips with an Apple-style
segmented control built from existing tokens (keep the day switcher labels
"Previous day" / "Next day").

**Train > Week** (`lib/screens/training_camp_screen.dart`): four red play
circles compete. Only today's session (or the next unfinished one) gets the red
start button; the others get a quiet outline icon. Completed sessions read as
done at a glance without adding colour.

## Slice D: onboarding, welcome, plan ready

Files: `lib/screens/onboarding/` (`welcome_pages.dart`, `onboarding_screen.dart`,
`onboarding_widgets.dart`, `plan_ready_view.dart`).

- Brand logo + tagline only on the first welcome page, not on every step.
- Progress bar at the top; back becomes a header chevron, not a full-width
  BACK button competing with CONTINUE.
- Remove the red uppercase eyebrow above every question; the question is the
  heading.
- One container level: options are rows or chips directly on the screen, not
  cards inside a bordered card.
- Replace the sparkle (`Icons.auto_awesome`) summary tile with a plain one-line
  summary written as a sentence, e.g. "4 days a week · Beginner · Lose fat".
- Welcome hero: remove the glowing ring (its glow is clipped into a visible
  square). Use a calm illustration or a large Oswald numeral/word; no glow.
- Plan ready: "Open dashboard" is the primary action and comes first; the Pro
  upsell sits below it, quieter. Macro tiles in one equal row (or one line of
  numbers). Fix "a starting point for lose fat" (enum inside a sentence).
- The Android integration test `integration_test/app_flow_test.dart` walks this
  flow. Keep its finders working (update them if copy changes) and note in the
  handoff that CI must re-run it.

## Slice E: Settings, login, copy and remaining tokens

- **Settings** (`lib/screens/settings_screen.dart`): one card per row today.
  Use grouped sections with hairline dividers, exactly like Profile
  (`lib/screens/profile_screen.dart`, the reference pattern).
- **Rows, not cards:** extract the grouped-row pattern from Profile into a
  shared widget (for example `lib/widgets/grouped_list.dart`) and use it in
  Profile, Settings, dashboard Recent Activity and Fuel meals. Add it to
  `lib/debug/component_gallery_screen.dart` and regenerate goldens.
- **Icon tiles:** the rounded coloured square + icon + title + subtitle +
  chevron row appears ~29 times. Keep leading icons only where they identify
  something (a discipline, a food group); remove them from settings, stats and
  summary rows.
- **Login:** the Google button uses a plain letter "G". Use the official
  multicolour Google "G" mark as a bundled asset per Google's sign-in branding
  guidelines. Flag (don't fix) that `assets/images/login_background.webp` has a
  tiled "FIGHTER EDGE CAMP" watermark baked in; it needs a new image from the
  owner.
- **Copy pass:** remove marketing lines ("Unlock your full edge", "Watch the
  edge build.", "Food you can actually cook") in favour of plain, specific
  copy. Buttons and section labels in sentence case (this changes the
  uppercase in `_ButtonContent`; update tests and the integration test that
  match uppercase text such as `MONTHLY - $7.99`).
- **Tokens:** clear the remaining raw `EdgeInsets`/`SizedBox` numbers (~50),
  raw `Duration`/`Curves` (4 each) and `Colors.white` uses (add a named token
  such as `AppColors.onPrimary`). `grep` should find none outside `lib/theme/`.

## Slice F: beginner learning path for drills (logic + UI)

The drill library (`lib/training/drills/`: `Drill`, `DrillCatalog`,
`DrillProgress { none, studied, drilled, sharp }`, `DrillProgressStore`) lists
17 drills, but a beginner is not told where to start or what comes next.
Build a guided path so someone with zero experience learns in a sensible order.

**Domain (pure Dart, new file e.g. `lib/training/drills/learning_path.dart`):**
- A `LearningPath` per discipline (striking, wrestling, BJJ, clinch) as an
  ordered list of drill ids, starting from the existing free starter drills
  (The Jab, Stance & Level Change, Shrimp, Plum Clinch & Knees). Order by
  prerequisite (stance before level change before shots, jab before 1-2
  before hooks).
- `nextDrill(path, progress)` returns the first drill not yet `sharp`, and
  never skips a drill whose prerequisite is below `drilled`.
- `pathProgress(path, progress)`: completed / total, and a stage label
  (Foundations / Building / Sharp).
- Respect entitlement: for a free user, a Pro drill appears in the path as
  locked, with the path pausing there (it must not grant access). The client
  never grants Pro.
- Unit tests for ordering, prerequisites, a free user hitting a Pro drill, an
  empty progress map, and a completed path. Aim for 100% line coverage on the
  new file.

**UI:**
- Train > Drills gets a "Start here" hero at the top: the path for the user's
  discipline (derive it from onboarding goal or let them pick once, stored per
  account like existing drill progress), the next drill with one primary action
  ("Learn the jab"), and a thin progress bar. Below it the existing library.
- Drill detail: after "Mark as drilled/sharp", show what's next in the path.
- Beginner-friendly: short sentences, no jargon without a one-line
  explanation, readable at 200% text.
- Widget tests: hero shows the right next drill; marking a drill sharp advances
  it; a free user sees the Pro drill locked and the paywall opens on tap
  without unlocking anything.

## When you finish each slice

1. Run the verification gate and the browser check.
2. Commit with a clear message (what changed, why, what you verified, anything
   not verified), ending with your agent attribution line.
3. Add a short section at the top of `fighter_edge/docs/CLAUDE_CODE_HANDOFF.md`
   (what changed, test count, what is not verified), and mark the slice done in
   `UI_POLISH_AUDIT_20260925.md`.

Do not push or open a PR unless the owner asks. At the end, report per slice:
what changed, test count before/after, goldens changed and why, screenshots
taken, and anything you could not verify (real devices, iOS, release builds,
Firebase).
