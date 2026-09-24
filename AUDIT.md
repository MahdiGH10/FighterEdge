# Fighter Edge production-readiness audit

| | |
|---|---|
| **Audited commit** | `4d94728` (`main` @ 2026-09-20 handoff + taxonomy + AI coach) |
| **Re-verified against** | `98d1785` (`main` @ 2026-09-24, 7 commits later). Every finding in a file those commits touched was re-checked, and all line numbers point at `98d1785`. See [Re-verification](#re-verification-against-98d1785). |
| **Audit date** | 2026-09-24 |
| **Scope** | Flutter app (`fighter_edge/`), Firebase Cloud Functions (`fighter_edge/functions/`), Firestore rules, CI, and release configuration. Target: App Store + Google Play, with RevenueCat subscriptions, external payment gateways, and AdMob. |
| **Method** | Ran the toolchain (section 1), read the source, and verified each finding against the code at the cited line. Nothing was refactored. |
| **Not verified** | No physical device or emulator. No iOS toolchain, and the repo has no `ios/` project. No Android SDK in the audit container, so no APK build was run. No Firebase, RevenueCat, App Store Connect, or Play Console access. No live endpoints were called. |

**How to read the tables:** paths are relative to `fighter_edge/` unless
they start with `/` (repository root). Severity:

- **P0**: blocks store submission or approval, exposes credentials or data,
  or breaks a core advertised feature. Must fix before any public build.
- **P1**: serious risk to revenue, privacy, cost, or correctness. Fix before
  launch (or before leaving closed testing).
- **P2**: scale, performance, or maintainability debt that will hurt within
  months of launch.
- **P3**: polish and hygiene.

---

## Executive summary

**The foundation is stronger than most apps at this stage.** `flutter analyze`
is clean and all 546 tests pass with 80% line coverage. The nutrition domain is
pure Dart. Paid entitlement is owned by the server (Firestore rules block
client writes to billing fields). The AI runs behind a Cloud Function that
checks auth, email verification, entitlement, quota, and schema. The design
system is token-based, with no literal font sizes in `lib/`.

**It is not shippable yet.** The blockers are concentrated in five areas:

1. **iOS doesn't exist yet.** There is no `ios/` project and no iOS Firebase
   app, so the app throws at boot on iOS. Google sign-in is offered without
   Sign in with Apple (App Review Guideline 4.8).
2. **Two core flows are broken on real devices.** Google sign-in throws a
   `TypeError` on every Android/iOS attempt. The round timer freezes when the
   screen locks or the app is backgrounded.
3. **Store compliance.** Android release builds are signed with the debug
   key. The privacy policy and terms are placeholders. The paywall has no
   auto-renew disclosure. There is no consent (GDPR/UMP) or ATT flow, which
   matters for the German market and for AdMob.
4. **Credential hygiene.** A live Pro test account's password, tester email
   addresses, and Firebase UIDs are committed to a doc in plain text.
5. **The monetization plumbing is half-built.** Entitlement is read once per
   session and ignores expiry. RevenueCat `TRANSFER` events are dropped. There
   is no AdMob, UMP, or ATT integration. Three of the four Pro features are
   gated only on the client. External gateways have no compliance path or
   unified entitlement source.

| Severity | Open | Resolved on `main` |
|---|---:|---:|
| P0 | 9 | — |
| P1 | 22 | 1 (A-2) |
| P2 | 36 | — |
| P3 | 21 | — |
| **Total** | **88** | **1** |

### Re-verification against `98d1785`

Seven commits landed on `main` while this audit was being written: Google
sign-in config, Reaction drills, launch-blocker fixes, a funnel telemetry
update, a persistent training log, and docs. Each finding in a touched file
was re-checked against the new code:

- **Resolved:** A-2. Commit `502ade0` added an append-only
  `users/{uid}/trainingLog`, derives the week's plan and the streak from it,
  and migrates legacy completions with deterministic IDs.
- **Partly addressed:** T-3. `functions/src/rules.test.ts` now tests the
  rules, but it only covers `trainingLog` and default-deny, it's skipped
  unless an emulator is running, and CI doesn't run it. M-13: nine client
  activation and habit events were added, but server-side subscription
  events and ad revenue are still missing.
- **Still present:**
  - S-2 (the Google sign-in cast). Commit `a20c83c` only refreshed
    `google-services.json`, and the `as OAuthProvider` cast is unchanged.
  - A-1 (`coachVoice` is now wired through, but `reminderGateway` still
    isn't).
  - P-1 (the round timer's clock loop is unchanged).
  - M-1, M-2, M-6, S-1 (the credentials moved to lines 530-537), and every
    other finding.
- **New code reviewed only for these findings:** Reaction drills
  (`lib/training/reaction/`, `lib/screens/reaction_drill_*.dart`). They
  already keep the screen awake and pause when backgrounded, which is the
  pattern P-1 should reuse. The training log's unbounded stream is folded
  into D-3 and P-4.

---

## 1. Tooling results

Flutter was not installed in the audit container. I installed stable
**Flutter 3.47.2 / Dart 3.13.2**, the version CI pins
(`/.github/workflows/flutter-ci.yml:21`). The newest stable today is 3.47.5.

| Command (from `fighter_edge/`) | Result |
|---|---|
| `flutter pub get` | ✅ Resolved. 19 packages have newer versions that the current constraints don't allow. |
| `dart format --output=none --set-exit-if-changed .` | ✅ 244 files, 0 changed |
| `flutter analyze` | ✅ **No issues found** (17.2 s). The baseline is only `flutter_lints` 4, with no strict modes (see A-10). |
| `flutter test --exclude-tags golden --coverage` | ✅ **546 passed, 0 failed** (1 m 59 s). Line coverage **80.3%** (9,621 / 11,987 lines in 160 files). At the originally audited commit it was 466 passed and 79.0%. |
| `flutter test --tags golden` | ⚠️ **3 / 3 failed on Linux**, with pixel diffs of 8.47%, 4.54%, and 8.47% against the baselines refreshed on `main`. The baselines were rendered on Windows, and CI runs goldens on `windows-latest`. This is a platform mismatch rather than a regression, but it means developers on macOS or Linux can't verify goldens (T-7). |
| `dart pub outdated` | Direct dependencies: `fl_chart` 0.68.0 → **1.2.0 (major)**, `go_router` 17.5.0 → **18.0.1 (major)**, `purchases_flutter` 10.12.0 → 10.13.2 (the lockfile holds it back). Dev: `flutter_lints` 4.0.0 → 6.0.0. 10 upgradable packages are held back by the lockfile. |
| `functions`: `npm ci && npm test` | ✅ TypeScript build + **37 / 37 tests pass**. The new `firestore.rules` suite is skipped without an emulator. |
| `functions`: `npm audit --omit=dev` | ⚠️ **12 moderate** (`qs` via express/body-parser; `uuid` via `google-gax` → `@google-cloud/firestore` → `firebase-admin` ≤14.3) |
| `functions`: `npm outdated` | `firebase-admin` 13.10 → 14.5, `firebase-functions` 6.6 → 7.4, `typescript` 5.9 → 7.0 |
| Not run | `integration_test/` (needs a device), Android release build (no SDK in the container), iOS (no project) |

**Coverage gaps that matter.** Every production adapter to an external
system has **0%** coverage:

| File | Covered lines |
|---|---|
| `lib/auth/firebase_auth_repository.dart` | 0 / 142 |
| `lib/features/edge_fuel/data/firestore_edge_fuel_repository.dart` | 0 / 91 |
| `lib/billing/revenuecat_billing_gateway.dart` | 0 / 58 |
| `lib/data/firestore_data_repository.dart` | 0 / 61 |
| `lib/notifications/local_reminder_gateway.dart` | 0 / 41 |
| `lib/features/edge_fuel/ai/firebase_edge_fuel_ai_gateway.dart` | 0 / 28 |
| `lib/observability/*` | 66 / 120 (55%) |
| `lib/main.dart` | 63 / 134 (47%) |

The domain layer (83%), widgets (93%), and most screens (75–96%) are well
covered.

---

## 2. Codebase map

### Folder structure

```text
/                               repo root: README, CLAUDE.md, CONTRIBUTING, CI
├─ .github/workflows/flutter-ci.yml   analyze+test, Windows goldens, Android APK, functions
└─ fighter_edge/                      Flutter app (android/, web/, windows/ — NO ios/)
   ├─ lib/                            160 Dart files, ~30k LOC incl. generated l10n
   │  ├─ main.dart                    Firebase bootstrap + composition root + Provider graph
   │  ├─ main_local.dart              local/in-memory entry point
   │  ├─ auth/                        AuthRepository, Firebase + Local adapters, password/verification policy
   │  ├─ billing/                     BillingGateway, RevenueCat/Fake/Unavailable, Plan/Feature/Entitlements
   │  ├─ controllers/                 AuthController (auth + billing + entitlement facade)
   │  ├─ data/                        legacy DataRepository (weights, sessions, meals) + MockData
   │  ├─ state/                       AppState (legacy god-object), Streak*, FirstRun, Locale controllers
   │  ├─ models/                      AppUser, TrainingSession, WeightEntry, Meal, DevMessage…
   │  ├─ features/edge_fuel/          the only true feature module
   │  │  ├─ domain/                   pure Dart: models, calculators, policies, validation
   │  │  ├─ data/                     Firestore + in-memory repos, bundled JSON catalogs
   │  │  ├─ ai/                       EdgeFuelAiGateway, Firebase callable client, fake
   │  │  └─ presentation/             controllers, setup wizard, plan, coach chat, recipes
   │  ├─ screens/                     auth, onboarding, first_run, dashboard, nutrition, train, timer, paywall, settings…
   │  ├─ training/                    drills catalog, technique taxonomy, corner cues
   │  ├─ notifications/               ReminderGateway + local-notifications adapter
   │  ├─ observability/               Telemetry (Firebase Analytics allow-list) + ErrorReporter (Crashlytics)
   │  ├─ routing/                     go_router config, auth redirect, transitions
   │  ├─ theme/                       AppColors, AppType, Insets, MotionTokens, AppHaptics, AppAccessibility
   │  ├─ widgets/                     shared primitives (buttons, cards, rings, skeletons, nav)
   │  └─ l10n/                        ARB (en, de) + generated `L`
   ├─ functions/src/                  index.ts (AI callable + RevenueCat webhook), billing.ts, quota.ts,
   │                                  accountDeletion.ts, openrouter.ts, validate.ts, systemPrompt.ts (+4 test files)
   ├─ firestore.rules / firestore.indexes.json / firebase.json
   ├─ test/                           unit, widget, flow, accessibility, golden (66 files)
   └─ integration_test/               app_flow, performance_smoke (not in CI)
```

### Architecture at a glance

| Concern | What exists |
|---|---|
| **State management** | `provider` 6 with `ChangeNotifier`. The root notifiers are `AuthController`, `AppState` (weights, sessions, legacy meals, settings), `EdgeFuelController`, `FirstRunController`, `StreakController`, and `LocaleController`. `ChangeNotifierProxyProvider<AuthController, …>` passes the uid into each one's `setUser`. Each screen also has its own controllers (coach, fuel match, recipes, setup). **49 `context.watch`, 0 `select`/`Selector`/`Consumer`.** |
| **Navigation** | `go_router` 17 with 16 flat top-level routes (`lib/routing/app_router.dart`). `authRedirect` guards deep links, and a `resetStackOnSessionChange` listener handles sign-in/out. The 4 tabs live inside `HomeShell` as a `switch (_index)` rather than router branches. Arguments travel in `state.extra`. |
| **DI** | A manual composition root (`lib/main.dart:99-130`) passes constructor parameters into `Provider.value`. The interfaces are `AuthRepository`, `DataRepository`, `EdgeFuelRepository`, `Food/RecipeCatalogRepository`, `EdgeFuelAiGateway`, `BillingGateway`, `ReminderGateway`, `Telemetry`, and `ErrorReporter`. There is no service locator or codegen. Fakes are used in tests. |
| **Data layer** | Two generations: the legacy `lib/data` (weights, sessions, meals) behind `AppState`, and `features/edge_fuel/data` (profile, target, and per-day documents, plus bundled JSON catalogs). `fromJson`/`toJson` is hand-written. Firestore offline persistence is on. SharedPreferences holds settings, locale, streak freezes, first-run flags, food memory, and drill progress. |
| **Firebase usage** | Uses Auth (email/password and Google; Apple disabled), Firestore, Functions (`edgeFuelAiExplain`, `deleteAccount`, `revenueCatWebhook`), Analytics (7 allow-listed events), and Crashlytics (mobile). **Not used:** App Check, Remote Config, FCM, Storage, and Performance Monitoring. There is **one project (`fighter-edge-app`) for every environment.** |
| **Backend** | Functions v2 on Node 20. Secrets are set via `defineSecret` (`OPENROUTER_API_KEY`, `REVENUECAT_WEBHOOK_AUTH`). The AI goes through OpenRouter's free-model chain (`functions/.env.fighter-edge-app`). |
| **Tests** | 45 unit files and 19 widget files, plus flow, accessibility, and golden tests. Functions tests cover pure helpers only (validate, billing mapping, quota, model chain). |

### Firestore schema (as used by the code)

```text
users/{uid}                     profile + server-owned plan/entitlement/billing{…}, devMessage
  weights/{stableId}            WeightEntry — whole collection streamed
  sessions/{day-title}          ≤6 weekly template docs (see A-2)
  meals/{YYYY-MM-DD}            legacy; read on every empty EdgeFuel day for migration
  nutritionProfile/current      setup draft
  nutritionTargets/current      deterministic target
  nutritionDays/{YYYY-MM-DD}    whole day incl. entries[] array, rewritten per edit (see D-1)
  aiUsage/{YYYY-MM-DD UTC}      server-written quota counter
billingEvents/{rcEventId}      webhook idempotency ledger (holds userId)
config/edgeFuelAi               server-only kill switch
```

---

## 3. Findings

### 3.1 Architecture & scalability

| ID | Sev | file:line | Problem | Fix |
|---|---|---|---|---|
| A-1 | **P1** | `lib/main.dart:81-90` (built at `:129`) | The production bootstrap builds `LocalReminderGateway` but **never passes `reminderGateway` to `FighterEdgeApp`**, so the provider falls back to `UnavailableReminderGateway` (`:205-207`). On real devices, the Settings "Camp reminders" switch is permanently disabled and the first-win "Remind me" does nothing. Tests inject a fake, so they can't see this. | Pass `reminderGateway: dependencies.reminderGateway`. Add a bootstrap test that asserts every `_AppDependencies` field reaches the provider tree. |
| A-2 | ~~P1~~ ✅ | `lib/models/training_log_entry.dart`; `lib/state/app_state.dart:238-330`; `lib/data/firestore_data_repository.dart:83-104` | **Resolved on `main` in `502ade0`.** Originally, training "sessions" were a mutable weekly template of at most 6 docs keyed `'$day-$title'`, with no history, so streaks couldn't exceed the number of template docs and past training was lost. `main` now keeps an append-only `trainingLog`, derives the week's plan and streak from it, and migrates legacy completions with deterministic IDs. | No action. Its unbounded stream is tracked in D-3 and P-4. |
| A-3 | **P1** | `lib/state/app_state.dart:17-25`, `:67-75`, `:76-96` | Production `AppState` loads `MockData` (fake weights, sessions, and meals) whenever the uid is null, and **keeps it after sign-in until the first Firestore snapshot arrives**. A slow or offline first launch shows fake data as if it were the user's. | Start empty with an explicit `loading` state. Confine `MockData` to tests and `main_local.dart`. |
| A-4 | **P1** | `lib/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart:112-126`, `:255-261`; `widgets/add_food_sheet.dart:88-96`; `screens/recipe_detail_screen.dart:153-156`; `lib/screens/nutrition_screen.dart:285-288` | UI flows `await` the Firestore `set()`, which only completes when the server acknowledges the write. **Offline, the Add Food sheet never closes** and recipe detail stays in its `_adding` state until the connection returns. A user who taps again logs duplicate entries. Gyms with poor signal are a normal use context. | Update local state optimistically (this already happens), and don't await server acknowledgement in UI flows. Attach `catchError` for reporting. Show a small "syncing" state instead. |
| A-5 | **P2** | `lib/state/app_state.dart:76-96`, `:132`, `:311`, `:436-460`; `edge_fuel_controller.dart:89-98` | Streams are `listen`ed without `onError`, and writes are fire-and-forget (`unawaited`). A `permission-denied` or `unavailable` error becomes an uncaught async error, which is reported as a fatal crash (S-8), and the UI never learns that a save failed. Outside auth and billing there is no typed error model. | Add a `Failure`/`Result` type and an `onError` on every subscription. Surface a non-blocking sync-error state. Report errors as non-fatal. |
| A-6 | **P2** | `lib/state/app_state.dart` (whole file); `lib/data/*` | Two architectures coexist. Only EdgeFuel is a `domain/data/presentation` feature module. Training, weight, account, billing, and settings are organized by layer (`screens/`, `state/`, `models/`). `AppState` is a god-object: any change notifies every watcher. It still exposes `MacroTarget get target => MockData.macroTarget` (`:184`) and the legacy Meal API. | Carve out `features/training`, `features/weight`, `features/account`, and `features/billing` in the EdgeFuel layout. Split `AppState` into Weight, Training, and Settings controllers. Delete the legacy Meal API after the migration (D-4). |
| A-7 | **P2** | `lib/routing/app_router.dart:109-252`, `:163-165`, `:231`; `lib/screens/home_shell.dart:135-148` | The tabs aren't routes. There are no deep links to Fuel or Train, each tab's scroll and filter state is destroyed on every switch, and Android back doesn't follow tab history. `state.extra` (`PaywallRouteArgs`, `RecipeFilters`) is lost on deep links and process death. | Use `StatefulShellRoute.indexedStack`. Encode filters and the highlighted feature as query parameters. |
| A-8 | **P3** | `lib/main.dart:189-191`; `lib/controllers/auth_controller.dart:6`, `:350-355` | The composition root quietly falls back to `InMemoryEdgeFuelRepository` and `FakeEdgeFuelAiGateway`, and `AuthController` imports `LocalAuthRepository` for `devMagicHint`. Fake and dev backends ship in the release binary, and a missing injection fails silently instead of loudly. | Make production dependencies required. Keep fakes in `main_local.dart` and tests. Assert in release builds. |
| A-9 | **P3** | `lib/models/training_session.dart:1`, `:8`; `lib/billing/subscription.dart:1-19` | Persistence and domain models import Material (`IconData`, `Color`). | Store semantic enums (`SessionType`, `Plan`) and map them to icons and colors in the presentation layer. |
| A-10 | **P3** | `analysis_options.yaml:9-30` | Only the `flutter_lints` 4 baseline applies. There are no `strict-casts`, `strict-inference`, or `strict-raw-types` settings, and no `unawaited_futures`, `prefer_const_constructors`, `avoid_dynamic_calls`, or `cancel_subscriptions` lints. | Move to `flutter_lints` 6, enable the strict modes and those lints, and apply `dart fix` incrementally. |

### 3.2 Performance

| ID | Sev | file:line | Problem | Fix |
|---|---|---|---|---|
| P-1 | **P0** | `lib/screens/round_timer_screen.dart:78-90`, `:94-135` | **The round timer isn't accurate when backgrounded or locked.** It's a `Timer.periodic(1 s)` decrementing a counter, with no wall-clock anchor, no `WidgetsBindingObserver`, no wakelock, and no scheduled bell. When iOS auto-locks (default 30 s–1 min) or Android throttles a background app, the isolate is suspended. The clock freezes, then resumes from a stale value, so a 5:00 round can run for many minutes. Tick jitter also adds drift in the foreground. Phases are signalled only by haptics, with no audio, so a phone on the gym floor gives no cue. This is the core training tool. | Extract a pure `RoundTimerEngine` driven by a start instant plus pause intervals on a monotonic clock, and compute phase and remaining time from elapsed time. Ticks only repaint. Recompute on `AppLifecycleState.resumed`. Keep the screen awake while running (`wakelock_plus`). On backgrounding, pre-schedule a local notification with sound for each phase boundary (iOS time-sensitive; Android exact alarm or a foreground service for long sessions). Add an audio bell with an audio session that mixes with music. `lib/screens/reaction_drill_screen.dart:46-97` already does the wakelock and lifecycle handling, so reuse that pattern. |
| P-2 | **P2** | `lib/screens/round_timer_screen.dart:94-99` | Off-by-one: the clock sits on `00:00` for a full tick before switching phase, so each phase lasts N+1 seconds. A 5×5:00 MMA session with 4 rests runs about 9 s long. | The engine from P-1 switches phase in the same tick that reaches 0. Add boundary unit tests. |
| P-3 | **P2** | `lib/screens/round_timer_screen.dart:94-135`, `:172-291`, `:201-203` | `setState` runs every second and rebuilds the whole screen (chips, ring, cue card, buttons). In the last 10 s, the `TweenAnimationBuilder` is re-keyed every second. | Drive only the clock and ring through `ValueListenableBuilder`. Put the ring in a `RepaintBoundary`, and animate its progress continuously instead of in 1 Hz steps. |
| P-4 | **P2** | `lib/screens/weight_tracker_screen.dart:255-261`; `lib/state/app_state.dart:99-116`, `:238-252`, `:319-330` | ~~`weights`, `weightHistoryDesc`, and `_sortedByDate` copy and sort the full list on every getter call... The rows are built eagerly inside `ListView(children:)`.~~ **Fixed (Phase 1) for the sort and the training log.** See Phase 3 progress below. Still open: the weight history stays an eager list, and the chart still plots every point uncapped. | — |
| P-5 | **P2** | `lib/screens/dashboard_screen.dart:53-57`, `:61-74`, `:284-289` | The dashboard `watch`es 5 notifiers and recomputes streak math in `build`. Across the app there are 49 `context.watch` and zero `select` calls, so any notification (a weight snapshot, a locale load, a billing sync) rebuilds entire screens. The largest `build` trees are in `dashboard_screen.dart` (958 LOC), `nutrition_screen.dart` (1,252), `edge_fuel_coach_screen.dart` (1,285), and `drill_library_screen.dart` (1,027). | Use `context.select` for the fields each widget actually reads. Memoize derived values in the controllers. Split large screens into `const` leaf widgets. |
| P-6 | **P2** | `lib/auth/firebase_auth_repository.dart:43-48`, `:65-70`; `lib/main.dart:120-121` | Startup: the first real frame waits for `authStateChanges().first` **and** a Firestore `users/{uid}` `get()`, which on a flaky network tries the server before falling back to cache. Then `authStateChanges().asyncMap(_hydrate)` re-emits the same user, which causes a second read, a full rebuild, and a second billing sync. | Hydrate from cache (`GetOptions(source: Source.cache)`) and refresh in the background. Skip the duplicate initial emission. Measure with `--trace-startup` against the budgets in `docs/PERFORMANCE_AND_RELEASE_PLAN.md`. |
| P-7 | **P3** | `assets/images/login_background.webp` (124 KB, was a 1.8 MB PNG); `lib/screens/auth/login_screen.dart:71-78` | ~~The largest asset is an uncompressed landscape PNG, decoded at full size behind a portrait cover crop.~~ **Fixed (Phase 1).** Converted to WebP (quality 80, 93% smaller) and decoded with `cacheWidth` at the device's physical width. Not yet `precacheImage`d during the splash. | — |
| P-8 | **P3** | `lib/widgets/bottom_nav.dart:56-61` | A full-width `BackdropFilter` (σ = 24) sits under the nav bar on every tab. Low-end GPU cost is still unprofiled (the handoff notes this). | Profile on a low-end Android device. Fall back to solid `surfaceGlass` on low-end devices or when reduced motion is on. |
| P-9 | **P3** | `lib/screens/auth/verify_email_screen.dart:44`, `:53` | The verify screen polls every 3 s (`user.reload()` plus a Firestore `get()`, so about 20 reads a minute) and keeps going when backgrounded. | Poll on resume with backoff (3 → 10 → 30 s), and pause in the background. |
| P-10 | **P3** | project-wide | `prefer_const_constructors` is no longer in `flutter_lints` ≥ 3, so nothing catches a missing `const` (many `Icon`, `SizedBox`, and `Text` literals in the large screens are non-const). | Enable the const lints and run `dart fix --apply`. |

Image caching isn't an issue today because there are no network images.
List virtualization is already correct in the recipe library, add-food
search, coach chat, and drill library (`ListView.builder`/`separated`).

### 3.3 Data & backend

| ID | Sev | file:line | Problem | Fix |
|---|---|---|---|---|
| D-1 | **P1** | `lib/features/edge_fuel/data/firestore_edge_fuel_repository.dart:117-129` | **Sync conflicts lose data.** Every add, edit, or toggle rewrites the whole `nutritionDays/{date}` document, including the `entries[]` array, with last-write-wins semantics. Two devices, or one device that was offline and reconnects, silently drop each other's entries. Only the 1 MiB document limit bounds growth. | Store entries as `nutritionDays/{date}/entries/{entryId}`, one write per entry with soft deletes. Keep day totals in the parent document through a transaction or a Cloud Function trigger. |
| D-2 | **P1** | `/fighter_edge/functions/package.json:7` | Functions run on **Node 20**. Per the handoff, Cloud Functions decommissions Node 20 on **2026-10-30** (about 5 weeks away), after which deploys fail. `npm audit` reports 12 moderate advisories, and `firebase-functions` 7.x and `firebase-admin` 14.x are available. | Move to Node 22, upgrade `firebase-functions` and `firebase-admin`, run `npm test` and an emulator smoke test, and redeploy before the deadline. |
| D-3 | **P2** | `lib/data/firestore_data_repository.dart:22-30`, `:66-73`, `:83-94` | `watchWeights` and `watchTrainingLog` stream **unbounded** collections; every cold start re-reads every entry ever logged. (`watchSessions` is the weekly plan template, 2-6 documents — not actually unbounded.) **Deliberately not fixed yet** — see Phase 3 progress below for why a naive `.limit()` is unsafe here. | — |
| D-4 | **P2** | `edge_fuel_controller.dart:161-179`; `firestore_edge_fuel_repository.dart:96-114`, `:131-139` | "Fuel this week" opens up to 7 sequential snapshot listeners (`.first`), and each empty day triggers a legacy `meals/{date}` `get()` for migration. That's up to **14 serial reads every time the dashboard card mounts**. | Use one range query on document ID from Monday's key onward, and cache per week. Finish the legacy-meal migration with a one-off backfill, then delete the read path. |
| D-5 | **P2** | `/fighter_edge/firestore.rules:16-44`, `:13` | Subcollections are `allow read, write: if isOwner(uid)` with **no schema, type, or size validation** and no field allow-list. A client can write malformed or oversized documents that later crash `fromJson`. On `users/{uid}` the owner can update any non-billing field, including `devMessage` and `createdAt`. | Add per-collection validators (`keys().hasOnly`, types, numeric ranges, request size). Make `devMessage` and `createdAt` server-only. Test the rules in CI (T-3). |
| D-6 | **P2** | `lib/models/training_session.dart:52`, `:65`; `lib/models/app_user.dart:93`, `:97`; `lib/models/weight_entry.dart` | Timestamps are stored as local-time ISO strings with no offset. They're ambiguous across time zones and DST changes, and they can't be ordered correctly on the server. | Store Firestore `Timestamp` or UTC milliseconds plus the user's IANA zone, and derive date keys explicitly. |
| D-7 | **P2** | `lib/state/streak_controller.dart:23`, `:45-62`; `lib/features/edge_fuel/presentation/controllers/food_memory.dart` | Streak freezes and protected days (a Pro perk) and food memory exist only in device SharedPreferences. They're lost on reinstall or a new phone, never synced, and user-editable. None of it is cleared on sign-out or account deletion. | Persist to `users/{uid}/state/*`, validating freeze grants on the server if they carry Pro value, and clear the per-user keys on deletion. |
| D-8 | **P2** | `/fighter_edge/functions/src/quota.ts:8`, `:16` | A single `DAILY_QUOTA = 20` is shared by the free `summarizeTrend` task and Pro chat/brief, keyed by **UTC** day, so it resets mid-afternoon in the Americas. There are no per-tier limits and no token or cost accounting. | Add per-task and per-tier quotas, reset on the user's local day, and record OpenRouter `usage` for cost dashboards and alerts. |
| D-9 | **P2** | `/fighter_edge/functions/src/accountDeletion.ts:25-58` | Deletion removes `users/{uid}` and the Auth user only. `billingEvents` rows containing the `userId` remain, the RevenueCat subscriber isn't deleted, and nothing warns that an active store subscription keeps billing. | Delete or anonymize `billingEvents` by `userId`, call RevenueCat `DELETE /subscribers/{id}`, and show "cancel in the App Store/Play" before confirming. |
| D-10 | **P3** | `lib/state/app_state.dart:154-178`, `:480-493` | Settings (units, haptics, safe-cut guidance, reminders) are device-local SharedPreferences **not keyed by user**. A second account on the same device inherits them, and they don't sync across devices. | Key them by uid, or move them to `users/{uid}/settings`. |
| D-11 | **P3** | `/fighter_edge/firestore.indexes.json`; `/fighter_edge/firebase.json` | There are no composite indexes (fine for today's queries, but D-3 and D-4 will need some), no emulator configuration, and rules and functions are deployed by hand from a developer machine. | Add an `emulators` block and deploy rules, indexes, and functions from CI on tags (R-5). |

### 3.4 Monetization readiness

**Where entitlement lives today.**

- **Client.** `Entitlements.allows(plan, feature)`
  (`lib/billing/subscription.dart:76-89`) is reached through
  `AuthController.allows` and `isPro`. It is checked separately in about 10
  screens: coach, plan, recipe library, drill library, round timer, profile,
  settings, paywall, home shell, and streak.
- **Server.** Only `edgeFuelAiExplain` checks `plan`
  (`functions/src/index.ts:115-120`).
- **RevenueCat integration points.** In `RevenueCatBillingGateway`:
  `configure`/`logIn` with the Firebase uid, the current offering's monthly
  and annual packages, `purchase`, `restorePurchases`, and `logOut`. Then
  `AuthController._syncBilling` runs on every auth change, and the paywall
  consumes the result. The webhook writes `users/{uid}.plan`.
- **Ads, UMP, ATT, and external gateways:** none exist.

| ID | Sev | file:line | Problem | Fix |
|---|---|---|---|---|
| M-1 | **P0** | `lib/screens/paywall_screen.dart:187-206`, `:526-537` | The purchase tiles show only price and period. **There is no auto-renew disclosure** (length, price per period, renewal unless cancelled at least 24 h before the period ends, charge to the Apple ID or Google account), **and no working Terms of Use (EULA) or Privacy Policy links next to the buy button.** This triggers App Review Guideline 3.1.2 rejection and violates Play's subscription policy. | Add a localized disclosure block and links to the hosted Terms and Privacy pages. Show intro and trial terms from `storeProduct.introductoryPrice`. Mirror this in the App Store Connect metadata. |
| M-2 | **P0** | `lib/main.dart:102-133`; `lib/observability/telemetry.dart:116-137`; `lib/observability/error_reporter.dart:55-70` | **There is no consent layer.** Firebase Analytics and Crashlytics collect from first launch, with no opt-in, no Google Consent Mode v2 (`setConsent`), no UMP (`ConsentInformation`/`ConsentForm`), and no iOS ATT flow. The German/EEA market needs prior consent (GDPR/TTDSG), and AdMob requires a Google-certified CMP for EEA/UK traffic. | Default analytics and Crashlytics collection to off. Run UMP at startup and map it to Consent Mode v2. Request ATT only after UMP, and only if ads use the IDFA. Add a privacy screen in Settings for changing consent later. |
| M-3 | **P1** | `lib/auth/firebase_auth_repository.dart:65-114`; `lib/controllers/auth_controller.dart:314-329`; `lib/billing/revenuecat_billing_gateway.dart:32-44` | **Entitlement is read once per session.** `plan` comes from a one-shot `get()` with no `users/{uid}` listener. After a purchase, the client polls 3 times over about 0.75 s, but webhook latency is usually seconds, so most buyers land on the "purchase recognized, sync pending" notice. Renewals, expirations, and refunds aren't reflected until the next launch. There is no `Purchases.addCustomerInfoUpdateListener`. | Listen to snapshots of `users/{uid}` (plan and billing fields) in `AuthController`. Add the RevenueCat customer-info listener as a trigger. Keep an "activating…" state until the server flips the plan. |
| M-4 | **P1** | `/fighter_edge/functions/src/index.ts:115-120`; `lib/models/app_user.dart:50` | Both client and server treat `plan == "pro"` as Pro and **ignore `billing.expiresAtMs`**. One missed EXPIRATION webhook, or a manual grant (the handoff documents two), leaves paid AI on forever. | Treat Pro as `plan == pro && (expiresAtMs == null \|\| expiresAtMs > now)` on both sides. Add a scheduled job that reconciles against the RevenueCat REST API. |
| M-5 | **P1** | `/fighter_edge/functions/src/billing.ts:120` | **`TRANSFER` events are ignored.** Under RevenueCat's "transfer to new App User ID" restore behavior, restoring on a second Firebase account moves the store entitlement but never updates Firestore: the new account stays stuck on "sync pending" and the old account keeps Pro. | Handle TRANSFER by revoking on `transferred_from` and granting on `transferred_to`, with the expiry fetched from the RevenueCat REST API. Alternatively, choose the "keep with original App User ID" restore behavior and explain it in the UI. Add tests either way. |
| M-6 | **P1** | `lib/screens/paywall_screen.dart:210-235`; `lib/controllers/auth_controller.dart:227-234` | With billing unavailable, the paywall says "Join Pro Waitlist… Joining the waitlist records interest". **Nothing is recorded:** the button calls `startProCheckout()`, which throws and shows developer-facing text ("Connect the store products before purchasing."). | Record interest (a `waitlist/{uid}` document or email capture), or hide the CTA. Block release builds when `billingAvailable` is false. |
| M-7 | **P1** | `/fighter_edge/assets/data/edge_fuel_recipes_v1.json` (`isPremium`); `lib/training/drills/drill_catalog.dart`; `lib/training/corner_cues.dart` | **Three of the four Pro features are gated only on the client.** Premium recipes, the full drill library, and corner cues ship inside the APK/IPA and are hidden only by `AuthController.allows`. A patched client unlocks them offline. Only the AI coach is enforced on the server. | This is acceptable for a first launch if documented. For lasting value, serve premium content from Firestore or Storage behind rules that check a custom claim (`request.auth.token.pro`) set by the webhook. |
| M-8 | **P1** | `lib/billing/revenuecat_billing_gateway.dart` | ~~Only `purchaseCancelledError` is mapped... Calling `logOut()` on an anonymous RevenueCat user throws, and the error is swallowed upstream.~~ **Fixed (Phase 1).** See Phase 3 progress below. | — |
| M-9 | **P1** | (no code) | **AdMob isn't integrated.** There's no `google_mobile_ads`, no `com.google.android.gms.ads.APPLICATION_ID` or `GADApplicationIdentifier`, no ad-unit config per flavor, no `SKAdNetworkItems`, no `app-ads.txt`, and no Pro-aware ad suppression. | Add an `AdsGateway` interface mirroring `BillingGateway` (a no-op for tests and Pro users), initialized only after consent (M-2). Use test ad-unit IDs in dev and staging. See the placement plan below. |
| M-10 | **P1** | (no code) | **External payment gateways have no path yet.** Selling Pro (digital content) outside IAP violates App Store Guideline 3.1.1 and Play's Payments policy, except under specific programs: US-storefront external purchase links, Apple's StoreKit External Purchase entitlements in eligible regions, and Play's alternative or user-choice billing. Because the RevenueCat webhook is the sole entitlement authority, a second gateway would split the source of truth. | Decide the policy per storefront first. Route web and external purchases through RevenueCat Web Billing or its Stripe integration, so the same webhook grants `plan`. Never gate on a client flag. Enroll in the store programs before shipping any external link. |
| M-11 | **P2** | `lib/controllers/auth_controller.dart:148-169` | ~~Billing sync and product-load failures are swallowed (`catch (_) {}`) and never reported...~~ **Partly fixed (Phase 1).** `_syncBilling`'s failures now report as non-fatal (see Phase 3 progress below). Still open: no `BillingStatus` state for the paywall to distinguish "store down" from "no offering configured" — that's M-12's broader entitlement-state work. | — |
| M-12 | **P2** | `lib/billing/subscription.dart:76-89`; ~10 call sites | Entitlement checks are scattered, with no route guard for Pro routes such as `/fuel/coach`. `isPro` doesn't distinguish grace period, billing issue, expired, or pending states. | Add one `EntitlementState {free, pro, grace, billingIssue, expired, pending}` owned by a single controller, a `ProGate` widget, and a `go_router` redirect for Pro routes. |
| M-13 | **P2** | `lib/observability/telemetry.dart:13-33` | **Partly addressed on `main` (`a3844c2`):** there are now 16 client events, including the activation and habit funnel (onboarding, plan reveal, training and meal logged, reminders, week target, streak freeze). Still missing: server-side `trial_started`/`subscription_started`/renewal events, ad impression and revenue events, and paywall experiment variants. Without them you can't measure LTV or ad-versus-subscription cannibalization. | Emit conversion events from the webhook (GA4 Measurement Protocol or BigQuery). Enable the RevenueCat → Firebase integration. Log ad revenue with `onPaidEvent`. |

**Ad placement plan** (free tier only; nothing loads before consent):

| Where | Format | Notes |
|---|---|---|
| Recipe library list (every ~8 cards) | Native | Styled with `AppCard` tokens and clearly labelled "Ad". |
| After a completed session summary or a saved weigh-in | Interstitial | At a natural break. Cap at 1 per 10 min, never 2 in a row, and never on the first day. |
| "Unlock 1 premium recipe for 24 h" or "+1 AI trend summary" | Rewarded | An opt-in value exchange that also funnels users toward Pro. |
| Drill library list footer | Adaptive banner | Never on a drill's detail or practice view. |
| **Never** | — | Round timer (active training), paywall, onboarding, signup, email verification, mid-way through the Add Food sheet, AI chat, Settings or account deletion, and any Pro account. |

**Health data must never reach ad requests** (no nutrition, weight, or
allergy context as targeting keys). This is required by App Store Guideline
5.1.3 and Play's Health apps policy.

### 3.5 Security (OWASP MASVS basics)

| ID | Sev | file:line | Problem | Fix |
|---|---|---|---|---|
| S-1 | **P0** | `docs/CLAUDE_CODE_HANDOFF.md:530-537` (and git history) | **Credentials and PII are committed.** The doc contains a live **Pro** test account's email and **password**, a second tester's email, and both Firebase UIDs, in plain text. This contradicts the repo's own `CLAUDE.md` rule. Anyone with read access can sign in and spend paid AI quota, and the password remains in history. | Change that account's password or disable it now. Revoke the manual `plan: pro` grants. Redact the doc. Before sharing the repo with anyone else, purge history (`git filter-repo`) and treat the credential as leaked. Keep test credentials in a password manager. |
| S-2 | **P0** | `lib/auth/firebase_auth_repository.dart:230-234` | **Google sign-in is broken on Android and iOS.** The code calls `_auth.signInWithProvider(provider as OAuthProvider)`, but `GoogleAuthProvider extends AuthProvider`, not `OAuthProvider` (verified in `firebase_auth_platform_interface` 9.1.0 `providers/google_auth.dart:37`). Every mobile Google sign-in therefore throws a `TypeError`, which the login screen shows as an error. The button is visible because `supportsGoogle` is `true`, and this adapter has 0% test coverage. | Pass the `AuthProvider` through (`signInWithProvider` accepts `AuthProvider`). Add adapter tests with `firebase_auth_mocks`. Verify the SHA-1/256 fingerprints in Firebase for each signing key. |
| S-3 | **P0** (iOS) | `lib/auth/firebase_auth_repository.dart:27-31` | Google sign-in is offered while Sign in with Apple is disabled (`supportsApple => false`). App Review Guideline 4.8 requires an equivalent privacy-focused login option. | Enable Sign in with Apple (Apple service ID, the Firebase provider, and a nonce flow) on iOS, or hide Google on iOS until then. |
| S-4 | **P1** | `/fighter_edge/functions/src/index.ts:67-68`, `:168-174`, `:211-231`; `lib/main.dart:102-117` | **There is no App Check** on the client, Functions, or Firestore, and no size bound on the client-supplied `target`/`day`/`foodPreferences` sent to the model. `summarizeTrend` is open to every verified free account. A script with throwaway verified accounts can send megabyte-sized "facts" 20 times a day each, multiplying token spend (MASVS-RESILIENCE). | Add `firebase_app_check` (Play Integrity and App Attest, with a debug provider in dev) and set `enforceAppCheck: true` on the callables. Cap the size of `suppliedFactsJson` (e.g., 8 KB) and validate its shape. Set budget alerts in OpenRouter. |
| S-5 | **P1** | `/fighter_edge/functions/src/index.ts:168-231`; `/fighter_edge/functions/.env.fighter-edge-app` | **Health data goes to free third-party models.** Weight, targets, day logs, allergy and preference strings, and free-text chat go to OpenRouter's *free* model chain. Providers behind free endpoints may log, retain, or train on prompts. Under GDPR Art. 9 this is special-category health data, it isn't disclosed (the legal pages are placeholders), and there's no AI-specific consent. | Use paid models with zero-data-retention routing (OpenRouter provider data-collection set to "deny"). Minimize the payload. Add an explicit AI-processing consent. List subprocessors in the privacy policy. |
| S-6 | **P2** | `android/app/src/main/AndroidManifest.xml:16-19` | There's no `android:allowBackup="false"` and no `dataExtractionRules`, so the Firestore offline cache (health data) and SharedPreferences (food memory, streak state) go into cloud and device-transfer backups (MASVS-STORAGE). | Exclude `databases/` and `shared_prefs/`, or disable backup. On iOS, use `NSFileProtectionComplete`. |
| S-7 | **P2** | `/fighter_edge/functions/src/accountDeletion.ts:35`, `:48`, `:55` | The logs contain raw Firebase UIDs, against the repo's own logging rule. | Log a salted hash or the event only. |
| S-8 | **P2** | `lib/observability/error_reporter.dart:58-65` | `FlutterError.onError` reports **every** framework error (layout overflows, image errors) as `fatal: true`. That inflates the crash-free metrics and any alerting, and collection starts before consent (M-2). | Report framework errors as non-fatal. Keep fatal for uncaught zone/`PlatformDispatcher` errors, and gate collection on consent. |
| S-9 | **P2** | `lib/auth/firebase_auth_repository.dart:89` | `debugPrint('…$e')` isn't stripped in release, and Firestore errors can include the `users/{uid}` path, which puts the UID in logcat. | Guard it with `kDebugMode`, or route it through `ErrorReporter` without the message. |
| S-10 | **P2** | `lib/firebase_options.dart:52-67`; `android/app/google-services.json` | Firebase API keys are public by design, but nothing shows they're restricted. | Restrict them in Google Cloud (Android package + SHA-256, web referrer, API allow-list), with separate keys per flavor and project (R-4). |
| S-11 | **P3** | `/fighter_edge/functions/src/index.ts:328-333` | The webhook compares the `Authorization` header with `!==`, which isn't constant-time. | Use `crypto.timingSafeEqual` on equal-length buffers. |
| S-12 | **P3** | `/.github/workflows/flutter-ci.yml:32`, `:63`, `:102` | Third-party actions are pinned by tag (`subosito/flutter-action@v2`). There's no Dependabot or Renovate and no secret-scanning or push-protection configuration. | Pin actions by commit SHA, add `dependabot.yml` for pub, npm, and Actions, and enable secret scanning with push protection. |
| S-13 | **P3** | release commands (`README.md`, handoff §8) | Release builds don't use `--obfuscate --split-debug-info`, and no symbols are uploaded (MASVS-CODE/RESILIENCE, and crash readability). | Add both to the release pipeline and upload symbols to Crashlytics. |

**What's already right:** Firestore rules deny by default, and clients can't
touch billing fields (`firestore.rules:10-14`, `:70-99`). The `aiUsage` quota
documents are read-only to clients. The OpenRouter and webhook secrets stay on
the server in Secret Manager. The AI endpoint requires a verified email.
Passwords need at least 8 characters. Notification receivers aren't exported.
A scan of the git history (50 commits available locally) found no API keys,
service-account JSON, or private keys; the only secret leak is S-1.

### 3.6 UI/UX

| ID | Sev | file:line | Problem | Fix |
|---|---|---|---|---|
| U-1 | **P2** | `lib/screens/paywall_screen.dart` (all copy); `lib/screens/legal_screen.dart:45-55`; `lib/screens/round_timer_screen.dart:160-164`; `lib/main.dart:367-376`; `lib/notifications/local_reminder_gateway.dart:97-98` | **Localization is partial.** The ARB files have about 161 keys, but screens and widgets still contain 87 literal `Text('…')` strings plus interpolated ones. The paywall, legal, onboarding, coach, boot-failure screen, the timer's "Next" labels, and the notification text are English-only. A German listing with an English paywall and legal text is a consumer-law and review risk. | Move every user-facing string into ARB, starting with the paywall and legal pages. Add a test that fails on new `Text('literal')` in `lib/screens`. |
| U-2 | **P2** | `lib/screens/dashboard_screen.dart:180`, `:299`, `:808`, `:948`; `lib/screens/paywall_screen.dart:458`; `lib/widgets/premium_effects.dart:24-26`, `:49`, `:62`, `:88`; `lib/widgets/bottom_nav.dart:48` | There are 11 raw `Color(0x…)` gradients and shadows outside `AppColors`, plus 15 `Colors.white/black` uses (4 of them are legitimate mask stops in `filter_chips.dart:203-206`) (e.g., `edge_fuel_coach_screen.dart:709`, `:1295`; `training_camp_screen.dart:287`, `:321`; `primary_button.dart:67`; `filter_chips.dart:272`). | Add `AppColors.cardGradient*`, `onPrimary`, and `shadow` tokens, plus a test that fails on `Color(0x` in `lib/` outside `lib/theme/`. |
| U-3 | **P2** | ~80 `AppColors.textMuted` and ~90 `AppColors.textSecondary` direct reads (e.g., `paywall_screen.dart:244`, `:258`) | These surfaces bypass `AppAccessibility.textMuted/textSecondary(context)`, so **iOS/Android high-contrast mode is ignored** on them. | Switch to the context helpers, or carry high-contrast variants in the theme's `ColorScheme` so direct reads are correct. |
| U-4 | **P2** | `lib/state/app_state.dart` (no loading or error state); `lib/screens/weight_tracker_screen.dart`; `lib/screens/training_camp_screen.dart`; `lib/screens/dashboard_screen.dart` | Screens backed by `AppState` have no loading, error, or "not synced" states. A first launch shows empty or mock data (A-3), and a failed save is invisible (A-5). The AI surfaces already do this well, with skeletons and titled notices. | Give `AppState` (or its replacement controllers) a `status`, and reuse the existing `Skeleton` and notice widgets. |
| U-5 | **P2** | `lib/screens/round_timer_screen.dart:223-231` | The timer has no screen-reader strategy. The clock changes every second, phase changes aren't announced, and there's no audio for eyes-off use. | Announce phase and round changes with `SemanticsService.announce`, make only the phase label a live region, and add an audio bell and an optional voice countdown (P-1). |
| U-6 | **P2** | `lib/screens/nutrition_screen.dart:49` | The calorie ring is the same green at 5% and at 99% of target, and turns red only when over, so it can't signal "barely started" versus "on track". This comes from the earlier hands-on test and is a design call, not a bug. | Color the ring by progress band, always paired with text. |
| U-7 | **P3** | 34 × `BorderRadius.circular(<literal>)` (dashboard 8, nutrition 5, onboarding widgets 3, …); 72 literal icon `size:` values | Radii and icon sizes bypass the tokens, so they'll drift. | Extend the radius tokens and `IconSizes`, then migrate. |
| U-8 | **P3** | `lib/theme/app_colors.dart:56`, `:75` | Computed contrast: white on `primary` (#E63328) is **4.31:1**, and `primary` text on `surface` is **4.25:1**. Both pass only as large or bold text (≥ 3:1); they fail AA if used at body size. | Keep `primary` text at ≥ 18.66 px bold, and use `primaryBright`/`accentText` for small text. Add both pairs to `test/unit/color_contrast_test.dart`. |
| U-9 | **P3** | 29 direction-sensitive literals, e.g., `edge_fuel_coach_screen.dart:695`, `:723`, `:840`, `:923`, `:1225` (`Alignment.centerLeft/Right`), `recipe_library_screen.dart:384` (`EdgeInsets.only(right:)`); 43 `EdgeInsets.fromLTRB`; **0** `*Directional` | **The layout isn't RTL-ready.** Chat bubbles and accessory padding would mirror incorrectly in Arabic or Hebrew. Material chevron and arrow icons already flip on their own. | Use `EdgeInsetsDirectional`/`AlignmentDirectional`, and add an RTL golden before adding an RTL locale. |
| U-10 | **P3** | `lib/screens/home_shell.dart:135-148` | Switching tabs rebuilds each page from scratch, losing scroll position and filters (see A-7). | Use `StatefulShellRoute.indexedStack` or `PageStorageKey`s. |
| U-11 | **P3** | 7 `IconButton`s, only 5 with a `tooltip` | Icon-only controls without labels. | Add a `tooltip` (which also serves as the semantics label). |

**Already strong:** `AppAccessibility.minTouchTarget = 48` is applied
consistently, which clears Apple's 44 pt and Android's 48 dp minimums. Text
scaling is honored everywhere except the timer's hero numeral (capped at
1.25×, deliberately). The app handles bold text and high contrast, respects
reduced motion, has large-text tests, and contains no literal `fontSize`.

### 3.7 Testing gaps

| ID | Sev | file:line | Problem | Fix |
|---|---|---|---|---|
| T-1 | **P1** | `test/live_features_test.dart:17-56` | **Timer lifecycle is untested.** The round timer has 2 widget tests (count/pause/reset, and style switch). Nothing covers phase transitions, the final round, the session save, backgrounding and resume, drift, or the off-by-one (P-2). | Build the engine from P-1 with an injectable clock and unit-test the boundaries, pause and resume, and simulated background gaps. Widget-test lifecycle with `tester.binding.handleAppLifecycleStateChanged`. |
| T-2 | **P1** | `lib/auth/firebase_auth_repository.dart` (0 / 142); `lib/billing/revenuecat_billing_gateway.dart` (0 / 58) | **Purchase and restore are untested against the real adapters.** They're only tested through `FakeBillingGateway` in `AuthController`, and **`restorePurchases` has no test at all**. The zero-coverage auth adapter is how S-2 shipped. | Test the adapters with `firebase_auth_mocks` and a mocked `purchases_flutter` method channel. Cover a purchase matrix (success, pending, cancelled, already owned, network error, restore with none, restore with active). Document the store-sandbox matrix in the release strategy doc. |
| T-3 | **P1** | `/fighter_edge/functions/src/index.ts` handlers; `accountDeletion.ts`; `/fighter_edge/functions/src/rules.test.ts` | Only pure helpers are tested. There are no tests for the callable handler's paths (auth, email verified, entitlement, quota refund), the webhook transaction (idempotency, ordering, unknown user), or `deleteAccount`. **Partly addressed on `main`:** `functions/src/rules.test.ts` now tests the rules, but it only covers `trainingLog` and default-deny, it's skipped in `npm test` without an emulator ("SKIP no Firestore emulator"), and CI never runs `npm run test:rules`. Billing immutability, `aiUsage`, and profile creation are still untested. | Run the Firebase Emulator Suite in CI, with `firebase-functions-test` for handlers and `@firebase/rules-unit-testing` for the rules (owner-only access, billing immutability, read-only `aiUsage`). |
| T-4 | **P1** | `lib/data/firestore_data_repository.dart` (0 / 61); `lib/features/edge_fuel/data/firestore_edge_fuel_repository.dart` (0 / 91) | **Offline behavior is untested.** Nothing covers pending writes, reconnects, multi-device conflicts (D-1), the legacy migration, or the hang when a write is awaited offline (A-4). | Add `fake_cloud_firestore` mapping tests, plus emulator tests that toggle `disableNetwork`/`enableNetwork`. |
| T-5 | **P2** | `lib/main.dart` (47%) | No test checks that the production wiring passes every dependency (which would have caught A-1). | Add a bootstrap test with fake dependencies that asserts every provider resolves to the injected instance. |
| T-6 | **P2** | `integration_test/app_flow_test.dart`, `integration_test/performance_smoke_test.dart` | ~~Integration and performance smoke tests exist but aren't run in CI.~~ **Fixed (Phase 1).** See Phase 3 progress below. | — |
| T-7 | **P2** | `test/golden/component_gallery_golden_test.dart` | Goldens only reproduce on Windows (all 3 fail on Linux), and they cover just the component gallery. | Make goldens platform-stable (bundled test fonts plus a tolerant comparator, or `alchemist`), and add goldens for the paywall, timer, dashboard, and an RTL variant. |
| T-8 | **P3** | `test/unit/local_auth_repository_test.dart` | Tests exercise the dev-only `LocalAuthRepository` more than the production adapter. | Rebalance once T-2 lands. |

### 3.8 Release readiness

| ID | Sev | file:line | Problem | Fix |
|---|---|---|---|---|
| R-1 | **P0** | `fighter_edge/` (no `ios/`); `lib/firebase_options.dart:25-29`; `/fighter_edge/firebase.json:14-31` | **There is no iOS project and no iOS Firebase app.** `DefaultFirebaseOptions.currentPlatform` throws `UnsupportedError` on iOS, so boot fails. There's no Info.plist (and so no permission strings for notifications or `NSUserTrackingUsageDescription`), no capabilities (In-App Purchase, Sign in with Apple, push), no `PrivacyInfo.xcprivacy` privacy manifest, and no `SKAdNetworkItems` or `GADApplicationIdentifier`. | Run `flutter create --platforms=ios .` and `flutterfire configure` (one iOS app per flavor). Set the bundle ID, team, capabilities, privacy manifest, and Info.plist keys. Add a macOS CI job that builds an unsigned IPA. |
| R-2 | **P0** | `android/app/build.gradle.kts:33-38` | **The release build is signed with the debug keystore.** Play rejects debug-signed uploads, and testers on a debug-signed APK can't upgrade to a properly signed build without uninstalling (and losing local data). | Create an upload key with Play App Signing, load it from `key.properties` or CI secrets, and fail the release build if it's missing. |
| R-3 | **P0** | `lib/screens/legal_screen.dart:45-55` | **The Privacy Policy and Terms are placeholders** ("will be published before public launch"). Both stores require a live privacy policy URL, and a health, nutrition, and AI app in the EU needs a GDPR-grade policy. Neither the Play Data safety form nor the App Store privacy details have been mapped against the real data flows (Firestore, OpenRouter, Analytics, Crashlytics, RevenueCat, AdMob). | Publish hosted policies (Privacy, Terms, EULA, subscription terms, medical disclaimer, support contact, and an account-deletion URL). Link them from signup, Settings, the paywall, and the store listings. Fill in Data safety and App Privacy to match. |
| R-4 | **P1** | `android/app/build.gradle.kts:22-31`; `lib/main.dart:103`; `/fighter_edge/firebase.json` | **There are no dev/staging/prod flavors.** One application ID and one Firebase project (`fighter-edge-app`) serve development, testing, and live users; the handoff records manual production Firestore writes made for testing. The only environment config is the two RevenueCat keys passed via `--dart-define`. | Add `dev`, `staging`, and `prod` product flavors with matching iOS schemes and xcconfigs, a separate Firebase and RevenueCat project per environment, generated `firebase_options_<flavor>.dart` files, `--dart-define-from-file`, and an app-name suffix per environment. |
| R-5 | **P1** | `/.github/workflows/flutter-ci.yml`, `/.github/workflows/release.yml` | ~~No release or deploy pipeline.~~ **Mostly fixed.** `release.yml` (tag-triggered) builds a signed, build-numbered AAB with symbols, and now uploads it to Play's internal track automatically once the owner adds `PLAY_SERVICE_ACCOUNT_JSON` (`OWNER_SETUP.md` section 5) — Phase 1. `flutter-ci.yml` now runs the integration tests on an emulator too (T-6). `deploy-backend.yml` deploys functions and rules behind an approval gate. Still open: no iOS/TestFlight upload (Phase 7, needs the owner's Apple setup first). | — |
| R-6 | **P1** | `android/app/build.gradle.kts:23-24` | The `applicationId = "com.fighteredge.fighter_edge"` line still carries the template's TODO. It becomes permanent at the first Play upload, and the iOS bundle ID isn't chosen yet. | Choose the final IDs (e.g., `com.fighteredge.app`) before any store upload. |
| R-7 | **P2** | `pubspec.yaml:4` | The version is `1.0.0+1`, with no automated build-number bump. Both stores reject a reused build number. | Derive `--build-number` from the CI run or tag, and keep the semver in `pubspec.yaml`. |
| R-8 | **P2** | `lib/notifications/local_reminder_gateway.dart:53-56` | Initialization passes only `AndroidInitializationSettings` and no `DarwinInitializationSettings`, so reminders will fail on iOS even after A-1 is fixed. | Add the Darwin settings, request permission through the iOS plugin, and verify on a device. |
| R-9 | **P2** | `android/app/src/main/AndroidManifest.xml:12`, `:15` | Keep the permissions and the Play declarations in sync with what actually ships. Today reminders declare `POST_NOTIFICATIONS` and `RECEIVE_BOOT_COMPLETED` while the feature is dead (A-1). AdMob will merge in `AD_ID` (which needs the Advertising ID declaration), and the P-1 timer fix may need `SCHEDULE_EXACT_ALARM` or `USE_EXACT_ALARM` or a foreground-service type (each needs a Play declaration). | Record each permission, and the reason for it, in the release document. |
| R-10 | **P2** | `/fighter_edge/functions/.env.fighter-edge-app` | Production AI runs on a chain of free models (not a contract; one was withdrawn on 2026-09-20), configured in a project-specific env file. | Put a paid model first in the production chain, and keep one env file per project once flavors exist (R-4). |
| R-11 | **P3** | `android/app/build.gradle.kts:33-39`; `/fighter_edge/android/settings.gradle.kts` | ~~Minify and resource shrinking rely on Flutter's defaults, with no ProGuard rules file and no Crashlytics Gradle plugin (so no mapping upload).~~ **Fixed (Phase 1).** See Phase 3 progress below. | — |
| R-12 | **P3** | `/fighter_edge/windows/`, `/fighter_edge/web/` | The desktop and web targets are maintained but aren't product targets. CI goldens depend on Windows, and web runs without billing or analytics. | Decide whether to keep them. If not, drop them and move goldens to Linux (T-7). |
| R-13 | **P3** | repo | There are no store assets or metadata: screenshots, EN/DE descriptions, age-rating answers, IAP review screenshots, or a support URL. | Add `fastlane/metadata` or an equivalent. |

---

## Phase 1 status (2026-09-24)

Phase 1 was approved and implemented on this branch, one commit per slice.
"Code done" means the change is merged into this branch and tested. The
last column is what only the owner can do, with store, Firebase, or Apple
accounts.

| Finding | Commit | Code done | Still needs the owner |
|---|---|---|---|
| S-1 credentials in docs | `cff3a29` | Redacted from the handoff | **Change or disable that test account's password now.** It is still in git history. Revoke the two manual Pro grants once sandbox billing works. |
| S-2 Google sign-in crash | `012e622` | Cast removed. Adapter tests fail against the old code with the original TypeError. | Verify the SHA-1/256 fingerprints in Firebase for the upload key. |
| S-3 Apple 4.8 | `012e622` | Google is hidden on iOS unless `ENABLE_APPLE_SIGN_IN=true` | Apple service ID, the Firebase Apple provider, and the capability, then build with the flag |
| S-9 UID in release logs | `012e622` | The debugPrint is debug-only | — |
| P-1/P-2/P-3/U-5/T-1 round timer | `fb99e90` | Wall-clock engine, resume-correct, wakelock, voice calls, screen-reader announcements, no extra second; 22 new tests | Device check on a locked phone. The notification bell for a round that ends while the screen is off is a follow-up (needs exact-alarm / time-sensitive permission). |
| A-1 reminders unwired | `232cd86` | Wired, plus a wiring test for every dependency | Real-device notification check |
| A-4 offline logging hang | `232cd86` | UI no longer waits on server acks; writes never throw | — |
| M-6 fake waitlist | `232cd86` | Honest "Notify me" CTA | — |
| M-1 paywall disclosure | `4a9e714` | Localized renewal terms plus Terms and Privacy links | — |
| R-3 legal pages | `4a9e714` | `TERMS_URL`/`PRIVACY_URL` build config, with an in-app fallback | **Publish the Privacy Policy and Terms (EULA)**, then set them as release variables. Fill in Play Data safety and App Store privacy details. |
| M-2 consent | `3369409` | Collection off natively, Consent Mode v2 denied, a one-time Allow/Don't allow prompt, Settings toggles, and Dart-side gates | — (UMP/ATT arrive with ads in Phase 3) |
| S-8 fatal FlutterErrors | `3369409` | Reported as non-fatal | — |
| R-2 debug-signed release | `d575bc7` | Upload-key signing from `key.properties` or CI secrets; `bundleRelease` refuses without a key | **Create the upload keystore** and add the release secrets (see `release.yml`) |
| S-6 backups | `d575bc7` | Backup and device transfer excluded | — |
| R-1 iOS project | `bbc4bf2` | Runner project, Info.plist privacy keys, privacy manifest, real icon and splash | **Register the iOS app in Firebase and run `flutterfire configure --platforms=ios`**, set the signing team and capabilities, and choose the final bundle ID (R-6) |
| R-8 iOS reminders | `bbc4bf2` | Darwin init settings | — |
| D-2 Node 20 EOL | `bec8097` | Node 22, firebase-functions 7, firebase-admin 14; 12 → 2 moderate advisories | **Redeploy the functions before 2026-10-30** |
| R-5/S-12/T-3/T-7 CI | `bde422a` | Every PR, SHA-pinned actions, coverage gate, l10n check, rules emulator job (14 tests), obfuscated APK, iOS build, a tag-driven signed AAB release, Dependabot | Protect the `production` environment with required reviewers. Mark the new jobs as required checks. |

Not in Phase 1 (by design, see Phases 2-3): entitlement listener/expiry
(M-3, M-4), TRANSFER handling (M-5), App Check (S-4), data-model changes
(D-1, D-3), flavors (R-4), and ads (M-9).

## Phase 2 progress

| Finding | Status | Still needs the owner |
|---|---|---|
| M-3 entitlement read once per session | **Fixed.** The app follows `users/{uid}` live; purchase and restore call the new `syncEntitlement` function; a RevenueCat customer-info listener nudges the server. | Deploy the functions |
| M-4 expiry ignored | **Fixed.** `hasActivePro` (server) and `AppUser.isPro` (client) require the recorded expiry, with a 1 h renewal leeway and billing-issue grace. A `reconcileEntitlements` schedule (every 6 h) recovers missed renewals and expires lapsed plans. | Deploy the functions and the new composite index |
| M-5 TRANSFER dropped | **Fixed.** Both sides are re-read from the RevenueCat REST API; without a key the old side is revoked and the new side flagged. | Create the `REVENUECAT_API_KEY` secret (an `sk_` key; "unset" until RevenueCat exists) |
| S-11 webhook auth compare | **Fixed.** Constant-time comparison. | — |
| R-3 legal pages | **Drafted.** Privacy Policy, Terms and account deletion in EN/DE, ready for Firebase Hosting (`fighter_edge/hosting/`). Slice 2 removed the placeholders the app itself now satisfies (11 left in each privacy page, 6 in each terms page, 2 in each deletion page). | Fill in the `TODO(owner)` items, get a legal review, then deploy hosting (`fighter_edge/docs/OWNER_SETUP.md`) |
| Art. 9 explicit consent (the privacy policy's legal basis) | **Fixed (slice 2).** Consent is recorded on the account (`users/{uid}.consents`, versioned, with a server timestamp that the rules require). The app asks before onboarding collects body data; accounts onboarded earlier are asked once; the AI coach asks before its first request. The server refuses AI calls without consent. Both consents can be withdrawn in Settings > Privacy (withdrawing health-data consent leads to account deletion, as the policy says). | Legal review of the in-app wording (EN/DE) |
| D-9 deletion leaves billing data | **Fixed (slice 2).** Deletion first deletes the RevenueCat customer (RevenueCat unreachable = nothing deleted yet, retry is clean; unknown customer = already gone), then removes the account ID from `billingEvents`, then wipes `users/{uid}`. Webhooks for unknown accounts no longer store the ID. The delete dialog warns subscribers that the store subscription keeps billing. Deletion logs no longer carry the UID. | A real `REVENUECAT_API_KEY` once RevenueCat is live |
| Profile listener leak (found while testing M-3) | **Fixed (slice 2).** The `async*` profile follower only noticed cancellation at its next snapshot: the Firestore listener stayed open after sign-out, and a late snapshot could put the previous account back into `currentUser`. Now a plain subscription; two regression tests fail on the old code. | — |
| S-4 no App Check, unbounded AI facts | **Mostly fixed (plan step 0).** The app activates App Check (Play Integrity, DeviceCheck; debug providers in debug builds). `edgeFuelAiExplain` and `syncEntitlement` enforce it once `ENFORCE_APP_CHECK=true`. The server now trims the client's facts to the fields the model needs, bounds every string and list, and refuses more than 12 KB (`aiFacts.ts`). | Register the apps in App Check, then switch enforcement on once metrics show verified traffic (`OWNER_SETUP.md` section 4). Firestore enforcement stays off for now. |
| S-5 health data to free models | **Partly fixed.** Explicit AI consent (slice 2), data minimisation (`aiFacts.ts`: no IDs, timestamps or notes reach the prompt) and an `OPENROUTER_DATA_COLLECTION=deny` routing option. | Fund OpenRouter; then a paid model plus `deny` replaces the free chain (owner approved; Claude picks the model from the new usage totals) |
| D-8 one shared UTC quota, no cost tracking | **Mostly fixed.** Per-task daily limits (brief 6, chat 20, summarizeTrend 3; 25 total). Every request's tokens and cost go to `aiStats/{date}` (counts only), and a daily token budget across all accounts (`config/edgeFuelAi.dailyTokenBudget`, default 2M) pauses the AI. Still open: the reset is UTC midnight, not the athlete's local midnight. | Optional: adjust the budget in Firestore |
| R-10 free-model chain in production | **Ready to switch.** See S-5. | Same as S-5 |
| CD | **Added.** `deploy-backend.yml` deploys functions, rules and indexes after the unit and emulator suites pass (hosting on request), behind the `production` environment. | Configure Workload Identity Federation (or a service-account secret) and required reviewers |

## Phase 3 progress (closed-test hardening)

| Finding | Status | Still needs the owner |
|---|---|---|
| A-3 `MockData` shown to real users | **Fixed.** `AppState.setUser` no longer conflates "no repository" (the offline demo, kept for `main_local.dart`/tests) with "no user yet" (a real repository, but signed out or not yet resolved). The second case now starts empty instead of falling back to `MockData`, so a slow first launch or a sign-out never flashes fabricated weights, sessions or training history, and it can no longer survive sign-in until the first Firestore snapshot arrives. | — |
| A-5 streams have no `onError` | **Fixed for `AppState` and `EdgeFuelController`.** All seven `.listen(...)` subscriptions across the two (weights, meals, sessions, training log, profile draft, target, nutrition day) now handle stream errors: the last known data stays on screen, a debug-only log names the stream, and the subscription is never silently abandoned. Two regression tests per file cover the fix. | — |
| P-6 no startup timeout | **Fixed.** `FirebaseAuthRepository.init()` bounds both the persisted-session restore and the first profile read to 4 s (matching the existing `syncEntitlement` timeout pattern), so a stalled network starts the app cold instead of hanging on the splash screen. | — |
| P-9 verify-email screen polls in the background | **Fixed.** `VerifyEmailScreen` now stops its 3 s poll and 1 s cooldown ticker when the app is backgrounded (`AppLifecycleState.paused`), and checks once immediately on return instead of waiting for the next tick. | — |
| R-11 no ProGuard rules, no Crashlytics mapping upload | **Mostly fixed.** Release builds enable `isMinifyEnabled`/`isShrinkResources` with a documented `proguard-rules.pro`; `res/raw/keep.xml` protects the notification icon, which is looked up by string name and invisible to the resource shrinker. CI checks the built APK's native libraries are 16 KB page-aligned (Play's November 2025 requirement) and the manifest explicitly removes the advertising-ID permission — all confirmed working by CI. **The Crashlytics Gradle plugin isn't applied.** `2.8.1` doesn't work at all under this project's Gradle 9.1: its mapping-upload task threw `groovy/util/XmlSlurper` at runtime, and a `mappingFileUploadEnabled = false` workaround then failed Kotlin DSL *compilation* itself (`Unresolved reference 'firebaseCrashlytics'`) — whatever registers that plugin's per-variant DSL extension breaks the same way its Groovy usage does, so there's no live-editable flag to reach here; both failures were caught by CI, not locally. The plugin is removed entirely rather than applied-but-broken. Crash *reporting* still works (the `firebase_crashlytics` Android AAR's own runtime code, wired in by the Flutter plugin mechanism, independent of this Gradle plugin); only automatic mapping-file upload and build-ID injection are unavailable until a Gradle-9-compatible plugin version is confirmed. | — |
| P-4 weight/training lists re-sort or rebuild on every access | **Fixed.** `AppState` now caches the ascending/descending weight sort, recomputed only when weights actually change, instead of sorting on every read (the weight tracker's history called this once per row, making the screen O(n²)). The training log ("Session History") now renders through `SliverList.builder` inside a `CustomScrollView` instead of building every row up front, so it stays cheap as the log grows without a bound (see D-3). The weight tracker's history keeps its single-card-with-dividers layout eagerly for now — restructuring that into a lazy sliver without changing its look is deferred to the Phase 2/8 screen rebuild. | — |
| D-3 unbounded weight/training-log queries | **Deliberately not limited yet.** `watchTrainingLog`'s all-time entries feed `completedSessionCount` and the streak engine's `trainingDayKeys` ("across every week, not only this one") — adding a naive `.limit()` would silently corrupt both for any account past that limit, not just cap the history view. `watchSessions` is the weekly plan template (2-6 documents, not a growing log) and was never actually unbounded. Doing this correctly needs a separate bounded query for the history *list* alongside an unlimited (or aggregated) source for streak/count, which is Phase 3's data-model work (D-1/D-4), not a safe Phase 1 change. | — |
| M-8 incomplete RevenueCat error mapping | **Fixed.** `translateRevenueCatError` (a top-level, unit-tested function in `revenuecat_billing_gateway.dart`) maps `paymentPendingError`, `productAlreadyPurchasedError`, `storeProblemError`, `networkError` and `offlineConnectionError` to specific user-facing copy with a retry or restore suggestion, instead of the raw platform message; every other code keeps a specific `BillingException.code` for reporting. `restorePurchases()` now goes through the same mapping (it had no error translation at all before). `logOut()` swallows only `logOutWithAnonymousUserError` (two sign-out events in a row, or a session that never configured the store) and rethrows anything else. | — |
| M-11 silent billing-sync failures | **Partly fixed.** `AuthController._syncBilling`'s catch-all now reports the error (`reason: 'billing_sync_failed'`) instead of discarding it, so a store outage is visible in Crashlytics instead of looking identical to "no offering configured". Still open: no typed `BillingStatus`/`EntitlementState` for the paywall UI to read that distinction — that's M-12, deferred to the monetization phase. | — |
| T-6 integration tests not run in CI, and stale | **Fixed.** `integration_test/app_flow_test.dart` was rewritten to match the current app: no more "More" tab or "Corner Coach" (both gone), it now walks the real onboarding (welcome pages, Art. 9 consent, all 6 questions) to the dashboard, then — unlike `test/flow/app_journey_test.dart`'s headless twin, which proves the honest-waitlist path with billing unconfigured (M-6) — configures a `FakeBillingGateway` to exercise the real purchase button and confirm the client still does not grant Pro, only a simulated webhook (`repo.debugSetPlan`) does. `flutter-ci.yml` gets a new `integration-test` job (`reactivecircus/android-emulator-runner`, API 34, skipped on draft PRs) running both `integration_test/` files on a real Android emulator. | — |

## 4. Three-phase plan

Each phase ends with a verifiable exit gate. Findings are referenced by ID.

### Phase 1: P0 blockers (make a store-reviewable build)

**Goal:** a TestFlight build and a Play internal-testing build that a
reviewer can install, sign into, train with, and subscribe on.

| # | Work | Findings |
|---|---|---|
| 1 | **Credential hygiene, today.** Change the test account's password, revoke manual Pro grants, redact the handoff doc, and decide whether to purge history. | S-1 |
| 2 | Fix the Google sign-in cast and add adapter tests. Enable Sign in with Apple on iOS (or hide Google there). | S-2, S-3, T-2 (auth) |
| 3 | Rewrite the round timer as a wall-clock engine with lifecycle handling, wakelock, an audio bell, and scheduled phase notifications, plus unit and lifecycle tests. | P-1, P-2, T-1, U-5 |
| 4 | Create the iOS project: FlutterFire iOS app, bundle ID, capabilities, privacy manifest, Info.plist strings, Darwin notification init, and a macOS CI build. | R-1, R-8 |
| 5 | Android release signing with Play App Signing, plus final application and bundle IDs. | R-2, R-6 |
| 6 | Legal: hosted Privacy, Terms, EULA, and subscription terms; paywall disclosures and links; Data safety and App Privacy forms. | R-3, M-1 |
| 7 | Consent: collection off by default, UMP with Consent Mode v2, and a privacy settings screen. Only then add ATT, and only if ads use the IDFA. | M-2 |
| 8 | Quick wins, bundled in because they're small: wire `reminderGateway`; stop awaiting server acknowledgements in UI flows; remove the fake waitlist copy. | A-1, A-4, M-6 |
| 9 | Deadline-driven: move Functions to Node 22 and upgrade `firebase-functions`/`firebase-admin` before **2026-10-30**. | D-2 |

**Exit gate:** both platforms install and sign in with email, Google, and
Apple. A 25-minute timer session with the screen locked ends within ±1 s of
wall time and plays the bell. Sandbox purchase and restore succeed on both
stores. The paywall shows the disclosure. No analytics event fires before
consent. CI is green on `main`.

### Phase 2: Scale & performance (trustworthy data, costs, and entitlement)

| # | Work | Findings |
|---|---|---|
| 1 | Entitlement correctness: listen to `users/{uid}`, apply expiry-aware Pro on client and server, handle TRANSFER, add a RevenueCat reconciliation job, a `BillingStatus`/`EntitlementState` model, and `ProGate`, and map purchase errors. | M-3, M-4, M-5, M-8, M-11, M-12 |
| 2 | Abuse and cost control: App Check everywhere, AI payload bounds, per-tier and per-task quotas on the local day, paid zero-data-retention models, and budget alerts. | S-4, S-5, D-8, R-10 |
| 3 | Data model: an append-only training log (with migration), nutrition entries as a subcollection, bounded weight and session queries, a one-query week range, and legacy-meal backfill and removal. | A-2, D-1, D-3, D-4, D-6 |
| 4 | Rules hardening plus emulator tests for rules and handlers (webhook idempotency and ordering, deletion). Clean up billing events and RevenueCat data on account deletion. | D-5, D-9, T-3, S-7 |
| 5 | Environments: dev, staging, and prod flavors with separate Firebase and RevenueCat projects and restricted API keys. | R-4, S-10 |
| 6 | Offline-first hygiene: `onError` on every stream, a `Failure` model, sync and loading states, and no `MockData` in production paths. | A-3, A-5, U-4, T-4 |
| 7 | Performance: add `select`/`Selector`, cache sorted lists and use sliver history, split large screens, isolate timer repaints, build startup from cache, compress the login image, and profile against the budgets on a low-end Android device. | P-3…P-10 |
| 8 | CI/CD: a tag-driven release pipeline (signed AAB and IPA, store tracks, gated deploys), build numbers, nightly integration tests, SHA-pinned actions, Dependabot, and obfuscation with symbol upload. | R-5, R-7, T-5, T-6, S-12, S-13 |
| 9 | Structure: feature modules for training, weight, account, and billing; split `AppState`; tabs as `StatefulShellRoute`; strict lints. | A-6, A-7, A-8, A-9, A-10 |

**Exit gate:** a 500-user closed test for 2 weeks. Crash-free sessions
≥ 99.5% (with FlutterError reported as non-fatal, S-8). There are no lost
nutrition entries across two devices in the conflict test. Firestore reads per
daily active user are measured and flat over time. Webhook-to-Pro latency is
under 10 s at p95. AI cost per daily active user sits within budget.

### Phase 3: Design polish + monetization

| # | Work | Findings |
|---|---|---|
| 1 | **Ads:** add an `AdsGateway` with AdMob, gated on consent, suppressed for Pro, capped in frequency, and placed per the ad plan (never on the timer, paywall, onboarding, or AI chat). Add `app-ads.txt`, `SKAdNetworkItems`, and ad revenue logging. | M-9, M-13 |
| 2 | **External payments** only where the store program allows, routed through RevenueCat Web Billing so one webhook stays the entitlement authority. | M-10 |
| 3 | **Paywall optimization:** RevenueCat Offerings and experiments, intro trials, localized pricing, and server-side conversion events. | M-1 (polish), M-13 |
| 4 | **Premium content moved server-side** (recipes, drills, cues) behind custom claims. Streak freezes and food memory synced through Firestore. | M-7, D-7, D-10 |
| 5 | **Design-system completion:** color, radius, and icon-size tokens; high-contrast via context helpers; a calorie ring colored by progress band; screen-reader support for the timer; tab state preservation; icon-button tooltips. | U-2, U-3, U-6, U-7, U-8, U-10, U-11 |
| 6 | **Localization and RTL:** finish German (paywall and legal first), add a literal-string lint test, directional layout, and an RTL golden. Upgrade `fl_chart` 1.x and `go_router` 18. | U-1, U-9, T-7 |

**Exit gate:** ad ARPDAU and subscription conversion are tracked side by side
with no measurable drop in subscription conversion after ads launch. German
UI coverage is 100%. The accessibility audit passes (TalkBack, VoiceOver,
200% text, high contrast). Goldens pass on the CI platform, including RTL.

---

## Appendix: verification commands used

```bash
# Flutter 3.47.2 stable (matches CI pin), from fighter_edge/
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
dart pub outdated
flutter test --exclude-tags golden --coverage --reporter compact
flutter test --tags golden --reporter compact
# from fighter_edge/functions/ (Node 22 runtime in the audit container; engines pins 20)
npm ci && npm test && npm audit --omit=dev && npm outdated
```

Coverage was computed from `coverage/lcov.info`. Contrast ratios use the
WCAG 2.1 relative-luminance formula. The `GoogleAuthProvider` class hierarchy
was checked in the resolved `firebase_auth_platform_interface-9.1.0` package
source.
