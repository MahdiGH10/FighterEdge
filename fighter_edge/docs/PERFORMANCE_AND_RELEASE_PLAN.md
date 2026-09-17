# Performance and release hardening plan

This document turns “optimize the app” into measurable gates. A change is not
called an optimization until the before/after behavior is measured on the same
device class and the relevant tests remain green.

## Current implementation

- RevenueCat SDK access is isolated behind `BillingGateway`; tests use a
  deterministic fake and builds without public store keys use a safe unavailable
  adapter.
- Store purchases never grant Pro locally. Firestore is updated only by the
  authenticated RevenueCat webhook, and the client polls briefly for the server
  mirror after a purchase or restore.
- Premium AI calls are entitlement-checked before quota consumption.
- AI requests have a 20-second client timeout and controller failures resolve to
  a retryable unavailable state instead of leaving a spinner mounted forever.
- The app keeps only the active navigation content mounted in the main shell;
  this is the current rebuild/repaint optimization baseline.

## Phase P1 — measure on Android

Run on a mid-range Android emulator and one physical low-end device in profile
mode. Capture the same flows before and after each change:

```text
flutter run --profile -d <android-device>
flutter drive --profile -d <android-device> \
  --target=integration_test/performance_smoke_test.dart
flutter build apk --analyze-size --release
```

Record:

- time to first branded frame and time to interactive login;
- average and 99th-percentile build/raster frame time while opening Dashboard,
  Fuel, Recipes, and Paywall;
- peak resident memory after ten Dashboard ↔ Fuel ↔ Recipes navigations;
- APK size and the largest five assets/dependencies;
- Firestore reads and callable latency for the first Fuel screen.

Target budgets:

| Surface | Budget |
| --- | ---: |
| First branded frame | < 500 ms on profile device |
| Interactive Dashboard | < 2.5 s warm, < 4 s cold |
| Steady-state frame build/raster | < 16 ms at p95 |
| AI timeout | 20 s hard ceiling, recoverable UI |
| Navigation memory growth | < 10 MB after ten repetitions |

## Phase P2 — Flutter rebuild and memory audit

1. Use DevTools frame chart and rebuild tracker on Dashboard and Fuel.
2. Replace broad `context.watch` calls with `Selector` where a card only needs
   one field; never optimize before a rebuild count is recorded.
3. Keep repositories/controllers scoped to the authenticated session and cancel
   Firestore streams on sign-out or date changes.
4. Bound recipe lists with pagination/limited search results before adding more
   catalog content.
5. Keep blur, gradients, and animated effects bounded to the smallest painted
   region; profile raster time before adding any new effect.
6. Re-run accessibility tests at 200% text after every layout optimization.

## Phase P3 — backend latency and cost controls

- Keep OpenRouter timeout at 15 seconds server-side and 20 seconds client-side.
- Keep prompt/context payloads to calculated facts only; never send raw account
  identity or unnecessary history.
- Keep quota consumption transactional and before the model request.
- Add structured latency logs (`task`, `model`, `durationMs`, `status`) without
  logging nutrition PII or model prompts.
- Add a bounded response size and reject malformed/safety-violating JSON before
  returning it to Flutter.
- Review Firestore indexes and callable read count after the first staging load
  test.

## Phase P4 — release matrix

Before store submission:

1. `dart format --set-exit-if-changed .`
2. `flutter analyze`
3. `flutter test`
4. `cd functions && npm test && npm run build`
5. Enable Windows Developer Mode and run the integration journey locally.
6. Accept Android SDK/NDK licenses and build a release APK/AAB.
7. Test RevenueCat sandbox: initial purchase, renewal, cancellation, restore,
   grace/billing issue, expiration, refund, and cross-device login.
8. Verify webhook replay is idempotent and stale events cannot downgrade a
   newer entitlement.
9. Verify a modified client cannot write `plan`, `billing`, or `entitlement`.
10. Run Play closed testing, then iOS TestFlight with the same account matrix.

## Test ownership

- Unit: billing event mapping, quota ordering, AI schema/safety, calculators.
- Widget: paywall loading/unavailable/purchase-pending/Pro states, large text,
  restore and cancellation actions.
- Flow: signup → onboarding → target → meal → preview → paywall.
- Integration: real store sandbox and webhook-driven entitlement activation.
- Performance: profile-device frame/memory/size budgets above.
- Release/security: rules emulator, signed builds, secrets scan, deletion and
  privacy flows.

No production release is “ready” while a device build, store sandbox, or
server-authoritative entitlement test is unverified.
