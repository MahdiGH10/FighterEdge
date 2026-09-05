# FighterEdge — Full Project Context (handoff document)

_Written for another LLM/engineer picking this up cold — including a fresh
model in a brand-new chat with zero memory of this project. Every claim
below was verified against the actual code/config in this repo on the date
of writing (not against older docs, not from memory, not aspirational).
Where something could plausibly have changed since, that's said explicitly.
The previous version of this file was itself stale in several places — it
described Phase 1 (cloud persistence) as "not started" when it had, in
fact, already shipped. Don't trust any doc in this repo, including this
one, over the actual code. Verify before you build on top of a claim._

---

## 0. Read this first — how to work with this specific user

This section exists because getting this wrong wastes both your time and
theirs. It matters as much as the architecture below.

- **The user dictates by voice.** Messages sometimes arrive with
  transcription artifacts ("hand of oil" meant "handoff", "wher edo i put"
  meant "where do I put"). Don't get thrown by typos or garbled phrasing —
  read for intent, not literal text.
- **One sprint/feature at a time, then stop for explicit approval.** This
  discipline is enforced hardest in `docs/EDGEFUEL_AI_CLAUDE_CODE_MASTER_PROMPT.md`
  §22: implement one sprint, report honestly, wait. It generalizes to the
  whole project — don't chain multiple big features together without
  checking in. A generic "continue" refers to whatever was just proposed,
  not blanket permission to keep going indefinitely.
- **The user overrides constraints explicitly when they want to** — e.g.
  "$0 budget" was a hard rule for most of this project's life, until the
  user explicitly chose to upgrade to Firebase's Blaze plan to unlock Cloud
  Functions for the AI gateway. Treat past constraints as defaults, not laws
  — but don't silently break them yourself; ask, the way this was asked.
- **When a real secret gets pasted into chat, treat it as compromised
  immediately** and say so — don't wait to be asked. This happened once
  already (an OpenRouter API key shared during planning). See §7.
- **Verify, don't inherit.** Every "honest handoff doc" in this repo
  (including this one, including `docs/FIGHTEREDGE_MASTER_PLAN.md`) is a
  snapshot. Before telling the user something is broken or missing, grep/read
  the actual file. This doc itself replaces a version that got several
  things wrong by trusting its own prior write-up instead of the code.
- **Ask before skipping the build's own stated order**, but if the user
  explicitly asks to jump ahead (e.g. "I want the AI to work" before
  finishing EF-3/4/5), that's a legitimate reprioritization — flag the
  prerequisites you're skipping, get a scope decision, then proceed.
- **This user cares about honesty over reassurance.** Long, deferential
  softening ("mostly done", "should work") is worse than a flat "this part
  is fake, here's why." Match that register.

---

## 1. What this is

**FighterEdge** — a dark, athletic MMA/fight-camp training app. Flutter
(Dart), targeting web + Android (iOS never built — needs a Mac + Apple
Developer account, neither set up). Private repo, solo builder, one
external tester so far. Built from a static design mockup into a working
prototype with a real Firebase backend, then extended with a full
deterministic nutrition/AI subsystem ("EdgeFuel AI") as a second, much
larger feature arc.

Product loop: log training sessions → track weight → track nutrition via
EdgeFuel → get corner-coach cues → optionally go Pro. No real payments are
wired yet (see §5).

Two very different engineering styles coexist in this codebase because
they were built at different times with different levels of specification:
- The **original app shell** (dashboard, camp, timer, weight tracker,
  technique library, corner coach, profile, settings, auth, billing) — built
  fast, iteratively, screen-by-screen.
- **EdgeFuel AI** (the nutrition subsystem) — built from an extremely
  detailed 1400-line user-authored spec
  (`docs/EDGEFUEL_AI_CLAUDE_CODE_MASTER_PROMPT.md`), sprint-by-sprint, with
  much heavier test coverage, an explicit safety policy, and a real backend.
  It is noticeably more rigorous than the rest of the app. If you're
  wondering why nutrition code looks so much more careful than, say, the
  Technique Library — that's why.

---

