## What and why

<!-- One bounded slice: what changed and the problem it solves. -->

## How it was verified

- [ ] `dart format --output=none --set-exit-if-changed .`
- [ ] `flutter analyze --fatal-infos`
- [ ] `flutter test --exclude-tags golden --coverage` (coverage floor holds)
- [ ] Golden tests (CI, Windows renderer) if UI changed
- [ ] `functions/`: `npm test` (and `npm run test:rules` if rules changed)
- [ ] Tested on a device / simulator / store sandbox (say which), or "not
      device-tested"

## Product and trust checklist

- [ ] No secrets, receipts, emails, UIDs, prompts, meal text or measurements
      in code, logs, telemetry or docs
- [ ] The client does not grant or persist Pro; entitlement stays server-owned
- [ ] `features/edge_fuel/domain/` stays pure Dart
- [ ] User-facing strings are in ARB (EN + DE)
- [ ] Handoff (`fighter_edge/docs/CLAUDE_CODE_HANDOFF.md`) updated if the
      repository state changed
