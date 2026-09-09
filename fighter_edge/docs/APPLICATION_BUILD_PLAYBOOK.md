# Fighter Edge — Ten-Step Application Build Playbook

Last updated: 2026-09-09

This document applies Mahdi's ten-step application-building method to Fighter
Edge. It records what is complete, what needs improvement, and what happens
next. It is an execution guide, not a feature wish list.

## Status legend

- **Established:** the decision exists and is supported by working code.
- **Improve:** the foundation exists but needs correction or completion.
- **Next:** current execution priority.
- **Deferred:** intentionally outside the paid Android MVP.

## 1. Understand the problem

**Status: Established**

The problem is not “fighters need another calorie counter.” Combat athletes
must coordinate nutrition, training, recovery, weight direction, and
consistency. Generic fitness apps separate these decisions and rarely account
for fight-camp demands.

Primary user: adult amateur combat-sport athletes training two to six days per
week.

Core product promise:

> Know what to eat, know what to train, and stay consistent.

Primary success signal: an athlete completes useful weekly actions in both
Fuel and Camp and returns the following week.

### Improve

- Interview and observe at least ten target users during closed beta.
- Record where users hesitate during onboarding, food logging, session
  logging, and the paywall.
- Validate whether “today's decisions” is the strongest reason to subscribe.

## 2. Define the requirements

**Status: Established; release requirements incomplete**

### Paid Android MVP requirements

- Account creation, sign-in, verification, reset, onboarding, and deletion.
- Personalized deterministic nutrition targets.
- Daily food logging and useful curated recipes.
- Weekly training schedule, session logging, RPE, notes, and round timer.
- Weight logging and trend display.
- Honest Free and Pro feature boundaries.
- Real Google Play subscriptions with restore and expiry behavior.
- Privacy, Terms, billing terms, health disclaimer, and public deletion URL.
- Crash reporting and a signed Android release build.
- No visible control that does nothing and no screen pretending to contain
  unavailable content.

### Non-functional requirements

- Owner-only health and account data.
- Secrets and privileged writes remain server-side.
- Food logging tolerates temporary connectivity loss through Firestore's
  offline behavior.
- Touch targets are at least 44 logical pixels.
- Critical screens tolerate larger text and narrow Android devices.
- Health-critical targets remain deterministic, versioned, and tested.

### Deferred requirements

- Technique video library, personalized Corner Coach, mobility programs,
  advanced camp planning, meal plans, grocery lists, and iOS launch.

## 3. Design the system

**Status: Established; mobile validation remains**

The product uses a dark, disciplined, athletic interface with restrained
crimson accents. Inter handles interface text; Oswald is reserved for display
headings and large numbers. Motion communicates state and respects reduced
motion.

Current mobile information architecture:

```text
Home
├── Today's training and fuel focus
├── Weight, sessions, and streak
├── Weekly completion
└── Recent real activity

Camp
├── Week
└── History

Fuel
├── Today
├── Meals
└── Recipes

More
├── Round Timer
├── Weight Tracker
├── Profile
└── Settings
```

### Improve

- Test the main journeys at approximately 360×640, 390×844, and a large-text
  accessibility setting.
- Add explicit loading/error states where Firestore streams currently move
  directly from empty to data.
- Keep unfinished areas hidden until they are functional.
- Avoid cosmetic redesigns before the release blockers are complete.

## 4. Choose the architecture and stack

**Status: Established**

```text
Flutter mobile client (Dart)
        |
        | Firebase Auth / Firestore / callable Functions
        v
Firebase Cloud Functions (TypeScript, server only)
        |
        +-- OpenRouter AI
        +-- Firebase Admin account deletion
        +-- RevenueCat webhook and entitlement writes (next)
```

Decisions:

- Flutter and Dart are the only client UI stack.
- Provider/ChangeNotifier remains until a concrete scaling problem justifies a
  migration.
- Navigation remains Flutter `Navigator` until deep linking or guarded routes
  create a concrete need for a router package.