## 2. Full architecture map

```
FighterEdge/                          ← git root (NOT fighter_edge/)
  .github/workflows/flutter-ci.yml    ← CI: dart format, flutter analyze, flutter test
                                          (Flutter only — does NOT build/test functions/, see §6)
  fighter_edge/                       ← the actual Flutter project
    lib/
      main.dart                      — boots Firebase, wires every Provider, entry point
      firebase_options.dart          — generated FlutterFire config (safe to be public)

      auth/
        auth_repository.dart         — AuthRepository interface (provider-agnostic)
        local_auth_repository.dart   — on-device fake (SharedPreferences), used in dev/tests
        firebase_auth_repository.dart— production impl (Firebase Auth + Firestore profile doc)

      billing/subscription.dart      — Plan enum, Feature enum, Entitlements gating
      controllers/auth_controller.dart — ChangeNotifier wrapping AuthRepository for the UI

      data/
        data_repository.dart         — interface: weights, meals (LEGACY, see §4), sessions
        firestore_data_repository.dart
        in_memory_data_repository.dart
        mock_data.dart                — seed data for signed-out/dev fallback

      state/app_state.dart           — ChangeNotifier: weights, training sessions, settings.
                                        Still owns a `meals`/`Meal` API that nothing calls
                                        anymore (see §4 — this is dead code, not a bug, but
                                        it's shipped weight nobody's removed).

      models/                        — Fighter, TrainingSession, WeightEntry, Meal, Technique,
                                        CoachCue, AppUser
      screens/                       — one file per screen (dashboard, training_camp,
                                        round_timer, weight_tracker, technique_library,
                                        corner_coach, profile, settings, paywall, onboarding,
                                        more, home_shell) + screens/auth/ for the whole auth flow
      widgets/                       — shared components (ProGate, PrimaryButton, AppCard/
                                        StatCard, ProgressRing, FilterChips, PremiumEffects, …)
      theme/                         — AppColors, AppTheme (Oswald/Inter via google_fonts,
                                        fetched at runtime — see §4)

      features/edge_fuel/            — the EdgeFuel AI subsystem, kept fully separate from
                                        the rest of the app (its own feature-folder module)
        domain/                      — PURE DART, zero Flutter/Firebase/clock/network imports
          models/                    — NutritionProfile, NutritionTarget, NutritionSetupDraft,
                                        NutritionDay, FoodLogEntry, enums
          policies/                  — NutritionPolicy (versioned constants),
                                        NutritionSafetyPolicy (age/BMI/clinical-flag gate)
          calculators/nutrition_target_calculator.dart — THE ONLY place a calorie/macro
                                        target may be computed (deterministic, no AI)
          units.dart                 — lb<->kg, in<->cm conversion boundary
        data/                        — EdgeFuelRepository interface + InMemory/Firestore impls
                                        (profile draft, target, daily food log, legacy-meal
                                        migration)
        ai/                          — EdgeFuelAiGateway interface + Fake/Firebase impls,
                                        response models. The ONLY seam the Flutter app uses
                                        to reach an AI provider — see §5 for the backend half
        presentation/
          controllers/                — EdgeFuelSetupController (wizard), EdgeFuelController
                                        (read-side: draft/target/day), EdgeFuelAiController
                                        (one-shot "explain my plan" request state)
          screens/                    — 6-step setup wizard, Plan screen (+ "Ask EdgeFuel
                                        Coach" AI section)
          nutrition_copy.dart         — human-readable copy for domain enums/reason codes
          widgets/choice_card.dart

    functions/                        — Firebase Cloud Functions (Node 20 + TypeScript).
                                        THE ONLY backend service in this project. Holds the
                                        OpenRouter key server-side; auth/quota/schema/safety
                                        pipeline for the one AI feature that exists.
        src/index.ts                  — the one callable function, edgeFuelAiExplain
        src/{openrouter,quota,validate,systemPrompt,types}.ts
        src/validate.test.ts          — Node's built-in test runner, 10 tests

    test/                             — unit/, widget/, flow/, plus live_features_test.dart
                                        and widget_test.dart at top level (154 tests total)
    integration_test/app_flow_test.dart — same journey as flow/, real integration_test binding
                                          (not run in CI or in most dev environments — web
                                          doesn't support it, Windows-desktop can't build the
                                          Firebase plugins)

    firebase.json / firestore.rules / firestore.indexes.json
    docs/
      PROJECT_CONTEXT.md              — this file
      ROADMAP.md                      — 9-phase plan, WRITTEN BEFORE MUCH OF PHASE 1 SHIPPED
                                          — treat its "not started" markers with suspicion,
                                          verify against code
      FIGHTEREDGE_MASTER_PLAN.md      — a separate, deep product/SaaS/business audit
                                          (1392 lines) written before EdgeFuel existed at all.
                                          Good for product-strategy/business-model thinking,
                                          silent on everything EdgeFuel-related.
      EDGEFUEL_AI_CLAUDE_CODE_MASTER_PROMPT.md — the 1424-line spec EdgeFuel was built from.
                                          Read this before touching EdgeFuel code.
      edge_fuel/
        PRODUCT_SPEC.md, SAFETY_AND_EVIDENCE.md — EdgeFuel decisions + safety-constant sourcing
        HANDOFF.md                     — EdgeFuel-specific mid-build handoff (narrower scope
                                          than this file, has some gotchas worth reading if
                                          you're touching the wizard/controllers)
        AI_PROVIDER_DECISION.md        — OpenRouter selection + the key-leak incident
        AI_DEPLOY.md                  — exact manual steps to deploy the AI backend
      firebase_setup.md                — how the Local/Firebase auth swap works
```

