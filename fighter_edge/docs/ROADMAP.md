# FIGHTER EDGE — Product Roadmap

_Last updated: July 2026. Status: working prototype — 8 screens, real Firebase auth
(email/password + Google), Free/Pro gating (demo), 53 tests green, CI on GitHub,
APK shipped to first tester._

**Guiding order: make it real → make it feel great → make it earn.**
Data persistence comes before animations; server-side entitlements come before payments.

## Current execution track

The historical phases below remain the long-range product map. The active work is
tracked in these implementation documents so product, design, and engineering do
not drift apart:

- [Product and monetization strategy](PRODUCT_MONETIZATION_STRATEGY.md)
- [Phase 7: Premium Fighter Brief](PHASE_7_PREMIUM_FIGHTER_BRIEF.md)
- [Release quality and test strategy](RELEASE_QUALITY_AND_TEST_STRATEGY.md)

### Delivered in the current slice

- Phase 6C activation polish: target explanation, meal empty state, and premium
  value framing.
- Phase 7A: a pure-Dart Fighter Brief preview with honest no-data states and
  nutrient-gap prioritization.
- Widget and unit coverage for the new preview; full suite remains green at 267
  Flutter tests plus 10 Functions tests.

### Next implementation order

1. Phase 7B: server-backed, schema-validated premium brief with quota and safety
   enforcement.
2. Phase 7C: real subscription state (RevenueCat or store billing), restore,
   cancellation, and trusted entitlement sync.
3. Phase 7D: event measurement, performance profiling, and release hardening on
   a physical Android device before TestFlight work.

---

## Phase 1 — Make it real (per-user cloud data) 🎯 NEXT

The single biggest gap: weights/meals reset on every restart. Until this is fixed,
testers churn and nothing else matters.

- [ ] `DataRepository` interface mirroring the `AuthRepository` pattern
      (`lib/data/data_repository.dart`): weights, meals, sessions per user
- [ ] `FirestoreDataRepository`: `users/{uid}/weights/{id}`, `users/{uid}/meals/{date}`,
      `users/{uid}/sessions/{id}` — offline persistence ON (Firestore caches locally,
      free tier)
