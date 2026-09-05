# EdgeFuel AI — session handoff

Read this first if you're picking up this work in a new session. It tells you
where things stand, what to read next, and the one rule that matters most:
**do not start the next sprint without the user's explicit approval.**

## What this is

EdgeFuel AI is a deterministic, safety-first nutrition/activity system being
built inside the existing FighterEdge Flutter app, replacing the current
mock-data Nutrition tab. It is being built from a single, user-authored
implementation spec:

- **`docs/EDGEFUEL_AI_CLAUDE_CODE_MASTER_PROMPT.md`** (1424 lines) — the
  master spec. Read this in full before touching any EdgeFuel code. It
  defines naming, architecture, the deterministic math, Firestore paths, the
  sprint plan (EF-0 through EF-7), and — critically — **§22, "Start
  instruction"**: work one sprint at a time, and after each sprint, report
  per §21's 10-point format and **stop and wait for explicit approval**
  before starting the next one. This is a hard rule the user has enforced
  every sprint so far. Do not batch sprints. Do not infer approval from a
  generic "continue" about something else — only proceed on a message that is
  actually approving the next sprint.
- `docs/edge_fuel/PRODUCT_SPEC.md` and `docs/edge_fuel/SAFETY_AND_EVIDENCE.md`
  — written during EF-0, documents the decisions and the (placeholder,
  pending-dietitian-review) safety constants in `NutritionPolicy`.
- `docs/FIGHTEREDGE_MASTER_PLAN.md` — a separate, pre-existing full product
  audit of the whole app (not just EdgeFuel). Useful for broader context
  (auth, entitlements, other screens) but not the spec being executed here.

## Status: EF-0 and EF-1 complete, committed, verified green

| Sprint | Commit | What it delivered |
|---|---|---|
| EF-0 | `1633f5d` | Deterministic nutrition domain: `NutritionProfile`, `NutritionTarget`, `NutritionPolicy`, `NutritionSafetyPolicy`, `NutritionTargetCalculator`. Pure Dart, no Flutter/Firebase/clock deps. 57 unit tests, hand-verified Mifflin–St Jeor test vector. |
| EF-1 | `2ebaf4c` | Six-step resumable/autosaved setup wizard, `EdgeFuelRepository` (in-memory + Firestore), `EdgeFuelSetupController`/`EdgeFuelController`, Plan screen, entry point added to the existing Nutrition tab, Firestore rules for the two new paths, tests. |

Both sprints: `flutter analyze` clean, full test suite green (138/138 as of
EF-1), `flutter build web` succeeds. Full EF-1 sprint report (the §21
10-point writeup) is in the conversation history where EF-1 was delivered —
not duplicated here.

**As of this handoff, EF-1's report has been given and the session is
waiting for the user to approve EF-2 before any EF-2 code is written.** If
you are resuming and the user hasn't said something that clearly approves
moving on, ask before starting EF-2 — don't assume "hand off" or "continue"
means "proceed to the next sprint."

## What's next (only after explicit approval)

Per the master prompt §19, the sprint order is:

- **EF-2 — Daily logging and safe migration**: log meals/activity against
  the EdgeFuel target, migrate the legacy `Meal` / `users/{uid}/meals/{date}`
  data into the new shape without data loss, idempotently.
- EF-3 — Recipe catalog
- EF-4 — Activity and training integration
- EF-5 — Insights and Weekly Fuel Review
- EF-6 — Secure AI and meal planning — **this one requires external
  decisions** (AI provider, billing backend, App Check, privacy consent).
  Per §21's closing instruction: if an external decision is required, stop
  at the interface/fake boundary and state the exact blocker. Never fabricate
  a secret, credential, entitlement, or deployment result.
- EF-7 — Launch hardening

Each sprint has an **exact required commit message** specified in master
prompt §19 — use it verbatim, don't paraphrase.

## Architecture map (as of EF-1)

```
lib/features/edge_fuel/
  domain/                          # pure Dart, zero Flutter/Firebase/clock imports
    models/
      nutrition_enums.dart         # NutritionGoal, EquationProfile, ActivityLevel,
                                    # GoalPace, ConfidenceLabel, NutritionTargetStatus,
                                    # enumFromName<T> helper
      nutrition_profile.dart       # NutritionSafetyFlags + NutritionProfile (strict, immutable)
      nutrition_target.dart        # NutritionTarget (calculator result)
      nutrition_setup_draft.dart   # NutritionSetupDraft (mutable, all-nullable wizard state)
    policies/
      nutrition_policy.dart        # versioned constants (activity coeffs, adjustment %s, etc.)
      nutrition_safety_policy.dart # age/BMI/target-direction/clinical-flag gate
    calculators/
      nutrition_target_calculator.dart  # THE ONLY place a target may be computed
    units.dart                     # lb<->kg, in<->cm conversion boundary

  data/
    edge_fuel_repository.dart              # abstract interface (watch/save draft, watch/save target)
    in_memory_edge_fuel_repository.dart     # fake — used in tests and as offline fallback
    firestore_edge_fuel_repository.dart     # users/{uid}/nutritionProfile/current,
                                             # users/{uid}/nutritionTargets/current

  presentation/
    nutrition_copy.dart            # human-readable labels for enums + reason/warning codes
    controllers/
      edge_fuel_setup_controller.dart  # drives the wizard, autosaves every field
      edge_fuel_controller.dart        # read-side, mirrors AppState.setUser lifecycle
    widgets/
      choice_card.dart             # shared selectable card (title + description + radio)
    screens/
      edge_fuel_setup_screen.dart  # wizard shell: progress bar, nav, step routing
      edge_fuel_plan_screen.dart   # read-only confirmed-plan view
      setup_steps/
        goal_step.dart, body_step.dart, activity_step.dart,
        training_step.dart, food_step.dart, review_step.dart
```