State management: `provider` package, `ChangeNotifier`-based, everywhere.
Navigation: raw `Navigator.push`/`MaterialPageRoute` throughout — no
declarative router. Two parallel Provider trees exist in `main.dart`
(app-wide) that both feed into the same screens; EdgeFuel's own
sub-controllers are scoped per-screen where it made sense (setup wizard,
AI request state) rather than living for the app's whole lifetime.

---

## 3. Feature inventory — what's real vs. mocked vs. stubbed

| Feature | Status | Notes |
|---|---|---|
| Email/password auth | **Real** | Firebase Auth, verified live |
| Google sign-in (web) | **Real** | Popup flow confirmed working |
| Google sign-in (Android native) | **Unverified** | Needs SHA-1/SHA-256 fingerprints registered in Firebase console; never confirmed done. Could be silently broken on the one external tester's device. |
| Apple sign-in | **Correctly hidden** | `supportsApple => false` under Firebase; button doesn't render. Code path exists (`signInWithApple`) but unreachable from UI. Would need a paid Apple Developer account to ever enable. |
| Magic-link/passwordless | **Correctly hidden** under Firebase | `supportsMagicLink => false`; Firebase uses tapped links not codes, never implemented. `LocalAuthRepository` (dev/tests only) has a real 6-digit-code flow. |
| Weight tracking | **Real, persisted** | `Firestore users/{uid}/weights/{id}`, live via `DataRepository` |
| Training sessions/streaks | **Real, persisted** | `users/{uid}/sessions/{id}` |
| Legacy meal tracking (`AppState.meals`) | **Dead code** | Fully implemented, Firestore-backed, zero UI callers left — see §4 |
| EdgeFuel nutrition targets | **Real** | Deterministic Mifflin–St Jeor engine, hand-verified test vectors, extensive safety gating |
| EdgeFuel daily food logging | **Real, persisted** | `users/{uid}/nutritionDays/{date}`, migrates one-time from legacy meals |
| EdgeFuel AI ("Ask EdgeFuel Coach") | **Real backend, NOT DEPLOYED** | Code complete, tested, but needs the user to upgrade Firebase billing + set a secret + deploy — see §5 |
| Round timer | **Real** | Live countdown, work/rest phases, Boxing/MMA/BJJ presets |
| Technique library | **Fake** | Filterable list UI only, no `video_player`, no real video source |
| Corner Coach | **Fake, Pro-gated** | Round-based cue cards from a static list, not personalized, not AI-driven despite the name |
| Settings screen | **Real, but self-admittedly incomplete** | Units/haptics/reminders toggles persist for real (SharedPreferences). Password/legal rows literally pop up a message admitting account deletion and real legal copy aren't done yet — this honesty is in the shipped code, not just docs. |
| Billing/entitlements | **Client-checked, server-safe now** | `Plan.free`/`Plan.pro` gate features client-side, but there is no client write-path to grant Pro anymore — `startProCheckout()` throws `billing-not-configured` until a real payment processor exists. This is an *improvement* over an earlier version of this app where the client could self-upgrade; don't reintroduce that. |
| Onboarding | **Real** | Exists (`onboarding_screen.dart`) — a first-run goal/experience/training-days flow. (An older doc claimed no onboarding existed; that was wrong even at the time it was written, or became wrong shortly after.) |
| Crash reporting | **None** | No Crashlytics/Sentry in `pubspec.yaml`. If the app crashes on a real device, there's currently no way to find out. |
| App icon | **Stock default** | No `flutter_launcher_icons` in `pubspec.yaml`; nothing suggests this changed. |
| CI | **Exists, Flutter-only** | `.github/workflows/flutter-ci.yml` at the **git root** (not inside `fighter_edge/`) — easy to miss if you only look inside the Flutter project. Runs `dart format` check + `flutter analyze` + `flutter test`. Does **not** build or test `functions/` at all — a TypeScript backend now exists with zero CI coverage. |

