# Fighter Edge legal pages

Static, script-free pages served by Firebase Hosting on the existing project:

| Page | English | German |
|---|---|---|
| Privacy Policy | `/privacy` | `/de/datenschutz` |
| Terms of Use (EULA) | `/terms` | `/de/nutzungsbedingungen` |
| Account deletion (Google Play requirement) | `/delete-account` | `/de/konto-loeschen` |
| Ethical Guidelines | `/ethics` | `/de/ethik` |

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
- your supervisory authority;
- governing law and, if based in Germany, your § 36 VSBG statement;
- the AI-provider sentence, depending on whether you use free models.

`hosting/check-placeholders.sh` blocks `firebase deploy --only hosting` and
the release workflow while any placeholder remains.

## 2. Things the app must match

The policy describes what the app does. Keep them in step:

1. **Explicit consent (done in the app).** A consent screen before onboarding
   asks for body data, and another before the first AI request. The server
   refuses AI requests without it. Withdrawal is in Settings > Privacy. If
   the wording of either screen changes materially, raise the version in
   `lib/privacy/data_consent.dart` and `functions/src/consents.ts` so every
   account is asked again, and update section 2.2 or 2.3.
2. **Account deletion (done in the app).** It deletes the RevenueCat customer
   and removes the account ID from the billing ledger (audit D-9). This needs
   a real `REVENUECAT_API_KEY` once RevenueCat is live.
3. **Firebase Analytics data retention** set to 2 months (owner setting).
4. **Data processing agreements** signed with Google (Firebase), RevenueCat
   and OpenRouter (owner).

The Ethical Guidelines are promises about the product. Each one is kept by
code; change the page in the same pull request as the code:

| Promise (section) | Kept by |
|---|---|
| 0.5–1 kg a week in camp; food-only fight week; lightest safe limit (1) | `lib/features/fight_camp/domain/weight_cut_policy.dart`, `weight_path.dart`, `fight_week_plan.dart` |
| Never plans water cuts; "drink normally" (1) | `fight_week_plan.dart` (no fluid step exists), `fightWeekWater` string |
| No weight-cut plan under 18 (1) | `WeightCutPolicy.minimumAgeYears` |
| Safety never behind the paywall (1) | No `Feature` gate in `lib/features/fight_camp/` |
| Numbers calculated by the app, not AI (2, 3) | `lib/features/edge_fuel/domain/`; `functions/src/validate.ts` rejects numbers the app did not supply |
| Dangerous methods discarded (3) | `functions/src/validate.ts` `PROHIBITED_PATTERNS`, `systemPrompt.ts` |
| AI only with consent (3) | `lib/privacy/ai_coach_consent.dart`, `functions/src/consents.ts` |
| AI tested before a model change (3) | `npm run eval:ai` (`functions/src/aiEvalScenarios.ts`) |
| No selling, no ads today, Pro ad-free (5, 6) | Owner decision 2026-09-26; adding ads means updating section 6 here and the Privacy Policy |
| Licensed, credited recipe photos (7) | `lib/features/edge_fuel/data/recipe_photos.dart` |
| Tested at 200% text, screen readers, high contrast (8) | `test/accessibility/` |

The app opens this page from Settings at the Terms URL's site
(`TERMS_URL` with `/ethics`), so it needs no build variable of its own.

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