- Firebase Auth and Firestore remain the account/data platform.
- Firebase Functions owns secrets and privileged operations.
- RevenueCat is the recommended subscription layer for Google Play and later
  iOS.
- OpenRouter may explain deterministic facts but never calculates or changes
  calories, macros, safety results, or weight-loss pace.

Do not add React, Next.js, React Bits, Lenis, a web UI framework, or direct
client access to OpenRouter.

## 5. Set up the project structure

**Status: Established; cleanup needed**

Important directories:

```text
lib/
├── auth/                 authentication repositories
├── billing/              plan and feature entitlements
├── controllers/          app-level controllers
├── data/                 training/weight repositories
├── features/edge_fuel/   isolated nutrition domain, data, AI, and UI
├── models/               shared application models
├── screens/              primary mobile screens
├── state/                legacy/shared AppState
├── theme/                colors, typography, spacing, motion
└── widgets/              reusable Flutter components

functions/src/            privileged Firebase backend
test/unit/                calculations and policies
test/widget/              UI states and interactions
test/flow/                cross-screen journeys
integration_test/         device-level journey scaffold
assets/data/              reviewed-by-tests food and recipe catalogs
docs/                     product, safety, deployment, and handoff context
```

### Improve

- Remove the dead legacy `Meal` state/repository path only after confirming
  EdgeFuel migration no longer needs its public interfaces.
- Keep new feature state outside `AppState`; use focused controllers.
- Do not introduce extra layers merely to make the folder tree look more
  sophisticated.
- Add Cloud Functions tests to CI.

## 6. Define the right context and Markdown files

**Status: Improved by this documentation pass**

Read documents in this order:

1. `docs/CURRENT_HANDOFF.md` — verified current repository state and next task.
2. `docs/APPLICATION_BUILD_PLAYBOOK.md` — this ten-step execution system.
3. `docs/START_HERE.md` — launch philosophy and broader checklist; verify old
   progress claims against the handoff.
4. `docs/edge_fuel/PRODUCT_SPEC.md` and
   `docs/edge_fuel/SAFETY_AND_EVIDENCE.md` before EdgeFuel domain changes.
5. `docs/EDGEFUEL_AI_CLAUDE_CODE_MASTER_PROMPT.md` before starting a numbered
   EdgeFuel sprint.
6. `docs/edge_fuel/AI_DEPLOY.md` before deploying the AI backend.

Treat these as historical/reference documents rather than current status:

- `docs/ROADMAP.md`
- `docs/PROJECT_CONTEXT.md`
- `docs/FIGHTEREDGE_MASTER_PLAN.md`
- `docs/edge_fuel/HANDOFF.md`
- untracked `docs/SESSION_HANDOFF.md`

When code and documentation disagree, inspect the code and tests, then update
`CURRENT_HANDOFF.md`. Do not copy stale progress markers into a new plan.

## 7. Establish project rules and conventions

**Status: Established**

### Delivery rules

1. Work on one bounded slice at a time.
2. Inspect before editing; never assume an old handoff is current.
3. Preserve unrelated and untracked user work.
4. Format, analyze, test, review the diff, then commit.
5. Use focused, imperative Conventional Commit messages.
6. Never claim deployment or real-device success without evidence.

### Flutter rules

- Use Dart/Flutter for all mobile UI and client logic.
- Reuse the existing design tokens and widgets.
- Use at least 44 logical pixels for interactive targets.
- Add ellipsis/wrapping behavior for user-controlled or narrow text.
- Respect `MediaQuery.disableAnimationsOf(context)`.
- Avoid synchronous `ChangeNotifier` mutations during widget `initState`.
- Keep calculations and policies pure and unit tested.
- Do not add new state to `AppState` when a feature controller is appropriate.

### Security and health rules

- Never store API keys in Flutter, Git, Markdown, tests, Firestore, or Remote
  Config.
- Only trusted backend code may write billing/entitlement fields.
- Keep Firestore deny-by-default and owner-scoped.
- AI may explain approved facts; it may not generate health-critical targets.
- Never add dehydration, starvation, diuretic, laxative, purging, or rapid-cut
  protocols.
