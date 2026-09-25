# Owner setup guide

These steps need your own logins (Firebase, RevenueCat, Google Cloud and
GitHub), so only you can do them. Run the commands from the `fighter_edge/`
folder unless a step says otherwise.

- Firebase project: `fighter-edge-app`
- Cloud Functions region: `us-central1`

**Never paste a key, password or secret into a chat, a git commit, a GitHub
comment or a document.** The commands below ask for secret values in a hidden
prompt.

## 1. Add the RevenueCat key, then deploy the backend

Do this from an up-to-date `main` branch.

### 1.1 Choose the value

- **You don't have a RevenueCat account yet:** use the word `unset`. Pro
  still works through RevenueCat's webhook. Instant sync, account transfers,
  the 6-hourly check and deleting RevenueCat data start working once you
  replace `unset` with a real key.
- **You have a RevenueCat account:** open the RevenueCat dashboard, pick your
  project, go to **API keys** and click **+ New secret API key**. Name it
  `firebase-functions`. If it asks for an API version, choose **V1**. Copy
  the key. It starts with `sk_`.

### 1.2 Save it in Firebase

```sh
firebase login
firebase functions:secrets:set REVENUECAT_API_KEY --project fighter-edge-app
```

Paste the value when asked. Then check that all three secrets exist. These
commands show only version numbers, never the values:

```sh
firebase functions:secrets:get OPENROUTER_API_KEY --project fighter-edge-app
firebase functions:secrets:get REVENUECAT_WEBHOOK_AUTH --project fighter-edge-app
firebase functions:secrets:get REVENUECAT_API_KEY --project fighter-edge-app
```

### 1.3 Deploy

```sh
git checkout main && git pull
npm --prefix functions ci
firebase functions:artifacts:setpolicy --location us-central1 --project fighter-edge-app
firebase deploy --only functions,firestore:rules,firestore:indexes --project fighter-edge-app
```

You only need the `setpolicy` line once. It deletes old build images so they
don't cost money, and it stops later automatic deploys from stopping to ask
about it. Accept the default answer.

### 1.4 Check that it worked

- `firebase functions:list --project fighter-edge-app` lists
  `syncEntitlement` and `reconcileEntitlements` next to the other functions.
- In the Firebase console, open **Firestore > Indexes**. The new `users`
  index (`plan`, `billing.expiresAtMs`) changes from "Building" to "Enabled"
  after a few minutes.
- In the Google Cloud console, open **Cloud Scheduler**. There is a job for
  `reconcileEntitlements` that runs every 6 hours.

**Deadline: deploy before 30 October 2026.** After that date, Google stops
supporting the old Node 20 version the functions currently run on. This
deploy moves them to Node 22.

## 2. Legal pages

The Privacy Policy, Terms of Use and account-deletion page are ready in
`hosting/public/`, in English and German. Each fact that only you know is
marked `TODO(owner)` and highlighted in yellow on the page. To list them:

```sh
grep -rn "TODO(owner)" hosting/public
```

### 2.1 Information only you can give

Edit the pages yourself, or send these answers to Claude and it will fill
them in:

| # | What | Notes |
|---|---|---|
| 1 | Your full name or company name, and its legal form | For example "Jane Doe (sole trader)" or "Example Ltd" |
| 2 | Postal address | It will be public on the pages |
| 3 | Contact email for privacy and support | Use a separate address, for example `privacy@your-domain.com`, not your personal one. It will be public and stored in git. |
| 4 | The country where you or your company are based | This decides which data-protection authority, which law and which consumer-dispute statement the pages name |
| 5 | Your developer name, exactly as the app stores show it | |
| 6 | The date the pages take effect | Usually the day you publish them |
| 7 | Where your database is stored | Firebase console > Firestore > the database's **Location**, for example `eur3` or `nam5` |
| 8 | Whether the AI coach will keep using free AI models | Free models may keep what users type. The pages and the app say so while that is true. If you change providers, the app's AI consent text must change too. |

### 2.2 Settings to change

The pages promise these, so set them:

- **Analytics data retention:** Firebase console > Analytics > **Admin** >
  **Data collection and modification** > **Data retention**. Set event data
  to **2 months**.
