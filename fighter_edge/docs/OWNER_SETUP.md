# Owner setup: secrets, legal pages, automatic deploys

Only the account owner can do these steps, because they need your Firebase,
RevenueCat, Google Cloud and GitHub logins. Commands run from the
`fighter_edge/` folder unless a step says otherwise. The Firebase project is
`fighter-edge-app` and the functions run in `us-central1`.

Never paste a key, password or secret into chat, git, a GitHub comment or a
document. The commands below ask for secret values at a hidden prompt.

## 1. RevenueCat secret key, then deploy the backend

Do this after PR #6 is merged, from an up-to-date `main`.

**1.1 Get the value.**

- **No RevenueCat account yet:** the value is the word `unset`. Pro still
  works from webhooks; instant sync, transfers and reconciliation switch on
  once you replace it with a real key.
- **RevenueCat account exists:** RevenueCat dashboard > your project >
  **API keys** > **+ New secret API key**. Name it `firebase-functions`. If it
  asks for an API version, choose **V1** (the functions read
  `GET /v1/subscribers`). Copy the key; it starts with `sk_`.

**1.2 Store it in Firebase.**

```sh
firebase login
firebase functions:secrets:set REVENUECAT_API_KEY --project fighter-edge-app
```

Paste the value at the hidden prompt. Check that the three secrets the
functions need exist (this lists versions, never values):

```sh
firebase functions:secrets:get OPENROUTER_API_KEY --project fighter-edge-app
firebase functions:secrets:get REVENUECAT_WEBHOOK_AUTH --project fighter-edge-app
firebase functions:secrets:get REVENUECAT_API_KEY --project fighter-edge-app
```

**1.3 Deploy.**

```sh
git checkout main && git pull
npm --prefix functions ci
firebase functions:artifacts:setpolicy --location us-central1 --project fighter-edge-app
firebase deploy --only functions,firestore:rules,firestore:indexes --project fighter-edge-app
```

The `setpolicy` line is one-time: it deletes old build images so they don't
cost storage, and it stops later automatic deploys from failing on that
question. Accept the default.

**1.4 Check it worked.**

- `firebase functions:list --project fighter-edge-app` shows
  `syncEntitlement` and `reconcileEntitlements` next to the existing
  functions.
- Firebase console > Firestore > **Indexes**: the `users` index
  (`plan`, `billing.expiresAtMs`) turns from "Building" to "Enabled" within
  a few minutes.
- Google Cloud console > **Cloud Scheduler** shows a job for
  `reconcileEntitlements`, every 6 hours.

**Deadline:** deploy before **2026-10-30**. That is when Node 20 functions
stop being supported, and this deploy moves them to Node 22.

## 2. Legal pages

The drafts are in `hosting/public/`: Privacy Policy, Terms and account
deletion, in English and German. Every fact only you know is marked
`TODO(owner)` and highlighted on the page. List them with:

```sh
grep -rn "TODO(owner)" hosting/public
```

**2.1 Facts only you can give.** Either edit the pages yourself, or send
these to Claude and it fills them in:

| # | What | Example |
|---|---|---|
| 1 | Your full name or company name, and legal form | "Jane Doe (sole trader)" or "Example GmbH" |
| 2 | Postal address | This is published on the pages |
| 3 | Contact email for privacy and support | Use a dedicated address such as `privacy@yourdomain`, not a personal one. It is published and stored in git. |
| 4 | Country you are based in | Decides the EU representative, the supervisory authority, the governing law and the German § 36 VSBG statement |
| 5 | Developer name exactly as shown in the stores | |
| 6 | Effective date | The day you publish |
| 7 | Firestore location | Firebase console > Firestore > the database's **Location** field, for example `eur3` or `nam5` |
| 8 | Whether the AI coach stays on free models | Free models may keep prompts; the pages say so while that is true. If you switch, the in-app AI consent text changes too. |

**2.2 Settings to change** (the pages promise these):

- Google Analytics (from Firebase console > Analytics) > **Admin** > **Data
  collection and modification** > **Data retention**: set event data to
  **2 months**.
- Accept each provider's data-processing terms: Firebase and Google
  Analytics (Firebase console > Project settings, "Data Processing Terms"),
  RevenueCat and OpenRouter (their DPA pages).

**2.3 Already handled in the app.** The pages promise two things the app now
does:

- It asks for explicit consent before collecting health data (Art. 9 GDPR),
  and before the AI coach sends anything to the AI provider. Both can be
  withdrawn in Settings > Privacy.
- Deleting an account also deletes the RevenueCat customer and unlinks the
  billing history (audit D-9). This needs a real `REVENUECAT_API_KEY` once
  RevenueCat is live; with `unset`, deletion can't reach RevenueCat.