- Do not promote nutrition content from `draft` without named professional
  review.

## 8. Use AI where it adds leverage

**Status: Architecture established; deployment hardening incomplete**

Good AI uses:

- Explain a deterministic plan in plain language.
- Summarize already-recorded trends.
- Recommend only validated catalog recipes.
- Help developers write tests, review diffs, and identify edge cases.

Bad AI uses:

- Calculating calorie or macro targets.
- Changing safety-policy decisions.
- Inventing foods, nutrient values, recipe identifiers, or user history.
- Giving rapid weight-cut or dehydration instructions.
- Holding provider credentials in the mobile application.

Before public AI access:

- Confirm the previously exposed key is revoked.
- Store the replacement only in Firebase Secret Manager.
- Verify the callable deployment, quota, kill switch, and Pro gate.
- Add server-owned entitlement enforcement when RevenueCat is integrated.
- Add App Check before meaningful scale.

## 9. Build, test, and review

**Status: Current execution phase**

Required gate before every commit:

```powershell
& 'C:\src\flutter\bin\dart.bat' format .
& 'C:\src\flutter\bin\flutter.bat' analyze
& 'C:\src\flutter\bin\flutter.bat' test --no-pub
Set-Location functions
npm test
npm run build
```

For release-related changes, also run:

```powershell
& 'C:\src\flutter\bin\flutter.bat' build apk --debug
```

Test behavior, not merely line coverage:

- Unit tests for calculations, policies, parsing, entitlements, and migration.
- Widget tests for loading, empty, error, locked, and narrow-layout states.
- Flow tests for signup → onboarding → useful action → upgrade → sign-out.
- Real-device checks for Google Sign-In, haptics, keyboard behavior, offline
  logging, account deletion, and subscription restoration.
- Backend tests for validation, quotas, webhooks, and prohibited AI output.

### Immediate engineering queue

1. Add `functions/` build and tests to GitHub Actions.
2. Rebuild the Android APK after accepting the SDK license.
3. Integrate Crashlytics and verify one controlled non-release test event.
4. Replace legal placeholders and add the public deletion URL.
5. Add icon, splash, signing, and release configuration.
6. Verify Google Sign-In on a physical Android device.
7. Implement RevenueCat purchases plus a verified Cloud Function webhook.
8. Test purchase, restore, cancellation, expiry, and offline entitlement state.

## 10. Deploy and iterate

**Status: Not complete**

### Release sequence

1. Push current commits and make CI green.
2. Produce a signed internal Android build.
3. Configure Crashlytics and Firebase App Distribution.
4. Deploy required Functions and Firestore rules.
5. Configure Google Play subscriptions and RevenueCat.
6. Verify the complete billing lifecycle with test accounts.
7. Recruit 20–30 combat-sport beta users.
8. Observe at least ten onboarding sessions without coaching the user.
9. Fix the top three repeated problems.
10. Run Google Play closed testing and submit the production release.

### Metrics for iteration

- Onboarding completion rate.
- Percentage logging a first meal and first training session.
- Week-one return rate.
- Weekly athletes active in both Fuel and Camp.
- Trial start, trial-to-paid conversion, cancellation, and restore success.
- Crash-free users and failed callable-function rate.
- Qualitative answer to: “Would you be disappointed if Fighter Edge
  disappeared?”

After the first paid validation, build recurring Pro value in this order:

1. EF-4: connect Fuel guidance to training load.
2. EF-5: Weekly Fuel Review.
3. Reviewed meal plans and grocery lists.
4. Regular reviewed recipe releases.

## Current definition of done

The Android MVP is ready only when:

- Every visible control works.
- A fresh account contains no sample user data.
- The complete automated suite and Android release build pass.
- Legal, deletion, and health disclosures are public and linked in-app.
- Crash reports are observable.
- Google Sign-In works on a real Android device.
- A test purchase grants Pro through the server.
- Restore works, and cancellation/expiry removes Pro correctly.
- At least ten target users complete a week of real usage.

Until then, describe Fighter Edge as a strong private beta—not a finished
paid SaaS product.