---

## 4. Concrete engineering mistakes found and their current status

These are things I found by reading the actual code, not by trusting an
older doc — several contradict what earlier documentation claimed.

1. **An entire legacy nutrition subsystem is dead code, still fully wired
   and shipped.** `AppState.toggleMeal`/`addMeal`/`shiftNutritionDate` and
   `DataRepository.watchMeals`/`saveMealsForDate` (with Firestore and
   in-memory implementations, plus `mock_data.dart` seed data) have **zero
   remaining callers** in any screen — verified with a full-repo grep.
   `nutrition_screen.dart` was rewritten to use `EdgeFuelController`'s
   `FoodLogEntry`/`NutritionDay` model instead. The old system exists only
   to seed the one-time legacy-meal migration inside EdgeFuel's own
   repository (`seedLegacyMeals`), which reads Firestore directly rather
   than going through `AppState`. **Nobody removed the old path.** This is
   the single clearest piece of unaddressed technical debt in the repo:
   an entire `users/{uid}/meals/{date}` Firestore collection, a `Meal`
   model, and ~120 lines of `AppState`/`DataRepository` code that do
   nothing for a signed-in user today. Fix: delete `toggleMeal`/`addMeal`/
   `shiftNutritionDate`/the `meals` getters from `AppState`, delete
   `watchMeals`/`saveMealsForDate` from `DataRepository` and both impls,
   update/delete the tests that cover them (`data_repository_test.dart`,
   parts of `app_state_test.dart`), keep the `Meal` model only as long as
   `FoodLogEntry.fromMeal`/`toLegacyMeal` need it for migration.

2. **CI doesn't cover the backend that now exists.** `functions/` (Node/TS,
   its own `npm test` with 10 real tests) has no GitHub Actions job. A
   regression in `validate.ts` (the safety-critical response validator)
   would ship silently. Fix: add a second job to
   `.github/workflows/flutter-ci.yml` (or a new workflow) that does
   `cd fighter_edge/functions && npm ci && npm test`.

3. **`dart format` drift was silently breaking CI's own formatting gate**
   at the time of this audit — 12 files (mostly EdgeFuel AI files added in
   the most recent sprint) hadn't been run through `dart format`. This was
   found and fixed as part of writing this document (a pure whitespace
   commit, zero logic changes, all 154 tests re-verified green
   afterward) — **but as of this writing it has not been committed yet**.
   Lesson for whoever continues this: run `dart format .` before every
   commit, not just `dart fix --apply` (they check different things).

