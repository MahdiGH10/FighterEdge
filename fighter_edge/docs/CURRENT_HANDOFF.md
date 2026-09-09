# Fighter Edge — Current Claude Code Handoff

Last verified: 2026-09-09

This is the current operational handoff for the repository. Read this file
first, then `APPLICATION_BUILD_PLAYBOOK.md`. Older plans remain useful for
history and detailed specifications, but their progress markers may be stale.

## Product

Fighter Edge is a Dart and Flutter mobile application for combat-sport
athletes. Its core promise is:

> Fighter Edge tells a combat athlete what to eat and what to train today,
> and helps them stay consistent.

Android is the first release target. The Flutter code should remain compatible
with iOS, but iOS release work is deferred until the Android product is
validated.

## Technology boundary

- Mobile UI and client business logic: Dart and Flutter.
- State management: Provider with focused `ChangeNotifier` controllers.
- Authentication and data: Firebase Auth and Cloud Firestore.
- Privileged backend operations: Firebase Cloud Functions written in
  TypeScript.
- AI provider: OpenRouter, called only by Cloud Functions.
- Tests: Flutter unit, widget, and flow tests; Node tests for Cloud Functions.

TypeScript under `functions/` is server-only. Do not move secrets, account
deletion, entitlement writes, quotas, or AI-provider calls into the Flutter
client. Do not introduce React, Next.js, React Bits, Lenis, CSS components, or
another frontend stack.

## Repository and Git state

- Repository: `C:\Users\Mahdi\Downloads\FighterEdge`
- Flutter project: `C:\Users\Mahdi\Downloads\FighterEdge\fighter_edge`
- Branch: `main`
- Latest application commit before this documentation update:
  `c45ebe7 fix(dashboard): replace demo state with live user data`.
- Local `main` contains multiple commits not yet present on `origin/main`.
- The branch currently has no configured upstream tracking branch.
- Existing untracked items: `../.playwright-mcp/` and
  `docs/SESSION_HANDOFF.md`. Do not stage them without reviewing them.

Recent local commits:

```text
c45ebe7 fix(dashboard): replace demo state with live user data
46794f6 fix(ui): expose only working MVP flows
4523bdc fix(camp): stop session titles/descriptions breaking mid-word
769731a fix(theme): give error state its own color instead of reusing brand red
98e787a fix(ui): prevent button label overflow on narrow widths
b905351 feat(auth): add account deletion
```

## Verified quality state

The following passed on 2026-09-09:

```text
dart format .                         134 files, no changes
flutter analyze                      No issues found
flutter test --no-pub                255 tests passed
cd functions && npm test             10 tests passed
cd functions && npm run build        TypeScript compiled
```

`flutter build apk --debug` reached Gradle but stopped because the local
Android SDK has not accepted the NDK 28.2.13676358 license. This is a machine
setup blocker, not a Dart compilation failure. The user should accept Android
SDK licenses before the next APK verification.

## What is working

### Account and onboarding

- Email/password authentication.
- Google authentication code path; native Android still needs real-device
  verification.
- Email verification and password reset.
- Fresh-account onboarding with goal, experience, training days, and starting
  weight.
- Secure account deletion through a callable Cloud Function.
- Owner-scoped, deny-by-default Firestore rules with billing fields protected
  from client writes.

### Training

- Personalized weekly training plan created during onboarding.
- Training-session completion, RPE, notes, persistence, history, and streaks.
- Boxing, MMA, and BJJ round timer presets.
- Dashboard now reads persisted sessions instead of fixed sample activity.

### EdgeFuel

- Deterministic calorie and macro engine with safety policies.
- Six-step nutrition setup and persisted target.
- Daily food logging, editing, completion state, saved entries, and legacy
  migration.
- Bundled food catalog and 24-recipe catalog.
- Recipe filtering, allergen warnings, serving scaling, free/Pro gating, and
  adding a recipe to today's food log.
- Secure AI gateway contract and backend validation.
- AI Coach client access is Pro-gated.
- Dashboard fuel remaining now reads `EdgeFuelController`, not legacy mock
  nutrition state.

### Mobile UX

- Primary navigation now exposes only working MVP areas: Home, Camp, Fuel,
  and More.
- Unfinished Technique, Corner Coach, Mobility, Camp Plan, and Analytics
  surfaces are hidden, not deleted.
- Dead header buttons were removed.
- Narrow button, filter-chip, training-row, and metric-card overflows were
  fixed.
- Production repository-backed state starts empty instead of flashing demo
  data to a new user.

## What is not ready

The application is not ready for a paid public launch yet.

### Release blockers

1. Local Android SDK licenses are not accepted, so an APK has not completed on
   this machine after the latest changes.
2. Five local commits are not pushed to GitHub.
3. CI tests Flutter but does not yet test or compile `functions/`.
4. Privacy Policy, Terms, billing terms, and the medical/nutrition disclaimer
   are placeholders.
5. A public account-deletion information/request URL is still required for
   Google Play compliance.
6. Firebase Crashlytics is not integrated.
7. Production app icon, native splash, release signing, and store metadata are
   unfinished.
8. Native Google Sign-In has not been verified on a real Android device.
9. RevenueCat/store subscriptions and server-owned entitlement synchronization
   are not implemented.
10. The exposed OpenRouter credential must be confirmed revoked and replaced
    before public AI use. Never place the replacement key in source or chat.
11. EdgeFuel food data, recipes, and safety constants still carry draft status
    pending qualified professional review.

### Deliberately deferred

- Technique videos.
- Corner Coach personalization.
- Mobility routines.
- Full fight-camp planning.
- EdgeFuel EF-4 training-load integration.
- EdgeFuel EF-5 Weekly Fuel Review.
- Meal plans and grocery lists.
- iOS store release.

These are preserved for later. Do not expose them as working features before
their acceptance criteria are met.

## Immediate next work

### User/environment actions

1. Accept Android SDK licenses using Android Studio's SDK Manager or the local
   `sdkmanager --licenses` command.
2. Run `flutter build apk --debug` again.
3. Push the five local commits and set upstream tracking:

   ```bash
   git push -u origin main
   ```

4. Confirm the previously exposed OpenRouter key has been revoked. Store the
   replacement only as the Firebase secret `OPENROUTER_API_KEY`.

### Next Claude Code task

Add Cloud Functions verification to GitHub Actions:

- Use Node 20.
- Run `npm ci`, `npm test`, and `npm run build` in
  `fighter_edge/functions`.
- Keep the existing Flutter job unchanged.
- Run the complete local quality gate.
- Commit exactly one focused change with message:

  ```text
  ci: test Firebase Functions
  ```

After that, continue the release-blocker queue in
`APPLICATION_BUILD_PLAYBOOK.md`. Do not start EF-4 or another large feature
until the paid Android MVP can be tested safely.

## Commands

From `fighter_edge/` on Windows PowerShell:

```powershell
& 'C:\src\flutter\bin\dart.bat' format .
& 'C:\src\flutter\bin\flutter.bat' analyze
& 'C:\src\flutter\bin\flutter.bat' test --no-pub
& 'C:\src\flutter\bin\flutter.bat' build apk --debug
```

Backend:

```powershell
Set-Location functions
npm test
npm run build
```

## Handoff rule for future sessions

Before changing code, verify `git status`, recent commits, and the relevant
implementation. Complete one bounded slice, test it, review its diff, commit
it, and update this handoff if its facts changed. Never claim that a deploy,
purchase, real-device test, credential rotation, or professional nutrition
review happened without direct evidence.
