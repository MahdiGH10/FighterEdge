# Deploying EdgeFuel AI (backend)

This is the part I can't do for you — enabling billing, setting secrets, and
deploying to your Firebase project are account-level actions. The backend
boundary, subscription webhook, entitlement gate, and tests are in the repo.
Follow these steps in order.

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

## 3. Set the subscription webhook secret

Run this in your own terminal and use the same value for the RevenueCat
webhook Authorization header:

```bash
firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTH
```

The app also needs the RevenueCat products and `pro` entitlement configured.
See `docs/BILLING_IMPLEMENTATION.md` for the dashboard checklist and sandbox
test matrix.

## 4. (Optional) Pick a different model

The default is `openai/gpt-4o-mini` (cheap, supports JSON mode). To use a
different OpenRouter model:
```bash
firebase functions:config:set openrouter.model="some/other-model"
```
Or set the `OPENROUTER_MODEL` environment variable in the Cloud Functions
console after first deploy. No code change needed either way.

### Using Groq instead of OpenRouter

The functions can talk to Groq (console.groq.com, free tier with per-model
limits). OpenRouter stays the default until you switch.

1. Create a key at console.groq.com/keys. Set it in your own terminal:
   ```bash
   firebase functions:secrets:set GROQ_API_KEY
   ```
   The functions declare this secret, so it must exist before any deploy.
   Until you use Groq, set it to the text `unset`.
2. Find out which models the key can use, then score them (both read
   `GROQ_API_KEY` from your shell and never print it):
   ```bash
   cd fighter_edge/functions
   npm run groq:models
   AI_PROVIDER=groq npm run eval:ai -- --models id1,id2,id3 --runs 2
   ```
3. Set `AI_PROVIDER=groq` and `GROQ_MODELS=best,second,third` (best first)
   as environment variables for the functions. A model that is busy (429),
   retired or unsupported (400) or down (5xx) hands over to the next one.
4. **Before real users:** the consent text and both privacy pages name
   OpenRouter as the processor. Update them to name Groq and bump the
   version in `data_consent.dart` and `consents.ts`. Check Groq's own
   data-retention terms first; the OpenRouter no-retention switch
   (`OPENROUTER_DATA_COLLECTION`) does not apply to Groq.

## 5. Deploy

```bash
cd fighter_edge
firebase deploy --only functions,firestore:rules
```

The predeploy hook runs `npm run build` (TypeScript compile) automatically.

## 6. Verify

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
- One transactional daily quota (20 requests/user/day). Premium AI tasks are
  authorized against `users/{uid}.plan == 'pro'` before consuming quota.
- Three backend task names: plan explanation, premium Fighter Brief, and
  trend summarization. The existing screen still exposes the plan explanation;
  the full Fighter Brief response sections are the next UI slice.
- No recipe/meal-plan/grocery actions — those need the recipe catalog (EF-3)
  to validate against first.

Follow-up hardening before a public launch: App Check, response caching,
cost dashboards, and explicit Fighter Brief analytics. These are deployment
and EF-7 follow-ups, not reasons to bypass the current trust boundary.