Wired into the app in `lib/main.dart` (Provider/`EdgeFuelRepository` +
`ChangeNotifierProxyProvider<AuthController, EdgeFuelController>`, mirroring
the existing `AppState` pattern exactly) and into
`lib/screens/nutrition_screen.dart` (`_EdgeFuelEntryCard`, additive only).

## Gotchas discovered during EF-1 (save yourself the debugging time)

1. **Never call a `ChangeNotifier` method synchronously from `initState()`
   if it triggers `notifyListeners()`.** Two step widgets (`BodyStep`'s
   weight prefill, `TrainingStep`'s default-days commit) originally called
   `controller.setXxx(...)` directly in `initState()`. This throws
   `setState() or markNeedsBuild() called during build` because the
   `ChangeNotifierProvider` ancestor is still mid-build. Fix: wrap the call
   in `WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) ... })`.
   If you add more auto-committing defaults in new steps, use this pattern
   from the start.
2. **Plain (non-`.builder`) `ListView`s in widget tests don't build
   everything.** Flutter's sliver list only mounts children within the
   viewport + cache extent, even for a fixed `ListView(children: [...])`.
   Adding the `_EdgeFuelEntryCard` pushed later list content (the meal list,
   the wizard's Confirm button) outside the default test window's cache
   extent, so `find.text(...)` found zero widgets even though the app works
   fine on a real scrollable screen. Fix in tests:
   `await tester.scrollUntilVisible(find.text(...), 300, scrollable: find.byType(Scrollable).first);`
   before tapping anything that might be below the fold. See
   `test/live_features_test.dart` and
   `test/widget/edge_fuel/edge_fuel_setup_screen_test.dart` for the pattern.
3. **`AppTextField` didn't have `onChanged`, only `onSubmitted`.** Added a
   nullable `onChanged` param (backwards compatible) because relying on
   `onSubmitted` (IME "done"/"next" action) made autosave-per-keystroke hard
   to trigger reliably, both in real use and in widget tests via
   `tester.enterText`. Body/Food step fields now commit on `onChanged`.
4. **`FighterEdgeApp.edgeFuelRepo` is optional**, defaulting to
   `InMemoryEdgeFuelRepository()` — mirrors how `dataRepo` already worked.
   This keeps `test/widget_test.dart` and `test/flow/app_journey_test.dart`
   (which construct `FighterEdgeApp` directly, not through the app's real
   `main()`) working without needing to know about EdgeFuel at all.
5. **`test/helpers/test_harness.dart`'s `wrapApp()` now always provides an
   `EdgeFuelController`** (defaulting to a fresh `InMemoryEdgeFuelRepository`
   unless you pass `edgeFuelRepo:` explicitly). Any *new* widget test that
   renders `NutritionScreen` — or anything else that ends up needing
   `EdgeFuelController` from context — should go through `wrapApp()`, not a
   hand-rolled `MaterialApp` + single `ChangeNotifierProvider`, or you'll hit
   a `ProviderNotFoundException`.

## How to build/run/test

Flutter is installed at `C:\src\flutter` and is **not** on PATH by default.
From `fighter_edge/`:

```bash
export PATH="/c/src/flutter/bin:$PATH"
flutter analyze
flutter test
flutter build web   # or: flutter run -d chrome
```

## Known limitations carried forward from EF-1

- Food preferences (wizard step 5) are captured but not consumed by anything
  until the recipe system (EF-3).
- No imperial-unit input UI yet — wizard text fields are metric-only, though
  the `units.dart` conversion boundary already exists for when that's added.
- `FirestoreEdgeFuelRepository` has no dedicated repository test (only the
  in-memory fake is unit-tested) — consistent with how
  `FirestoreDataRepository` is already handled elsewhere in this codebase,
  but worth revisiting if Firestore-specific bugs show up.
- The wizard's Review step only recomputes the preview when you land on step
  6 — paging back to an earlier step and forward again re-triggers it, but
  it isn't live while you're on an earlier step.
