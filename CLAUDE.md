# Fighter Edge agent instructions

Fighter Edge is a Dart/Flutter mobile application with Firebase Cloud
Functions in `fighter_edge/functions/`. JavaScript/TypeScript is backend-only;
the product UI must remain Flutter.

## Start here

1. Inspect `git status --short` and the current branch before editing.
2. Read `fighter_edge/docs/CLAUDE_CODE_HANDOFF.md` for verified state.
3. Read the relevant product/design document for the slice you are changing.
4. Keep one bounded slice per session: implement, test, commit, then reassess.

## Non-negotiable rules

- Keep `fighter_edge/lib/features/edge_fuel/domain/` pure Dart with no Flutter,
  Firebase, network, platform, or clock imports.
- Deterministic nutrition calculations are authoritative. AI only explains or
  prioritizes trusted facts and must pass schema/safety validation.
- RevenueCat plus the trusted Firebase webhook own entitlements. The client
  never grants or persists Pro access.
- Do not log or commit secrets, prompts, measurements, meal text, email
  addresses, Firebase UIDs, receipt tokens, or clinical narratives.
- Reuse the design tokens and motion/accessibility helpers already in the app.
- Preserve unrelated user/audit artifacts in the working tree.

## Verification

From `fighter_edge/`:

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --exclude-tags golden --coverage --reporter compact
flutter test --tags golden --reporter compact
```

From `fighter_edge/functions/`:

```powershell
npm ci
npm test
```

Never claim store, Firebase secret, webhook, signing, or sandbox readiness
unless it was actually configured and tested. Update the handoff when the
repository state changes.