4. **`AppState` is trending toward a god object.** It currently owns
   weights, training sessions, and app-wide settings (units, haptics,
   reminders, safe-cut-guidance toggle) — plus the dead meals API above.
   EdgeFuel correctly did **not** add its state here; it built its own
   parallel controller tree instead. That was the right call and is worth
   preserving as a pattern: don't add new feature state to `AppState`,
   give new features their own controller the way EdgeFuel did.

5. **Doc sprawl.** There are now 10 markdown files under `docs/` (5 at the
   top level, 5 under `docs/edge_fuel/`), several written at different
   points in the project's life with claims that contradicted each other
   by the time this file was rewritten. There is no single mechanism
   keeping them in sync with the code. Treat every doc as a hypothesis to
   verify, not a fact — this file included.

6. **Google Sign-In on native Android remains unverified** (carried over
   from the previous audit — nothing in the commit history since suggests
   this was checked). The one external tester's APK may have a broken
   Google button specifically on Android.

7. **The OpenRouter API key incident.** During EdgeFuel AI planning, a real
   OpenRouter key was pasted into a chat session. This is recorded
   explicitly in `docs/edge_fuel/AI_PROVIDER_DECISION.md` and
   `docs/edge_fuel/AI_DEPLOY.md`, with instructions for the user to rotate
   it before deploying. **As of this writing it is unconfirmed whether the
   user has actually rotated it.** If you're continuing this project and
   the AI feature is being deployed, confirm this was done before assuming
   the backend is safe to turn on — don't assume it's handled just because
   a doc says to do it.

8. **No environment separation.** One Firebase project (`fighter-edge-app`)
   for dev, the one external tester, and (once deployed) the AI backend's
   quota/kill-switch config. No staging project.

---

## 5. EdgeFuel AI — current state in detail

This is the newest and most heavily engineered part of the app. Full spec
in `docs/EDGEFUEL_AI_CLAUDE_CODE_MASTER_PROMPT.md`; only the delta from
that spec is summarized here.

**What's built and tested:** a deterministic nutrition engine (calorie/macro
targets from Mifflin–St Jeor + activity + goal pace, with an explicit
safety policy blocking under-18/underweight-fat-loss/invalid targets and
flagging six clinical conditions for "consult a professional" instead of
silently calculating), a 6-step resumable/autosaved setup wizard, daily
food logging with one-time legacy-meal migration, and a real (code-complete)
AI backend on Firebase Cloud Functions that explains the already-calculated
plan in plain language via OpenRouter.

**Explicit, user-approved scope cuts (not oversights — documented decisions):**
- No App Check on the AI endpoint yet.
- No server-owned Pro entitlement check — every signed-in user shares one
  daily quota (20 requests/day), regardless of plan. This is inconsistent
  with the rest of the app's `Entitlements` model (which is otherwise
  Pro-gated) — the AI feature is currently free for everyone.
- Only two AI task types exist (`explainPlan`, `summarizeTrend` — and only
  `explainPlan` has a UI). Recipe/meal-plan/substitution/grocery-list
  actions are all explicitly disabled (`recipeIds` must always be empty)
  because no recipe catalog exists yet (that's EF-3 in the master prompt,
  not built).
- Response caching, cost dashboards, and prompt-response logging (beyond a
  bare quota counter) don't exist.

**Not yet done, blocking the AI feature from working at all:**
1. Rotate the leaked OpenRouter key (see §4.7).
2. Upgrade Firebase project to the Blaze (pay-as-you-go) plan.
3. `firebase functions:secrets:set OPENROUTER_API_KEY` (must be run by the
   user in their own terminal — never through an AI assistant).
4. `firebase deploy --only functions,firestore:rules`.

Exact commands in `docs/edge_fuel/AI_DEPLOY.md`. Until these four manual
steps happen, the "Ask EdgeFuel Coach" button in the app will always
return the "unavailable" state — this is expected, not a bug.

---

## 6. Design/UX gaps

- Technique Library, Corner Coach, and the nutrition Analytics tab are all
  empty-shell UI with no real content behind them.
- No golden/screenshot tests — zero visual-regression coverage for the
  dark theme across ~20 screens.