- **Data processing agreements:** accept them for Firebase and Google
  Analytics (Firebase console > Project settings, "Data Processing Terms"),
  and on the RevenueCat and OpenRouter websites.

### 2.3 What the app already does

The pages promise two things that the app now handles itself:

- It asks users for clear permission before it collects health data, and
  again before the AI coach sends anything to the AI provider. Users can
  take back either permission in **Settings > Privacy**.
- Deleting an account also deletes the user's RevenueCat record and removes
  their account from the billing history. Once RevenueCat is live, this
  needs a real `REVENUECAT_API_KEY`. With `unset`, the app can't reach
  RevenueCat to delete that record.

### 2.4 Legal review

The app handles health data, which the law protects strictly. Have a lawyer
or a data-protection service review the pages before launch. They are
drafts, not legal advice.

### 2.5 Publish

The deploy refuses to run while any `TODO(owner)` is left.

```sh
firebase deploy --only hosting --project fighter-edge-app
```

After step 3 you can also publish from GitHub: **Actions > Deploy backend >
Run workflow**, then choose **hosting**.

The pages will be at:

- `https://fighter-edge-app.web.app/privacy`
- `https://fighter-edge-app.web.app/terms`
- `https://fighter-edge-app.web.app/delete-account`

The German translations are under `/de/` on the same site.

### 2.6 Link the app and the stores to the pages

- **GitHub:** repository **Settings > Environments > production >
  Environment variables**. Add:
  - `TERMS_URL` = `https://fighter-edge-app.web.app/terms`
  - `PRIVACY_URL` = `https://fighter-edge-app.web.app/privacy`

  Release builds include these links. Without them, the release workflow
  stops.
- **App Store Connect:** set the Privacy Policy URL. For the License
  Agreement, either use the Terms URL as a custom agreement, or keep Apple's
  standard agreement and link the Terms in the app description.
- **Google Play Console:** set the Privacy Policy URL. Under **Data
  deletion**, set the account-deletion URL to
  `https://fighter-edge-app.web.app/delete-account`.

## 3. Automatic backend deploys (optional)

After this setup, every merge to `main` that changes the backend runs the
tests and then deploys, after you approve it. No password or key is stored
anywhere: GitHub proves its identity to Google directly (this is called
Workload Identity Federation).

### 3.1 First, protect the `production` environment

GitHub > **Settings > Environments > production** (create it if it doesn't
exist):

- **Required reviewers:** add yourself. Every deploy and every release then
  waits until you click approve.
- **Deployment branches and tags:** choose "Selected branches and tags",
  then add `main` and the tag pattern `v*.*.*` (used for releases).

### 3.2 Set up Google Cloud

Open the Google Cloud console for the project `fighter-edge-app`. Click
**Activate Cloud Shell** (the `>_` icon at the top right). Paste this whole
block and press Enter:

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

# Only jobs in this repository's protected `production` environment may
# act as the deployer.
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

The last two lines print two values you need in the next step. They are not
secret.

### 3.3 Give the values to GitHub

GitHub > **Settings > Secrets and variables > Actions**, then the
**Variables** tab. Click **New repository variable** and add both values
printed above, with the same names.

### 3.4 Test it

Wait about five minutes for Google to apply the new permissions. Then go to
GitHub > **Actions > Deploy backend > Run workflow**. Choose the branch
`main` and the target `backend`. Approve the deployment when GitHub asks. The
run should finish with a green check.

If it fails with "Permission denied" or "does not have permission", the error
message names the missing permission. In the Google Cloud console, open
**IAM**, give that role to `github-deployer`, and run the workflow again.

There is also a fallback that uses a stored key (the `FIREBASE_SERVICE_ACCOUNT`
secret). Use it only if the setup above is impossible for you: a stored key
can leak, and the setup above has none.

## 4. Protect the AI budget

The app now proves to the server that requests come from the real app
(Firebase App Check), and the server limits how much each account and the
whole app can spend on AI each day. Some switches need you.

### 4.1 Register the apps in App Check

Firebase console > **App Check** > **Apps**:

