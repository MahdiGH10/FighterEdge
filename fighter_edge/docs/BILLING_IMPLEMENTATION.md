# Billing implementation handoff

Fighter Edge uses RevenueCat for store receipt handling and Firebase as the
server-owned entitlement mirror. The Flutter client can start or restore a
purchase, but it cannot write `plan`, `billing`, or `entitlement`.

## RevenueCat dashboard setup

1. Create Android and iOS apps in one RevenueCat project.
2. Add the store products:
   - `fighter_edge_pro_monthly`
   - `fighter_edge_pro_annual`
3. Create the entitlement with identifier `pro` and attach both products.
4. Create a current offering with monthly and annual packages.
5. Configure a webhook integration for:
   `https://<region>-<project>.cloudfunctions.net/revenueCatWebhook`.
6. Set the webhook Authorization header to the same value stored in the
   `REVENUECAT_WEBHOOK_AUTH` Firebase secret.
7. Enable at least `INITIAL_PURCHASE`, `RENEWAL`, `PRODUCT_CHANGE`,
   `UNCANCELLATION`, `CANCELLATION`, `BILLING_ISSUE`, `EXPIRATION`, and
   `REFUND_REVERSED` events.

RevenueCat must receive the Firebase UID as its `appUserID`. Anonymous or
arbitrary IDs are never allowed to create a Fighter Edge entitlement profile.

## Firebase setup

```text
firebase functions:secrets:set OPENROUTER_API_KEY
firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTH
firebase deploy --only functions
```

Run the mobile app with the public store keys (never the RevenueCat secret or
OpenRouter key):

```text
flutter run \
  --dart-define=REVENUECAT_ANDROID_PUBLIC_KEY=public_android_key \
  --dart-define=REVENUECAT_IOS_PUBLIC_KEY=public_ios_key
```

Without those defines, the app deliberately renders the free/waitlist state.
That is expected for local development and tests.

## State machine

| Store event | App access |
| --- | --- |
| Initial purchase / renewal / product change | Pro, until `expiration_at_ms` |
| Cancellation / billing issue / paused | Pro until expiration; `willRenew=false` |
| Uncancellation / extension / refund reversed | Pro, until expiration |
| Expiration | Free immediately |
| Test / transfer / unknown user | Acknowledge without granting access |

Webhook events are idempotent by provider event ID and ordered by event
timestamp. A delayed cancellation cannot overwrite a newer renewal. A purchase
receipt is shown as “syncing” until Firestore confirms `plan: pro`.

## Required sandbox matrix

- monthly initial purchase;
- annual initial purchase;
- restore after reinstall and after signing in on a second device;
- renewal;
- cancellation before expiry and access after expiry;
- billing issue/grace period;
- expiration and refund/reversal;
- webhook replay and out-of-order delivery;
- client attempt to write billing fields (must be denied by rules).

Do not ship paid access until every case passes on both Google Play closed
testing and App Store TestFlight sandbox accounts.
