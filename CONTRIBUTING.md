# Contributing to Fighter Edge

Fighter Edge is developed as a small, safety-sensitive product. Every change
should improve the athlete's daily loop without weakening privacy, billing
trust, or the deterministic nutrition engine.

## Before you change code

1. Read the current [engineering handoff](fighter_edge/docs/CLAUDE_CODE_HANDOFF.md).
2. Run `git status --short` and preserve unrelated local/audit artifacts.
3. Choose one bounded engineering slice. Record larger ideas in
   `fighter_edge/docs/LATER.md` instead of expanding the slice.
4. For UI changes, follow the local `fighter-edge-ui` design contract and the
   tokens already used by the app.

## Implementation standards

- Prefer existing repository, controller, routing, and design-token patterns.
- Keep domain logic pure and add unit tests for edge cases and safety rules.
- Add widget tests for user-visible states and interaction paths.
- Never move provider secrets, AI keys, receipts, or entitlement authority into
  the Flutter client.
- Do not log personal data, nutrition measurements, prompts, meal text, or
  receipt identifiers.
- Do not change Firestore billing fields from a client write.
- Keep copy honest: distinguish a local preview, a configured store product,
  and a server-confirmed entitlement.

## Required checks

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

If a check cannot run locally, explain why in the handoff/PR and do not hide
the failure. Update documentation when behavior, setup, or release status
changes.

## Commit and pull-request practice

Use a short imperative commit subject, for example:

```text
feat: show annual Pro value on plan reveal
fix: reject stale entitlement updates
test: cover verification blocking state
docs: refresh release handoff
```

Each commit should represent one coherent slice and include its tests. Do not
commit generated coverage/build output, `.env` files, Firebase credentials,
store keys, or local tooling directories. Push only after the checks pass and
the user has asked to publish the commits.
