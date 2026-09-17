# Production store, analytics, and observability setup

This document is the release checklist for the hosted Fighter Edge services.
The Flutter app contains the provider boundaries and safe event names; the
Firebase and store consoles still need to be connected to the production
accounts before a real purchase can be activated.

## What is implemented in code

- RevenueCat product IDs are `fighter_edge_pro_monthly` and
  `fighter_edge_pro_annual`.
- The entitlement name expected by the client and webhook is `pro`.
- RevenueCat remains the store receipt authority. The app never turns a
  client purchase result into a Pro entitlement by itself.
- `revenueCatWebhook` verifies an Authorization header, ignores test/transfer
  events, is idempotent, and applies events in timestamp order.
- Flutter custom analytics are allow-listed in `lib/observability/telemetry.dart`.
  Events contain only product signals such as surface, billing period, task,
  access tier, and result status. They must never contain measurements,
  calories, meal text, prompts, email addresses, or Firebase UIDs.
- Crashlytics catches Flutter and uncaught async errors on Android/iOS. Error
  reporting is best-effort and never blocks sign-in, billing, or nutrition.
- Functions emit structured Cloud Logging events for AI lifecycle, quota
  blocks, rejected model output, and subscription webhook lifecycle.

## Firebase secrets

Never put secret values in git, Markdown, CI logs, or chat. The current project
has `OPENROUTER_API_KEY` provisioned. `REVENUECAT_WEBHOOK_AUTH` still needs to
be created before the webhook can be deployed.

From an authenticated Firebase CLI session, create it interactively:

```powershell
firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTH --project fighter-edge-app
```

Use a long random value. The same value is configured in RevenueCat as the
webhook's `Authorization` header (including the `Bearer ` prefix if that is
the value you choose). Do not print the value after creation.

Confirm only secret *names* with Google Cloud:

```powershell
gcloud secrets list --project=fighter-edge-app --format="value(name)"
```

## RevenueCat products

1. In RevenueCat, select the Fighter Edge production project.
2. Create an App Store product and a Play product with the exact product IDs
   above. Use the same entitlement identifier, `pro`, for both stores.
3. Attach both products to the `pro` entitlement and configure monthly and
   annual pricing in each store's own console.
4. Add a RevenueCat webhook pointing to the deployed Firebase URL:

   `https://us-central1-fighter-edge-app.cloudfunctions.net/revenueCatWebhook`

5. Send the Authorization header configured from `REVENUECAT_WEBHOOK_AUTH`.
6. Enable the events used by the handler: initial purchase, renewal, product
   change, cancellation, billing issue, expiration, refund reversed, and test.
7. Send RevenueCat's test webhook. It should return HTTP 200 with `ignored` and
   must not grant an account Pro access.

The Flutter client also needs the two **public** RevenueCat SDK keys at build
time (these are not the webhook secret):

```powershell
flutter build apk --release `
  --dart-define=REVENUECAT_ANDROID_PUBLIC_KEY=your_public_android_key

flutter build ipa --release `
  --dart-define=REVENUECAT_IOS_PUBLIC_KEY=your_public_ios_key
```

Use CI/release secret variables for those values; never commit them to Dart or
put them in a public issue. A build without the matching platform key correctly
shows the waitlist/restore-status state instead of pretending payments are
active.

## Deploy

After the webhook secret exists:

```powershell
firebase deploy --only functions,firestore:rules --project fighter-edge-app
```

If the secret is not ready yet, it is safe to deploy only the existing AI and
account functions plus rules, but the RevenueCat endpoint will remain absent:

```powershell
firebase deploy --only functions:edgeFuelAiExplain,functions:deleteAccount,firestore:rules --project fighter-edge-app
```

Check the deployed function names without reading secret values:

```powershell
firebase functions:list --project fighter-edge-app
```

## Sandbox subscription test matrix

Real store transactions require store accounts and a physical/emulated device;
they cannot be completed from Windows CI.

### Android (Google Play internal testing)

1. Create the two products in Play Console and publish them to an internal
   testing track.
2. Add a license tester account and install the signed internal-test build.
3. Sign in to Fighter Edge with a Firebase account whose UID is the RevenueCat
   app user ID.
4. Buy monthly and annual products separately. Verify the app first shows a
   pending sync, then Firestore `users/{uid}.plan == "pro"` after the webhook.
5. Restore purchases, cancel renewal, and let the entitlement remain active
   until expiration. Verify expiration changes the plan to `free`.

### iOS (Sandbox/TestFlight)

1. Create the products and subscription group in App Store Connect.
2. Create a Sandbox tester and install a development/TestFlight build on an
   iOS device. iOS purchase testing is not supported on this Windows runner.
3. Repeat purchase, restore, cancellation, and expiration checks. Confirm that
   deleting the Firebase account does not leave a writable entitlement profile.

Record each run with store, build number, product ID, webhook event ID, and
result status. Never record receipt tokens or personal data in issue trackers.

## Release dashboards

- Firebase Analytics: create funnels for `paywall_viewed` →
  `subscription_checkout_started` → `subscription_purchase_result`.
- Crashlytics: monitor crash-free users, fatal/non-fatal errors, and release
  versions. Do not add user identifiers or health values as custom keys.
- Cloud Logging: create alerts for repeated `openrouter_call_failed`,
  `ai_response_rejected`, and `revenuecat_webhook_failed` events.
- RevenueCat: monitor active subscribers, webhook delivery failures, and
  entitlement state. Treat RevenueCat and Firestore as the source of truth;
  client analytics are for conversion analysis only.
