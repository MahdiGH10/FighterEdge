# Fighter Edge legal pages

Static, script-free pages served by Firebase Hosting on the existing project:

| Page | English | German |
|---|---|---|
| Privacy Policy | `/privacy` | `/de/datenschutz` |
| Terms of Use (EULA) | `/terms` | `/de/nutzungsbedingungen` |
| Account deletion (Google Play requirement) | `/delete-account` | `/de/konto-loeschen` |

They were drafted from the app's actual data flows (see `AUDIT.md`), so they
say what the app really does, including the parts that are uncomfortable
(US processing for AI and billing, and data retention by free AI models).

> **These are drafts, not legal advice.** They process health data under the
> GDPR, so have a lawyer or data-protection professional review them before
> publishing, especially sections 2.2, 2.3, 4 and 5 of the privacy policy and
> sections 11 and 13 of the terms.

## 1. Fill in every placeholder

Every `TODO(owner)` is highlighted on the page. List them with:

```sh
grep -rn "TODO(owner)" fighter_edge/hosting/public
```

You need to provide:

- your legal name or company, legal form, and postal address;
- a privacy/support email (ideally a dedicated address, not a personal one);
- the effective date;
- if you are not established in the EU, an EU representative (Art. 27 GDPR);
- the Firestore location (Firebase console > Firestore > Settings);
- the billing-record retention period and your supervisory authority;
- governing law and, if based in Germany, your § 36 VSBG statement;
- the AI-provider sentence, depending on whether you use free models.

`hosting/check-placeholders.sh` blocks `firebase deploy --only hosting` and
the release workflow while any placeholder remains.

## 2. Things the app must match (engineering follow-ups)

The policy is only accurate once these are true:

1. **Explicit consent for health data** (Art. 9 GDPR): add a consent step
   before onboarding asks for weight and body data, and before the AI coach is
   first used.
2. **Account deletion** also deletes or anonymises the RevenueCat customer
   and billing-event records (audit D-9), or the policy states the retention.
3. **Firebase Analytics data retention** set to 2 months.
4. **Data processing agreements** signed with Google (Firebase), RevenueCat
   and OpenRouter.

## 3. Publish

```sh
cd fighter_edge
firebase deploy --only hosting --project fighter-edge-app
```

Pages are served at `https://fighter-edge-app.web.app/...` (or attach your own
domain in Firebase Hosting and use that instead).

## 4. Point the app and the stores at them

- GitHub > Settings > Environments > `production` > variables:
  `TERMS_URL=https://fighter-edge-app.web.app/terms`,
  `PRIVACY_URL=https://fighter-edge-app.web.app/privacy`.
  Release builds embed them (the paywall, signup and Settings open them).
- App Store Connect: set the Privacy Policy URL, and set the License
  Agreement to the custom EULA (the Terms URL) or keep Apple's standard EULA
  and link the Terms in the description.
- Google Play Console: set the Privacy Policy URL, and set the account
  deletion URL to `https://fighter-edge-app.web.app/delete-account`.
