# Deploying EdgeFuel AI (backend)

This is the part I can't do for you — enabling billing and setting a secret
are account-level actions. Everything else (code) is already built and
tested. Follow these steps in order.

## 1. Upgrade the Firebase project to Blaze

Cloud Functions require the Blaze (pay-as-you-go) plan, even to stay within
the free tier. Requires a billing card on file.

1. Go to https://console.firebase.google.com/project/fighter-edge-app/usage/details
2. Click "Modify plan" → select Blaze.
3. Optional but recommended: set a budget alert (e.g. $5/month) at
   https://console.cloud.google.com/billing/budgets so you're notified long
   before the free tier's limits are ever approached.

## 2. Rotate the exposed key, then set it as a secret

Do this in your own terminal — never paste the key into a chat with an AI
assistant, a commit, or any file in this repo.

1. Revoke the old key and create a new one at https://openrouter.ai/keys
2. From `fighter_edge/`, run:
   ```bash
   firebase functions:secrets:set OPENROUTER_API_KEY
   ```
   It will prompt you to paste the key — that's the only place it should
   ever be typed.

## 3. (Optional) Pick a different model

The default is `openai/gpt-4o-mini` (cheap, supports JSON mode). To use a
different OpenRouter model:
```bash
firebase functions:config:set openrouter.model="some/other-model"
```
Or set the `OPENROUTER_MODEL` environment variable in the Cloud Functions
console after first deploy. No code change needed either way.

## 4. Deploy

```bash
cd fighter_edge
firebase deploy --only functions,firestore:rules
```

The predeploy hook runs `npm run build` (TypeScript compile) automatically.

## 5. Verify

- In the app, open Fuel → your Plan → "Ask EdgeFuel Coach". You should get a
  plain-language explanation within a few seconds.
- Check Cloud Functions logs in the Firebase console if it shows "AI
  unavailable" — the function logs a reason (`openrouter_call_failed` or
  `ai_response_rejected`) without ever logging health/PII text.
- To confirm the kill switch works: create a Firestore document at
  `config/edgeFuelAi` with field `enabled: false` (boolean). The app should
  immediately start showing "unavailable" for new requests, with no
  redeploy needed. Delete the doc (or set it back to `true`) to re-enable.

## What ships in this pass vs. what's deferred

Per your "Fast MVP" choice, this deploy has:

- Firebase-authenticated calls only (no App Check yet).
- One shared daily quota (20 requests/user/day) — no Pro-only gating, since
  there's no server-owned entitlement system yet.
- Only two AI tasks: explaining the already-calculated plan, and (wiring
  exists, UI doesn't yet) summarizing a trend. No recipe/meal-plan/grocery
  actions — those need the recipe catalog (EF-3) to validate against first.

Follow-up hardening (do this before a public launch, not before a personal
test): App Check, real Pro-entitlement gating, response caching, cost
dashboards. These are EF-7 territory per the master prompt, not blockers for
you trying this yourself first.
