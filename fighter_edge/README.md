# Fighter Edge Flutter package

This directory contains the Flutter application. Start with the repository
guide at [`../README.md`](../README.md), then read
[`docs/CLAUDE_CODE_HANDOFF.md`](docs/CLAUDE_CODE_HANDOFF.md) for the verified
implementation state.

## Run locally

```powershell
flutter pub get
flutter run -d chrome
```

## Verify changes

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --exclude-tags golden --coverage --reporter compact
flutter test --tags golden --reporter compact
```

The Firebase Cloud Functions backend has its own package and checks:

```powershell
cd functions
npm ci
npm test
```

Production setup, payments, Firebase secrets, and release requirements are
documented in the repository-level README and `docs/` handoffs. Do not add
provider secrets to this package or commit generated build/coverage output.