- Fonts (Oswald/Inter) are fetched over the network at runtime via
  `google_fonts` with no bundled fallback — cold start with no network
  degrades typography silently.
- No animated transitions beyond what a couple of screens do locally (the
  round timer ring, the meal-check animation); most of the app is static
  `Navigator.push`.
- Stock app icon, no native splash screen.

---

## 7. Security posture, honestly

- Firestore rules are owner-only, deny-by-default (`match /{document=**} {
  allow read, write: if false; }` catches everything not explicitly
  matched) — this part is solid and was reviewed with the `saas-rules`
  skill earlier in the project.
- Entitlements/billing fields are protected by a `billingFieldsUnchanged()`
  rule function — a signed-in user cannot write their own `plan` field.
  This closes the gap an earlier version of this app had.
- The AI backend never exposes the OpenRouter key to the client, validates
  every model response before it reaches the app (schema shape, a
  prohibited-content keyword blocklist for weight-cutting language, and a
  "no fabricated numbers not present in supplied facts" heuristic check),
  and never lets the model touch calorie/macro math.
- **Open item**: the leaked key (§4.7) — confirm rotation before deploying.
- **Open item**: no App Check anywhere in the app (auth, Firestore, or the
  new Functions endpoint) — nothing stops a scripted client from hitting
  these endpoints outside the real app.
- Single Firebase project for everything — a bug in a security rule or a
  misconfigured quota affects the one real user in production, with no
  staging buffer.

---

## 8. Production-readiness checklist, prioritized

**P0 — blocks any wider distribution:**
- Account deletion flow (Play Store requires this for any app with accounts
  — currently just a placeholder message in Settings)
- Real Terms/Privacy/medical-disclaimer copy (currently placeholder)
- Crash reporting (Firebase Crashlytics, free)
- Real app icon + release keystore signing (APK is currently debug-signed)
- Verify Google Sign-In actually works on native Android

**P1 — undermines credibility/safety if skipped:**
- Delete the dead legacy-meal subsystem (§4.1) or explicitly document why
  it's being kept
- Add CI coverage for `functions/` (§4.2)
- App Check on Firestore + the Functions endpoint
- Server-owned Pro entitlement check before the AI feature (or any
  Pro feature) is trusted with real money
- Confirm the OpenRouter key rotation actually happened

**P2 — real but not launch-blocking:**
- Real payments (RevenueCat or equivalent) — currently `startProCheckout()`
  is a deliberate not-implemented stub
- Technique Library real video content
- Golden tests, declarative routing, animation polish
- Recipe catalog (unlocks the disabled EdgeFuel AI action types)
- Consolidate the 10 docs under `docs/` into fewer, clearly-scoped files

---

## 9. If you're picking this up: suggested order

1. Confirm the OpenRouter key rotation (§4.7) — cheap, and blocks trusting
   the AI backend at all.
2. Commit the pending `dart format` fix if it's still uncommitted (check
   `git status` — don't assume; this doc was written the same session that
   fix happened).
3. Decide: delete the dead legacy-meal system, or explicitly keep it
   documented as intentional (§4.1). Don't leave it silently ambiguous.
4. Add CI coverage for `functions/`.
5. Then work through the P0 list in §8 before touching anything cosmetic.
6. Only pick up EdgeFuel sprint EF-3+ (recipes) or further AI task types
   after the P0/P1 list above, unless the user explicitly asks to
   reprioritize again — which they have done before, and is fine, but ask.

---

## 10. Constraints that shaped this project

- **Budget discipline was the default, not absolute.** Everything ran on
  Firebase's free Spark plan for most of the project's life; the user
  explicitly chose to upgrade to Blaze specifically to unlock the AI
  feature, after being told what that would cost/require. Don't assume $0
  is still a hard ceiling, and don't assume it's been abandoned either —
  ask if a new paid dependency comes up.
- **Solo builder, one external tester.** No team workflow, no PR review
  process, everything lands on `main` directly.
- **User is in Tunisia** — Firebase region is `europe-west1` for latency,
  not a US region.
