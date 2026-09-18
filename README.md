# Fighter Edge

Fighter Edge is a mobile-first Flutter app for MMA and combat-sport athletes.
It helps a fighter answer two questions every day: **what should I eat, and
what should I do next?**

The product combines a personalized EdgeFuel nutrition loop, training and
weight logging, a round timer, onboarding, and an optional Pro subscription for
deeper analytics, premium recipes, technique content, and the AI Fighter Brief.
The app is intentionally dark, focused, and athletic rather than a generic
fitness dashboard.

## Repository map

```text
fighter_edge/
  lib/                         Flutter application
    auth/                      Firebase/local authentication contracts
    billing/                   RevenueCat gateway and entitlement UI
    features/edge_fuel/        Nutrition domain, data, UI, and AI boundary
    observability/             Privacy-safe analytics and error reporting
    routing/                   App routes and navigation
    screens/                   Product screens
    theme/                     Design tokens and accessibility helpers
  functions/                   Firebase Cloud Functions (TypeScript)
  test/                        Unit, widget, flow, accessibility, and golden tests
  integration_test/            Device/browser integration tests
  docs/                        Product, architecture, release, and handoff docs
  assets/                      Bundled food/recipe data, fonts, and images
.github/workflows/flutter-ci.yml
                               Analyze, test, goldens, Functions, and Android build
```

The Flutter application is in `fighter_edge/`; the repository root contains
project documentation and CI configuration. JavaScript/TypeScript is used only
for the Firebase Functions backend, not for the mobile UI.

## Current product state

Implemented and tested:

- Firebase email/password and Google authentication flows, verification gate,
  session-safe routing, and account settings.
- Fresh first-run onboarding with a personalized plan reveal, guided tour, and
  first-win checklist.
- EdgeFuel deterministic nutrition calculations, safety checks, daily targets,
  food logging, allergen filtering, serving scaling, and recipe catalog.
- Training sessions, streaks, weight tracking, charts, and a round timer.
- Free/Pro feature gates, annual-first paywall presentation, restore/manage
  purchase affordances, and privacy-safe premium conversion telemetry.
- Server-backed EdgeFuel AI boundary with schema validation, quota handling, and
  safety enforcement. The deterministic target remains authoritative.
- Firestore rules that prevent clients from granting or modifying billing
  entitlements.

Not yet production-complete:

- RevenueCat webhook deployment needs the Firebase secret
  `REVENUECAT_WEBHOOK_AUTH`.
- App Store/Google Play products and sandbox purchase/restore tests still need
  account-level configuration.
- Production legal URLs, account deletion verification, store metadata,
  release signing, and final device QA remain release work.

Never place OpenRouter, Firebase Admin, RevenueCat, or store secrets in this
repository or in Flutter configuration. Use Firebase Secret Manager and local
environment/configuration instead.

## Requirements

- Flutter `3.47.2` (Dart `3.13.2`)
- Node.js `20` and npm for `fighter_edge/functions`
- Firebase CLI for emulator/deployment work
- Android Studio/SDK for Android builds
- Xcode and Apple Developer access for local iOS builds (or a macOS CI runner)

On this project machine the Flutter executable is
`C:\src\flutter\bin\flutter.bat`.

## Local development

```powershell
cd C:\Users\Mahdi\Downloads\FighterEdge\fighter_edge
flutter pub get
flutter run -d chrome       # fast browser smoke test
```

The production bootstrap uses Firebase. For isolated widget/unit work, tests
inject local in-memory repositories and fake billing/AI gateways; do not add
fake providers to the production bootstrap.

## Verification commands

Run these from `fighter_edge/` before committing Flutter changes:

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --exclude-tags golden --coverage --reporter compact
flutter test --tags golden --reporter compact
```

Run the backend checks from `fighter_edge/functions/`:

```powershell
npm ci
npm test
```

The Android release check used by CI is:

```powershell
flutter build apk --config-only
flutter build apk --release --no-pub
```

## Architecture rules

1. Keep `lib/features/edge_fuel/domain/` pure Dart. It must not import Flutter,
   Firebase, network clients, platform APIs, or a clock.
2. Keep deterministic nutrition calculations authoritative. AI can explain or
   prioritize a result, but cannot invent or replace calorie/macro targets.
3. The server and RevenueCat webhook own paid entitlements. The client may
   start a purchase and display state, but must never grant Pro itself.
4. Treat telemetry as privacy-safe by design: no prompts, meal text,
   measurements, receipt tokens, email addresses, or Firebase UIDs in events.
5. Use the existing design vocabulary (`AppColors`, `AppType`, `Insets`,
   `MotionTokens`, `AppHaptics`, `PressScale`) instead of one-off styles.
6. Build one bounded slice at a time: inspect, implement, test, commit, then
   choose the next slice.

## Documentation guide

- [`fighter_edge/docs/CLAUDE_CODE_HANDOFF.md`](fighter_edge/docs/CLAUDE_CODE_HANDOFF.md)
  — verified engineering state and continuation notes.
- [`fighter_edge/docs/DESIGN_SYSTEM_PLAN.md`](fighter_edge/docs/DESIGN_SYSTEM_PLAN.md)
  — design-system phases and decisions.
- [`fighter_edge/docs/PRODUCT_MONETIZATION_STRATEGY.md`](fighter_edge/docs/PRODUCT_MONETIZATION_STRATEGY.md)
  — free/Pro value strategy.
- [`fighter_edge/docs/RELEASE_QUALITY_AND_TEST_STRATEGY.md`](fighter_edge/docs/RELEASE_QUALITY_AND_TEST_STRATEGY.md)
  — quality gates and release planning.
- [`fighter_edge/docs/OBSERVABILITY_AND_STORE_SETUP.md`](fighter_edge/docs/OBSERVABILITY_AND_STORE_SETUP.md)
  — Firebase, RevenueCat, analytics, and observability setup.
- [`fighter_edge/docs/START_HERE.md`](fighter_edge/docs/START_HERE.md)
  — historical product checklist; verify status against the current handoff.

## CI and publishing

`.github/workflows/flutter-ci.yml` runs on pushes and pull requests to `main`:

1. Flutter formatting, analysis, non-golden tests, and coverage artifact.
2. Windows golden tests.
3. Android release APK build and artifact upload.
4. Functions TypeScript build and tests.

Keep CI green before merging. A green CI run proves the repository builds and
tests; it does not prove that store accounts, Firebase secrets, webhook
deployment, signing, or sandbox purchases are configured.

## License and release note

This is a private, unpublished product repository (`publish_to: none`). Add a
license and public legal/privacy URLs before opening the project or publishing
the app.