- **Android:** choose **Play Integrity**. It needs the SHA-256 fingerprint
  of your app signing key (Google Play Console > your app > **Test and
  release > App integrity**) and your Google Cloud project linked in the Play
  Console (**App integrity > Play Integrity API**).
- **iOS:** choose **DeviceCheck**. In the Apple Developer website, create a
  key with **DeviceCheck** enabled (**Certificates, IDs & Profiles > Keys**),
  then upload the `.p8` file with its Key ID and your Team ID.
- **While developing:** debug builds print a debug token in the device log.
  Add it under **App Check > Apps > (your app) > Manage debug tokens**.

### 4.2 Switch on enforcement, later

Wait until a version of the app with App Check is in the stores and most
users have updated. Then check Firebase console > **App Check** > **APIs** >
**Cloud Functions**: almost all requests should show as verified.

Then, in `functions/.env.fighter-edge-app`, change `ENFORCE_APP_CHECK=false`
to `ENFORCE_APP_CHECK=true`, commit, and deploy the functions. From then on,
the AI coach and the purchase sync refuse requests that don't come from the
real app. **Older app versions without App Check lose the AI coach at that
moment**, which is why you wait.

Leave App Check enforcement for Firestore off in the console for now.
Turning it on would lock users of older app versions out of their own data.

### 4.3 Set spending limits

- **OpenRouter:** open **Keys**, edit the key the functions use, and set a
  **credit limit**. OpenRouter then stops that key at the limit.
- **Google Cloud:** open **Billing > Budgets & alerts** and create a monthly
  budget with email alerts at 50%, 90% and 100%.

### 4.4 The daily AI budget

The server adds up the AI tokens used each day, for all users together, in
Firestore under `aiStats/<date>`. These totals contain counts only, never
user data. When a day reaches its budget, the AI pauses until midnight UTC.

- The default budget is 2,000,000 tokens a day.
- To change it, create the Firestore document `config/edgeFuelAi` (if it
  doesn't exist) and set the number field `dailyTokenBudget`.
- To switch the AI off completely, set the boolean field `enabled` to
  `false` in the same document.

Each account also has daily limits: 6 Fighter Briefs, 20 chat messages,
25 AI requests in total.

### 4.5 Move to a paid AI model before launch

You approved this. The free models can be withdrawn at any time, and their
providers may keep what users type.

1. Add credits to your OpenRouter account.
2. Ask Claude to pick the model and update the app. It will use the
   `aiStats` totals to estimate the cost per user. Then, in
   `functions/.env.fighter-edge-app`, the `OPENROUTER_MODELS` line gets the
   paid model and `OPENROUTER_DATA_COLLECTION=deny` is switched on. With
   that setting, OpenRouter only uses providers that don't store or train on
   what users type.
3. The privacy policy (section 2.3) and the app's AI consent text both say
   that free models may keep inputs. Claude updates both in the same change.

## 5. Automatic Play Store uploads (optional)

Without this, the release workflow still builds a signed app bundle and
attaches it to the GitHub Actions run for you to upload to Play by hand.
With it, every version tag (`v1.2.3`) uploads straight to Play's internal
testing track.

### 5.1 Create the service account

1. Google Play Console > **Setup > API access**. If this is the first time,
   click **Choose a project** and link or create a Google Cloud project.
2. Click **Create new service account**. It opens Google Cloud Console for
   you; click **Create Service Account**, give it any name, and finish the
   wizard without granting it a project role.
3. Back in Play Console, find the new service account in the list and click
   **Grant access**. Give it the **Release manager** permission for this
   app (it doesn't need Admin).
4. In Google Cloud Console, open the service account > **Keys** > **Add
   key** > **Create new key** > **JSON**. This downloads a `.json` file —
   treat it like a password.

### 5.2 Add it to GitHub

1. This repository's **Settings > Environments > production > Secrets**.
2. Add a secret named `PLAY_SERVICE_ACCOUNT_JSON`.
3. Open the downloaded `.json` file, copy its entire contents, and paste
   them as the secret's value.
4. Delete the local `.json` file once it's saved in GitHub.

### 5.3 Before the first upload

Play requires the app's first release to be uploaded by hand once, through
the Play Console website, before the API can publish to it. Do that first
(any track), then every tagged release after that can upload automatically.