- [ ] Extend `firestore.rules` to the subcollections (same owner-only pattern)
- [ ] `AppState` reads/writes through the repository; seed data only for new accounts
- [ ] Nutrition becomes date-keyed (today's meals, history per day) → unlocks the
      Analytics tab with real data
- [ ] Training Camp: mark sessions complete → streak becomes computed, not mocked
- [ ] Profile stats (training days, workouts) computed from real data
- [ ] Tests: fake `DataRepository` in the harness; unit tests for date-keying + streaks

## Phase 2 — Auth fixes & hardening

- [ ] **Email verification flow**: banner on dashboard when `emailVerified == false`,
      resend button; Firebase already sends the email on signup
- [ ] **Hide broken buttons under Firebase**: Apple + magic-link currently throw
      `unsupported` — hide them when the repo is `FirebaseAuthRepository` (capability
      flags on the interface, e.g. `supportsApple`, `supportsMagicLink`)
- [ ] Account settings: change display name, change password, **delete account**
      (required by Play Store policy for apps with accounts)
- [ ] Re-auth before destructive actions (delete account requires recent login)
- [ ] Google sign-in on **Android**: add SHA-1/SHA-256 fingerprints to Firebase console
      + regenerate google-services.json (popup flow works on web; native needs this)
- [ ] Enable **App Check** (free) to throttle abuse of Auth/Firestore

## Phase 3 — Feel great (animations & polish)

Keep it dark, fast, restrained — the brand is discipline, not confetti.

- [ ] Page transitions: fade-through between tabs, shared-axis push for detail screens
- [ ] Hero animation: dashboard weight card → Weight Tracker
- [ ] Animated counters (weight, calories) — `TweenAnimationBuilder`, 300ms
- [ ] Round Timer: pulse the ring on the last 10s of a round, color shift WORK→REST,
      haptic + sound cue on round change (`HapticFeedback`, `audioplayers` for bell)
- [ ] Meal check: satisfying scale+check animation; calorie ring animates to new value
- [ ] Chart entrance animation (fl_chart supports animated `LineChartData` swap)
- [ ] Skeleton loaders while Firestore data loads (shimmer on cards)
- [ ] Micro-interactions: button press scale (0.97), snackbar slide-in
- [ ] Splash screen: brand logo fade (flutter_native_splash for the native part)

## Phase 4 — Branding

- [ ] **App icon**: replace default Flutter icon with the FE mark on near-black
      (`flutter_launcher_icons`, adaptive icon for Android)
- [ ] Native splash matching #0A0A0B (flutter_native_splash)
- [ ] Bundle Oswald + Inter as assets (kill the runtime Google Fonts fetch — offline
      brand consistency; already flagged in review)
- [ ] Empty states + error states all use brand voice ("The grind never lies.")
- [ ] App name/store listing copy, feature screenshots (can reuse mockup style)
- [ ] Onboarding: 3-screen intro (train / track / win) shown once after signup

## Phase 5 — Feature depth (functionalities)

Ordered by user value:

1. [ ] **Workout logging**: start session from Camp → timer → mark done → history
2. [ ] **Weight**: body-fat + measurements tabs become real (same repo pattern);
       goal weight line on the chart; weekly average trend
3. [ ] **Nutrition**: add/edit custom meals, per-day history, weekly analytics
       (calorie/macro bar chart — Pro)
4. [ ] **Technique Library**: real video playback (`video_player` + Firebase Storage
       free tier, or YouTube embeds to stay at $0); favorites; per-video progress
5. [ ] **Corner Coach v2**: rule-based cue engine driven by user's recent data
       ("You cut 0.5kg this week — hydrate before sparring"); later: Claude API
6. [ ] **Mobility**: guided routines with interval timer reuse
7. [ ] Notifications: training reminder, weigh-in reminder (flutter_local_notifications
       — local only, free, no server needed)

## Phase 6 — Settings screen

- [ ] `SettingsScreen` from Profile/More: units (kg/lb), week start day,
      timer sound on/off, haptics on/off, reminder times
- [ ] Persist in `users/{uid}.settings` map (syncs across devices)
- [ ] Legal: Privacy Policy + Terms links (required for Play Store; generate pages,
      host on GitHub Pages for $0)
- [ ] About: version, licenses (`showLicensePage`), contact/support email

## Phase 7 — Payments (the real SaaS switch) 💰

⚠️ Prereq: server-authoritative entitlements. Requires **Blaze plan** (needs a card;
free quota is generous but this is the one step beyond strict $0).

- [ ] **RevenueCat** (`purchases_flutter`) — free up to $2.5k MTR; products:
      monthly + annual (annual discount)
- [ ] Play Console account ($25 one-time) + in-app products
- [ ] Cloud Function: RevenueCat webhook → verify signature → write
      `users/{uid}.plan` via Admin SDK
- [ ] Tighten `firestore.rules`: client can **no longer write `plan`**
      (rule already drafted in docs/firebase_setup.md §5)
- [ ] Paywall v2: annual/monthly toggle, restore purchases, real prices from the store
- [ ] Free trial (7 days) configured in Play Console
- [ ] Remove "demo — no payment taken" copy and the client `setPlan` write path

## Phase 8 — Tests & quality (continuous, not a phase)

- [ ] Fake `DataRepository` tests for every Phase 1 feature as it lands
- [ ] Golden tests for key screens (visual regression on the dark theme)
- [ ] Integration test on a real device/emulator in CI (macos/linux runner + AVD)
- [ ] Coverage report in CI (`flutter test --coverage` + badge)
- [ ] Crash reporting: Firebase Crashlytics (free) before wider distribution
- [ ] Performance: `flutter build apk --analyze-size`; defer chart lib on login route

## Phase 9 — Videos & tutorials

- [ ] Technique content: record or license; host on YouTube (unlisted) embeds = $0,
      or Firebase Storage within free quota
- [ ] In-app tutorial overlays: first-run coach marks on Timer & Nutrition
      (highlight + one-line tip, dismiss forever)
- [ ] "How to cut weight safely" style articles (markdown rendered in-app) — Pro content
- [ ] Promo video for store listing (screen recording + captions)

## Best practices (standing rules)

- Repository pattern for every backend surface (auth ✅, data → Phase 1)
- No client-trusted entitlements once money is involved (Phase 7)
- `flutter analyze` + `dart format` + all tests green before every push (CI enforces)
- Feature branches + PRs once a second contributor joins; main stays releasable
- Secrets never in the repo (Firebase client config is public-by-design; server keys
  live only in Cloud Functions env)
- Every new decision-heavy module ships with unit tests in the same commit
- Accessibility: min 44px touch targets, semantic labels on icon buttons, contrast
  already strong on the dark theme

## Suggested sequence (realistic solo pace)

| Week | Focus |
|------|-------|
| 1–2  | Phase 1 (cloud data) + Phase 2 auth fixes |
| 3    | Phase 4 branding (icon/splash/fonts) + Phase 6 settings |
| 4–5  | Phase 3 animations + Phase 5 items 1–3 |
| 6    | Phase 8 hardening (Crashlytics, goldens) + closed testing track on Play |
| 7–8  | Phase 7 payments + Phase 5 items 4–5 + store launch prep |
