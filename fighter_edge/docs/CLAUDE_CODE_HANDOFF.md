# Fighter Edge — Claude Code Handoff

**Verified:** 2026-09-17  
**Repository:** `MahdiGH10/FighterEdge`  
**Branch:** `main`  
**Latest commit:** `9f1b04f ci: use Android-specific Flutter config generation`  
**Purpose:** Give a new Claude Code session enough context to continue the
application without rebuilding work that already exists or claiming that
account-level setup is complete when it is not.

This document is the current engineering handoff. It supersedes the status
sections of older handoffs, especially `CURRENT_HANDOFF.md`,
`PROJECT_CONTEXT.md`, and `START_HERE.md`. Those documents still contain useful
decisions and product reasoning, but some of their implementation counts and
"not started" statements are historical. Always verify against the code and
this document before changing scope.

---

## 1. Product in one paragraph

Fighter Edge is a mobile-first Flutter app for MMA and combat-sport athletes.
The core loop is: create an account → complete a fresh athlete onboarding flow
→ receive a personalized EdgeFuel nutrition target → log training, weight, and
food → see useful daily guidance → optionally upgrade to Pro for deeper coaching
and AI insights.

The product is intentionally dark, focused, athletic, and premium. It should
feel like a calm fight-camp instrument, not a generic fitness dashboard. The
commercial model is a free plan with a genuinely useful daily loop and a Pro
subscription for advanced analytics, libraries, coaching, and the premium AI
Fighter Brief.

The app is written in **Dart/Flutter**. JavaScript/TypeScript only exists in
`fighter_edge/functions/` for Firebase Cloud Functions; it is not the mobile
application UI.

---

## 2. Non-negotiable working rules

1. Work in one bounded engineering slice at a time.
2. Inspect the actual code and `git status` before relying on a document.
3. Keep the app useful for a free user; do not hide the core nutrition loop.
4. Never let the client grant or persist a paid entitlement. RevenueCat plus
   the trusted webhook and Firestore are the source of truth.
5. Keep deterministic nutrition calculations authoritative. AI may explain or
   prioritize the result; it must never invent or override calorie/macro targets.
6. Keep `lib/features/edge_fuel/domain/` pure Dart: no Flutter, Firebase,
   network, clock, or platform imports.
7. Add tests with decision-heavy logic. Run formatting, analyzer, Flutter tests,
   and Functions tests before every commit.
8. Do not log secrets, prompts, measurements, calories, meal text, email
   addresses, Firebase UIDs, receipt tokens, or clinical narratives.
9. Use existing design-system vocabulary instead of introducing one-off styles.
10. Do not remove or commit unrelated scratch files in the working tree.

The standing product rule from `docs/START_HERE.md` remains valid: finish one
step, test it, commit it, then choose the next step.

---

## 3. Verified repository and toolchain state

### Repository

