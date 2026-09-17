# Release Quality and Test Strategy

## Quality gates

Every phase must pass:

```text
dart format --set-exit-if-changed .
flutter analyze
flutter test
cd functions && npm test && npm run build
```

## Current validation snapshot

The latest hardening pass is green in the local Flutter and Functions suites:

- `flutter analyze`: clean
- `dart format --set-exit-if-changed .`: clean
- `flutter test`: 267 tests passed
- `functions/npm test`: 10 tests passed
- `functions/npm run build`: clean

Two device-level checks still require machine setup and cannot be faked by a
headless test:

- Windows integration tests need Developer Mode enabled for Flutter plugin
  symlinks, then run `flutter test integration_test/app_flow_test.dart -d windows`.
- Android builds need the configured SDK licenses accepted (including the NDK
  version selected by the project), then run `flutter build apk --debug` before
  attempting a signed release build.

Release builds must also be verified on a physical Android device and later on
iOS TestFlight. A passing widget suite is not a substitute for store builds.

## Test layers

### Unit tests

- target calculator and safety policy;
- Fighter Brief preview rules and boundaries;
- nutrition totals and date isolation;
- entitlement and quota decisions;
- JSON parsing and schema-version compatibility;
- AI response validation and unsafe output rejection;
- subscription state transitions and restore behavior.

### Widget tests

- free preview renders with no target, no entries, partial entries, and an
  over-target day;
- Pro CTA routes to the correct paywall feature;
- loading, unavailable, quota, professional-review, and retry states;
- large text and narrow width do not overflow;
- screen-reader labels identify actions and locked content;
- quick-add meals persist through the visible UI.

### Flow and integration tests

- new account -> onboarding -> target -> first meal -> preview;
- preview -> paywall -> restore purchase;
- Pro entitlement -> full brief -> quota reached;
- sign out -> second account starts clean;
- account deletion removes user-owned data;
- Firestore rules deny cross-user reads and client entitlement writes;
- Cloud Function validates auth, quota, schema, and safety flags.

### Performance tests

- cold start and first frame on a mid-range Android device;
- dashboard rebuilds when logging one meal, not the whole navigation tree;
- recipe list scrolling at 60fps with large catalogs;
- AI request timeout and cancellation do not block the UI;
- memory remains stable after repeated navigation between Fuel and recipes;
- Firestore listeners are cancelled when user/session changes.

### Release and security tests

- signed Android App Bundle installs and upgrades over the previous build;
- Firebase production configuration is separate from local fallback;
- no provider key exists in Flutter assets, logs, or compiled client config;
- Crashlytics receives a controlled test crash;
- privacy policy, terms, deletion URL, Health declaration, and store data
  disclosures match the shipped behavior;
- subscription purchase, renewal, cancellation, refund, grace period, and
  restore all reconcile from the trusted billing provider.

## Test data rules

Use synthetic users only. Never place real body measurements, health notes,
meal names, email addresses, or secrets in fixtures, snapshots, logs, or
analytics.

## Definition of ship-ready

- zero analyzer errors and zero test failures;
- no known P0/P1 crash or data-isolation issue;
- Android release AAB verified on a physical device;
- iOS archive verified through TestFlight;
- all paid flows tested with store sandbox accounts;
- rollback/build-version procedure documented;
- support contact and user deletion path are live.