**2.4 Legal review.** The pages handle health data under the GDPR, so have a
lawyer or a data-protection service review them before launch. They are
drafts, not legal advice.

**2.5 Publish.** The deploy refuses while any `TODO(owner)` is left.

```sh
firebase deploy --only hosting --project fighter-edge-app
```

Or, after step 3: GitHub > **Actions** > **Deploy backend** > **Run
workflow** > targets **hosting**.

The pages are then at:

- `https://fighter-edge-app.web.app/privacy`
- `https://fighter-edge-app.web.app/terms`
- `https://fighter-edge-app.web.app/delete-account`
- German: `/de/datenschutz`, `/de/nutzungsbedingungen`, `/de/konto-loeschen`

**2.6 Point the app and the stores at them.**

- GitHub > repository **Settings** > **Environments** > `production` >
  **Environment variables**:
  - `TERMS_URL` = `https://fighter-edge-app.web.app/terms`
  - `PRIVACY_URL` = `https://fighter-edge-app.web.app/privacy`

  Release builds embed these. Without them the release workflow stops.
- App Store Connect: set the Privacy Policy URL. For the License Agreement,
  use the Terms URL as a custom EULA, or keep Apple's standard EULA and
  link the Terms in the app description.
- Google Play Console: set the Privacy Policy URL, and set **Data deletion**
  > the account-deletion URL to
  `https://fighter-edge-app.web.app/delete-account`.

## 3. Automatic backend deploys (optional)

After this, every merge to `main` that changes the backend runs the tests
and then deploys, once you approve it. It uses keyless Workload Identity
Federation: GitHub proves who it is to Google, so no key is stored anywhere.

**3.1 Protect the `production` environment first.** GitHub > **Settings** >
**Environments** > `production` (create it if missing):

- **Required reviewers:** add yourself. Every deploy and release then waits
  for your click.
- **Deployment branches and tags:** "Selected branches and tags", add `main`
  and the tag pattern `v*.*.*` (used by the release workflow).

**3.2 Create the Google Cloud side.** Open the Google Cloud console for
project `fighter-edge-app`, click **Activate Cloud Shell** (the `>_` icon,
top right), and paste this whole block:

```sh
PROJECT_ID=fighter-edge-app
REPO=MahdiGH10/FighterEdge
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
SA="github-deployer@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud services enable iamcredentials.googleapis.com sts.googleapis.com \
  --project="$PROJECT_ID"

gcloud iam workload-identity-pools create github \
  --project="$PROJECT_ID" --location=global \
  --display-name="GitHub Actions"

gcloud iam workload-identity-pools providers create-oidc fighteredge \
  --project="$PROJECT_ID" --location=global \
  --workload-identity-pool=github \
  --display-name="FighterEdge repository" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository == '${REPO}'"

gcloud iam service-accounts create github-deployer \
  --project="$PROJECT_ID" --display-name="GitHub deploys"

# Only jobs running in the protected `production` environment of this
# repository may act as the deployer.
gcloud iam service-accounts add-iam-policy-binding "$SA" \
  --project="$PROJECT_ID" \
  --role=roles/iam.workloadIdentityUser \
  --member="principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github/subject/repo:${REPO}:environment:production"

for role in \
  roles/firebase.admin \
  roles/cloudfunctions.admin \
  roles/run.admin \
  roles/cloudscheduler.admin \
  roles/artifactregistry.admin \
  roles/secretmanager.viewer \
  roles/iam.serviceAccountUser \
  roles/serviceusage.serviceUsageConsumer; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SA}" --role="$role" --condition=None --quiet >/dev/null
done

echo "GCP_WORKLOAD_IDENTITY_PROVIDER = projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github/providers/fighteredge"
echo "GCP_SERVICE_ACCOUNT = ${SA}"
```

The last two lines print the two values for the next step. Neither is a
secret.

**3.3 Tell GitHub.** GitHub > **Settings** > **Secrets and variables** >
**Actions** > **Variables** tab > **New repository variable**, twice, with
the names and values printed above.

**3.4 Test it.** Wait about five minutes for Google to apply the new
permissions, then go to GitHub > **Actions** > **Deploy backend** > **Run
workflow** > branch `main`, targets `backend`. Approve the deployment when
GitHub asks. The run should end green.

If it fails with "Permission denied" or "does not have permission", the
error names the missing permission. Add the matching role in Cloud Console >
**IAM** to `github-deployer`, then run it again.

Don't use the `FIREBASE_SERVICE_ACCOUNT` key fallback unless Workload
Identity Federation is impossible for you. A stored key can leak; the setup
above has no key.