- Root repository: `C:\Users\Mahdi\Downloads\FighterEdge`
- Flutter project: `C:\Users\Mahdi\Downloads\FighterEdge\fighter_edge`
- Remote: `git@github.com:MahdiGH10/FighterEdge.git`
- Current branch: `main`
- Latest known CI run: [GitHub Actions run 35226199432](https://github.com/MahdiGH10/FighterEdge/actions/runs/35226199432)
- Latest known CI result: green for analyze/tests, Windows goldens, Functions,
  and Android release APK build.

### Local toolchain

- Flutter: `3.47.2`
- Dart: `3.13.2`
- Flutter executable on this machine: `C:\src\flutter\bin\flutter.bat`
- Chrome and Edge are available Flutter web targets.
- Android/iOS source folders and release configuration exist, but real device
  and store tests are not complete.

PowerShell command pattern:

```powershell
cd C:\Users\Mahdi\Downloads\FighterEdge\fighter_edge
& 'C:\src\flutter\bin\flutter.bat' pub get
& 'C:\src\flutter\bin\flutter.bat' analyze
```

### Current working tree caveat

At handoff creation, the only untracked paths are unrelated/generated items:

```text
.playwright-mcp/
fighter_edge/docs/SESSION_HANDOFF.md
fighter_edge/test/golden/failures/
```

Preserve them. Do not add, delete, or fold them into a feature commit unless
the user explicitly asks for that cleanup.

---

## 4. What is implemented now

### Application shell and navigation

- `lib/main.dart` boots Firebase, installs production dependencies, and wires
  the Provider tree.
- `go_router` is configured in `lib/routing/app_router.dart`.
- Main authenticated tabs are **Home, Train, Fuel, Profile**.
- `HomeShell` renders only the active tab instead of keeping every tab mounted.
- Named routes include auth pages, paywall, profile, settings, round timer,
  weight tracker, EdgeFuel setup, EdgeFuel plan, and recipes.
- Debug-only component gallery route: `/gallery`.
- `AppNavigation` supports router navigation and a fallback route for isolated
  widget tests.

### Authentication and account lifecycle

- `FirebaseAuthRepository` is the production backend.
- Email/password signup, sign-in, password reset, email verification request,
  Google sign-in on web, sign-out, and account deletion are implemented.
- Apple sign-in and magic-link UI are capability-gated off for the Firebase
  production repository because those flows are not configured.
- `LocalAuthRepository` remains a deterministic fake for tests/dev-only flows.
- Every account enters a fresh onboarding flow; onboarding collects camp goal,
  nutrition goal, age, height, current weight, optional target milestone,
  equation preference, daily activity, experience, and weekly training days.
- Weight class is intentionally removed from onboarding. Users do not need to
  know a competition weight class to start.
- Onboarding seeds a clean camp and optionally an initial weigh-in. It does not
  carry another user's sample state into the new account.
- Account deletion calls the server `deleteAccount` function, which recursively
  removes `users/{uid}` data before deleting the Firebase Auth user.

### Training and weight

- Weight entries persist through `DataRepository` and Firestore under
  `users/{uid}/weights/{entryId}`.
- Training sessions persist under `users/{uid}/sessions/{sessionId}`.
- Training Camp supports weekly sessions, completion, RPE, notes, history, and
  computed current streak days.
- Round Timer has MMA, boxing, and BJJ-style presets with work/rest phases.
- Timer haptics and training settings are persisted locally with
  `SharedPreferences`.
- `AppState` still owns weight, session, and app preference state.

### EdgeFuel nutrition system

EdgeFuel is the most rigorously engineered feature module. It is in
`lib/features/edge_fuel/` and is separated into domain, data, AI, and
presentation layers.

Implemented:

- Six-step setup wizard with branded one-question-per-screen UX.
- Goals: lose fat, maintain, gain muscle.
- Inputs: age, height, current weight, optional target weight/milestone,
  activity level, equation profile, goal pace, food preferences, and safety
  flags.
- Deterministic Mifflin–St Jeor target calculator in
  `domain/calculators/nutrition_target_calculator.dart`.
- Targets include calories, protein, carbohydrates, fats, fiber range,
  maintenance range, RMR, confidence, warnings, policy version, and the
  reference weight used for protein.
- Safety gate in `nutrition_safety_policy.dart` rejects under-age or invalid
  profiles and routes clinical flags to professional review.
- No weight-class concept is used.
- Metric/imperial conversion belongs at the UI boundary (`units.dart`); the
  domain uses kg/cm.
- Firestore persistence for profile draft, calculated target, daily nutrition
  day, food log entries, and one-time legacy meal migration.
- Bundled food catalog (94 foods) and recipe catalog (24 recipes) with serving
  scaling and allergen filtering.
- Daily food logging, consumed totals, date navigation, recent entries, and
  recipe browsing/detail flows.
- Dashboard and Fuel surfaces show the personalized target more clearly,
  including empty states and remaining calories/macros.
- Free Fighter Brief preview is deterministic and offline-safe. It explains
  the next useful action from available target/log context.

### Premium Fighter Brief and AI

The AI boundary is `EdgeFuelAiGateway`. Flutter never calls OpenRouter directly.

Implemented client-side:

- Typed tasks: `explainPlan`, `fighterBrief`, and `summarizeTrend`.
- Typed result states: success, quota reached, entitlement required, and
  unavailable.
- 20-second client timeout and recoverable unavailable state.
- `EdgeFuelAiController` keeps request state local to the screen and emits
  privacy-safe result telemetry.
- `fighterBrief` renders four sections: next action, meal suggestion, training
  timing, and weekly adjustment.

Implemented server-side:

- Callable Function: `edgeFuelAiExplain`.
- Auth check before any work.
- Server-owned `plan == pro` check for premium tasks before quota consumption.
- Atomic daily quota in `users/{uid}/aiUsage/{YYYY-MM-DD}`; current quota is
  20 calls/day.
- Minimum-necessary context only: target, day totals, and food preferences.
- OpenRouter call uses the server secret `OPENROUTER_API_KEY` and model config.
- Strict JSON/schema validation in `functions/src/validate.ts`.
- Version-2 Fighter Brief schema.
- Rejects prohibited weight-cut language, malformed output, fabricated large
  numbers, and unverifiable recipe references.
- Structured lifecycle logging without nutrition content.
- AI kill switch: `config/edgeFuelAi.enabled == false` disables the feature;
  missing config defaults to enabled.

Important known mismatch to resolve:

- The mobile app has a real bundled recipe catalog, but the Functions prompt and
  validator still intentionally require `recipeIds` to be empty because the
  backend does not yet have a server-side recipe catalog. Do not let the model
  invent recipe IDs. Either keep recipe references empty and map suggestions to
  the local catalog safely, or add a versioned server catalog before enabling
  recipe IDs.

### Billing and entitlements

- Plans: `Plan.free` and `Plan.pro`.
- Gate definitions are centralized in `lib/billing/subscription.dart`.
- Pro-gated features currently include Corner Coach, advanced timer presets,
  unlimited weight history, nutrition analytics, full technique library,
  premium EdgeFuel recipes, and the AI coach/Fighter Brief.
- Free limits include five weight-history entries, three technique items, and
  one timer style.
- `BillingGateway` is provider-neutral; tests use fakes and local builds use a
  safe unavailable adapter when store keys are absent.
- `RevenueCatBillingGateway` supports monthly/annual offerings, purchase,
  restore, refresh, logout, and management URL.
- Product IDs:
  - `fighter_edge_pro_monthly`
  - `fighter_edge_pro_annual`
- RevenueCat entitlement identifier: `pro`.
- The client never writes `plan`, `billing`, or `entitlement`.
- Purchase UI stays in pending/server-sync state until Firebase reflects the
  webhook-owned entitlement.
- On web, RevenueCat is unavailable by design; the paywall shows a safe
  waitlist/restore-status state rather than pretending payment succeeded.

### Observability and privacy-safe telemetry

- `lib/observability/telemetry.dart` defines an allow-list of event names and
  product-only parameters.
- Current event families include paywall viewed, checkout started, purchase
  result, restore result, AI request result, brief preview viewed, and premium
  CTA tapped.
- No body measurements, calories, meal text, prompts, emails, or UIDs belong in
  event parameters.
- `error_reporter.dart` supports Crashlytics on Android/iOS/macOS only.
  Web/desktop use a no-op reporter.
- Cloud Functions emit structured logs for AI start/block/failure/rejection/
  completion and RevenueCat webhook lifecycle.
- Review pending: `accountDeletion.ts` still includes UID values in server log
  payloads; reconcile that with the no-identifier observability policy before
  production logging is considered complete.

### Design system and visual direction

The design direction is Apple-informed, not an Apple clone: take the chassis
(typography hierarchy, 8pt spacing, Dynamic Type, 44px targets, restrained
motion, material depth), keep Fighter Edge's crimson/black fight-night identity.

Use these existing tokens/components:

| Need | Existing vocabulary |
|---|---|
| Typography | `AppType` in `lib/theme/app_typography.dart` |
| Spacing | `Insets` in `lib/theme/app_theme.dart` |
| Colors | `AppColors` and theme roles |
| Tappable feedback | `PressScale` |
| Haptics | `AppHaptics` |
| Cards | `AppCard` / `StatCard` |
| Entrance motion | `PremiumReveal` |
| Reduced motion | `AppAccessibility` and `MediaQuery.disableAnimationsOf` |
| Brand | `BrandLogo`, `PremiumBackground`, bundled Oswald and Inter variable fonts |

The shared component gallery and goldens are in
`lib/debug/component_gallery_screen.dart` and `test/golden/`. Keep them green
when changing shared components.

---

## 5. Architecture map

```text
FighterEdge/                         git root
├─ .github/workflows/flutter-ci.yml  CI for Flutter, goldens, Functions, APK
├─ CLAUDE.md                          project rules/gstack note
└─ fighter_edge/                      Flutter project
   ├─ lib/main.dart                   Firebase bootstrap + Provider graph
   ├─ lib/auth/                       AuthRepository + Firebase/local adapters
   ├─ lib/billing/                    BillingGateway + RevenueCat adapter
   ├─ lib/controllers/                AuthController
   ├─ lib/data/                       Legacy weight/session/meal repository
   ├─ lib/state/                      AppState (weights, sessions, settings)
   ├─ lib/models/                     app/user/training/weight/legacy models
   ├─ lib/features/edge_fuel/
   │  ├─ domain/                      pure Dart models/policies/calculators
   │  ├─ data/                        catalog + Firestore/in-memory repositories
   │  ├─ ai/                          gateway, response models, Firebase caller
   │  └─ presentation/                controllers, setup, plan, recipes, widgets
   ├─ lib/screens/                    auth, shell, dashboard, train, fuel, profile
   ├─ lib/widgets/                    shared UI primitives
   ├─ lib/theme/                      tokens, accessibility, motion, haptics
   ├─ lib/observability/               telemetry + error reporter
   ├─ functions/                      Node 20 TypeScript Cloud Functions
   ├─ firestore.rules                  owner-only data + server-owned billing
   ├─ test/                            unit, widget, flow, accessibility, goldens
   └─ integration_test/                device/performance journeys
```

### Firestore shape

```text
users/{uid}
  plan, entitlement, billing       server-owned billing fields
  onboardingComplete, goal, ...    user profile/onboarding fields
  weights/{entryId}
  sessions/{sessionId}
  meals/{YYYY-MM-DD}               legacy path; EdgeFuel is the active path
  nutritionProfile/{docId}
  nutritionTargets/{docId}
  nutritionDays/{YYYY-MM-DD}
  aiUsage/{YYYY-MM-DD}             server-written quota counter

billingEvents/{providerEventId}   webhook idempotency/order ledger
config/edgeFuelAi                  server-only AI kill switch
```

Firestore rules are deployed and enforce owner-only reads/writes. The client
cannot create/update/delete paid billing fields. Admin SDK Functions bypass the
rules for webhook, quota, and deletion work.

---

## 6. What is real, partial, or deliberately not ready

| Surface | Current truth |
|---|---|
| Email/password auth | Real Firebase flow; browser/device account still needed for testing |
| Google sign-in web | Real/implemented; Android SHA fingerprints still need verified console testing |
| Google sign-in Android | Not verified on a physical/internal-test build |
| Apple sign-in | Hidden/disabled until Apple setup exists |
| Magic link | Hidden/unsupported in production Firebase adapter |
| Onboarding | Real fresh-account flow, including EdgeFuel inputs |
| Weight tracking | Real Firestore persistence |
| Training sessions/streak | Real Firestore persistence and local computation |
| Round timer | Real local timer; device haptics need device verification |
| EdgeFuel target | Real deterministic engine and Firestore persistence |
| Daily food logging | Real EdgeFuel path and persistence |
| Food catalog | Real bundled asset catalog |
| Recipe catalog | Real bundled catalog with filtering/scaling |
| Free Fighter Brief preview | Real deterministic, no AI cost |
| Premium Fighter Brief | Code complete and tested, but production function deployment/account setup pending |
| OpenRouter AI | Server code complete; deployment and key rotation/setup must be verified |
| Technique Library | UI exists, but real video playback/content is not shipped |
| Corner Coach | Static/pro-gated cues, not personalized AI coaching yet |
| Mobility | Placeholder/not MVP |
| Profile stats | Some values still come from `MockData`; replace with real aggregates before launch |
| Legacy meal API | Still in `AppState`/`DataRepository`; current Fuel UI uses EdgeFuel. Safe cleanup is pending |
| Settings | Local units/haptics/reminders/safety toggles and account deletion exist; legal pages and password change are placeholders |
| Payments | RevenueCat adapter and server webhook code exist; real store products/sandbox not configured |
| Crash reporting | Mobile Crashlytics adapter exists; real production crash test is pending |
| App icon/native splash | Not fully store-polished/verified |
| iOS | Source-compatible, but TestFlight/device validation is not done |

Do not describe the current state as a shipped SaaS. It is a production-
hardening MVP candidate with account/store deployment work still outstanding.

---

## 7. CI and validation status

### Verified locally at this handoff

```text
dart format --output=none --set-exit-if-changed .  → clean (153 files)
flutter analyze                                      → No issues found
flutter test --exclude-tags golden                  → 271 tests passed
functions: npm test                                 → build + 19 tests passed
```

The latest green GitHub Actions run also passed:

- Analyze and non-golden Flutter tests with coverage.
- Windows renderer golden tests.
- Cloud Functions build/tests.
- Android release APK build and artifact upload.

### Standard local gates

```powershell
cd C:\Users\Mahdi\Downloads\FighterEdge\fighter_edge
& 'C:\src\flutter\bin\dart.bat' format --output=none --set-exit-if-changed .
& 'C:\src\flutter\bin\flutter.bat' analyze
& 'C:\src\flutter\bin\flutter.bat' test --exclude-tags golden --coverage --reporter compact
& 'C:\src\flutter\bin\flutter.bat' test --tags golden --reporter compact

cd functions
npm ci
npm test
npm run build
```

Device/integration checks are separate and cannot be claimed from these unit
tests:

```powershell
& 'C:\src\flutter\bin\flutter.bat' test integration_test/app_flow_test.dart -d windows
& 'C:\src\flutter\bin\flutter.bat' test integration_test/performance_smoke_test.dart -d <device>
& 'C:\src\flutter\bin\flutter.bat' run --profile -d <android-device>
```

### Browser testing

```powershell
cd C:\Users\Mahdi\Downloads\FighterEdge\fighter_edge
& 'C:\src\flutter\bin\flutter.bat' run -d chrome
```

The dev-server port is ephemeral. In the last session it was
`http://localhost:56462/`; use the URL printed/served by the current process,
not a hardcoded port. The browser should eventually show the Firebase
sign-in screen. First boot can take several seconds while Firebase and the
Flutter web bundle initialize. RevenueCat is intentionally unavailable in web
builds.

---

## 8. Account and deployment blockers

These are the items that prevent calling the app a publishable paid MVP.

### Firebase / Functions

- Firebase project: `fighter-edge-app`.
- Firestore rules deployment has succeeded.
- `OPENROUTER_API_KEY` is provisioned, but do not print or copy its value.
- `REVENUECAT_WEBHOOK_AUTH` is missing. Function deployment that includes
  `revenueCatWebhook` is blocked until it exists.

Run interactively in an authenticated Firebase CLI session:

```powershell
firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTH --project fighter-edge-app
firebase deploy --only functions,firestore:rules --project fighter-edge-app
firebase functions:list --project fighter-edge-app
```

The same long random authorization value must be configured as the RevenueCat
webhook Authorization header. Never place it in Markdown, git, chat, or CI
logs.

### RevenueCat / stores

Configure in RevenueCat and the stores:

1. Android and iOS apps in one RevenueCat project.
2. Products `fighter_edge_pro_monthly` and `fighter_edge_pro_annual`.
3. Entitlement `pro`, attached to both products.
4. Current offering with monthly and annual packages.
5. Webhook URL:
   `https://us-central1-fighter-edge-app.cloudfunctions.net/revenueCatWebhook`
6. Webhook Authorization header matching the Firebase secret.
7. Initial purchase, renewal, product change, cancellation, billing issue,
   expiration, refund reversed, test, and transfer events enabled.

Public RevenueCat SDK keys are build-time defines, not secrets for the webhook:

```powershell
flutter build apk --release `
  --dart-define=REVENUECAT_ANDROID_PUBLIC_KEY=<public-key>

flutter build ipa --release `
  --dart-define=REVENUECAT_IOS_PUBLIC_KEY=<public-key>
```

Use CI/release secret variables for these values. Without them, the app is
supposed to render the unavailable/waitlist state.

### Credentials and security

A real OpenRouter key was previously pasted during project planning. Treat it
as compromised even if the current Firebase secret is different: rotate it in
OpenRouter, update Firebase Secret Manager, and never repeat the value.

Do not put Firebase client configuration, store public keys, OpenRouter keys,
webhook auth, or test credentials in source control. Firebase client config is
public-by-design; server keys are not.

---

## 9. Recommended next execution sequence

Do these in order. Each item is a bounded slice with its own tests and commit.

### Slice A — unblock the hosted backend

1. Create `REVENUECAT_WEBHOOK_AUTH` without exposing the value.
2. Deploy Functions and Firestore rules.
3. Verify `edgeFuelAiExplain`, `revenueCatWebhook`, and `deleteAccount` in
   `firebase functions:list`.
4. Create/verify `config/edgeFuelAi` only if a kill switch is desired; missing
   config is enabled by default.
5. Exercise callable AI with a synthetic Firebase user and verify:
   unauthenticated, entitlement-required, quota, unavailable, schema rejection,
   and successful Fighter Brief states.

### Slice B — make the first paid loop real

1. Configure RevenueCat products, entitlement, offering, and webhook.
2. Add platform public keys through local/CI defines.
3. Run Android Play internal-test sandbox purchase and restore.
4. Verify pending server sync, Firestore `plan == pro`, cancellation-before-
   expiry, expiration, billing issue, refund reversal, replay, and stale event
   ordering.
5. Do not enable production price claims until the matrix is green.

### Slice C — privacy-safe conversion and production observability

1. Finalize the allow-listed funnel:
   `brief_preview_viewed → premium_cta_tapped → paywall_viewed →
   trial_started → subscription_started → brief_completed`.
2. Add Firebase Analytics dashboards for conversion events only.
3. Add Crashlytics release monitoring and a controlled test crash on mobile.
4. Add Cloud Logging alerts for repeated OpenRouter failures, rejected model
   output, quota blocks, and webhook failures.
5. Remove UID-bearing fields from logs where the privacy policy disallows them.

### Slice D — remove launch-blocking fake data and debt

1. Replace Profile's `MockData.fighter` and hard-coded goal weight with real
   user/profile aggregates.
2. Decide whether to remove the legacy `Meal` API from `AppState` and
   `DataRepository`; preserve only the migration adapter needed by EdgeFuel.
3. Make settings sync to Firestore if cross-device behavior is promised.
4. Implement real legal pages/URLs, billing terms, medical disclaimer, and
   support contact.
5. Verify email-verification banner, Android Google sign-in fingerprints,
   App Check, and deletion behavior on deployed Functions.

### Slice E — profile and release performance

1. Profile a mid-range Android emulator and one low-end physical device in
   profile mode.
2. Measure first branded frame, first interactive login, frame p95, memory
   after repeated Home/Fuel/Recipes navigation, and APK/AAB size.
3. Optimize only measured rebuild/raster hotspots with `Selector` or narrower
   providers; keep Firestore streams scoped to the current user/date.
4. Build a signed Android AAB/APK and verify install/upgrade on a device.
5. Run Play closed testing before production rollout.
6. Set up iOS signing/TestFlight when Apple Developer access is available.

### Slice F — product depth after the paid MVP

Only after the above is reliable:

- real Technique Library video sources and progress;
- personalized Corner Coach based on recent training/nutrition data;
- weekly nutrition analytics and trends;
- workout logging and richer camp planning;
- mobility routines and local reminders;
- safe educational articles and tutorials;
- richer premium recipe/meal-plan content;
- referral, retention, and subscription win-back experiments.

---

## 10. Performance and release budgets

Use the same device class before and after every optimization. Current target
budgets from `PERFORMANCE_AND_RELEASE_PLAN.md`:

| Metric | Target |
|---|---:|
| First branded frame | under 500 ms on profile device |
| Warm interactive dashboard | under 2.5 s |
| Cold interactive dashboard | under 4 s |
| Steady-state frame build/raster | p95 under 16 ms |
| AI request | 20 s client ceiling, recoverable UI |
| Navigation memory growth | under 10 MB after ten repetitions |

Do not add large blur/gradient effects without profiling. The bottom navigation
already uses carefully bounded premium effects; low-end device cost remains an
open verification task.

---

## 11. Store-readiness checklist

The app is not ready to publish as a paid SaaS until all of these are true:

- [ ] Firebase Functions deployed, including webhook and deletion.
- [ ] OpenRouter key rotated if necessary and stored only in Firebase Secret Manager.
- [ ] RevenueCat products/offering/entitlement configured in both stores.
- [ ] RevenueCat webhook authenticated and idempotency tested.
- [ ] Android purchase/restore/cancel/expire/refund sandbox matrix passed.
- [ ] iOS TestFlight/Sandbox matrix passed when Apple setup exists.
- [ ] Server-authoritative Firestore entitlement confirmed.
- [ ] Privacy policy, Terms, subscription terms, medical disclaimer, support,
      and account-deletion URL are live and linked from Settings/store listing.
- [ ] Data Safety / App Privacy disclosures match actual behavior.
- [ ] Android App Check and OAuth fingerprints configured.
- [ ] Crashlytics mobile test event received.
- [ ] Signed Android release installed and upgrade-tested.
- [ ] Store icon, splash, screenshots, description, pricing, and privacy labels
      reviewed.
- [ ] No P0/P1 crash, cross-user read, client-entitlement-write, or unsafe AI
      output issue remains.

---

## 12. Useful file map for the next Claude session

Start with this document, then open only the file relevant to the slice:

| Need | Read |
|---|---|
| Product/build context | `docs/PROJECT_CONTEXT.md` |
| Active roadmap | `docs/ROADMAP.md` |
| Design tokens/rules | `docs/DESIGN_SYSTEM_PLAN.md`, `docs/DESIGN_SYSTEM_HANDOFF.md` |
| EdgeFuel specification | `docs/EDGEFUEL_AI_CLAUDE_CODE_MASTER_PROMPT.md` |
| AI deployment | `docs/edge_fuel/AI_DEPLOY.md`, `docs/OBSERVABILITY_AND_STORE_SETUP.md` |
| Billing behavior | `docs/BILLING_IMPLEMENTATION.md` |
| Premium brief | `docs/PHASE_7_PREMIUM_FIGHTER_BRIEF.md` |
| Release tests | `docs/RELEASE_QUALITY_AND_TEST_STRATEGY.md` |
| Performance | `docs/PERFORMANCE_AND_RELEASE_PLAN.md` |
| Firebase rules | `firestore.rules`, `firebase.json` |
| Mobile bootstrap | `lib/main.dart` |
| Trusted billing | `functions/src/billing.ts`, `functions/src/index.ts` |
| AI safety | `functions/src/validate.ts`, `functions/src/systemPrompt.ts` |

Before changing code, run:

```powershell
git status --short
git log --oneline -10
rg -n "TODO|FIXME|not configured|placeholder|MockData|hard-coded" lib functions docs
```

Then state the one slice being implemented, write/adjust tests, run the gates,
review the diff, and commit only that slice.

---

## 13. Definition of done for a handoff continuation

A future Claude Code session should report all of the following honestly:

1. What changed and which files changed.
2. Which tests were added and which commands passed.
3. Whether the behavior was tested locally, on a device, in a store sandbox,
   or only reasoned about. These are different claims.
4. Any account-level or external-console blocker that remains.
5. The exact next bounded slice, not an unbounded list of new features.

The goal is a shippable, trustworthy combat-athlete product: useful for a free
user, compelling enough for Pro, safe around nutrition guidance, honest about
what is connected, and measurable in production.
