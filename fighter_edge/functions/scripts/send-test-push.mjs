// Sends a test push notification to the phones signed in as the given
// accounts, through Firebase Cloud Messaging.
//
//   node scripts/send-test-push.mjs a@example.com b@example.com \
//        [--title "Fighter Edge test"] [--body "It works."] [--dry-run]
//
// Runs on the owner's PC with the owner's own Google login (`gcloud auth
// login`); it adds no public endpoint. It looks each email up in Firebase
// Auth, reads that account's saved phone tokens (users/{uid}/pushTokens, filed
// by the app once the athlete signed in and allowed notifications), and sends
// one message per token. A token Firebase says no longer exists is deleted.
//
// Prints counts and masked emails only: never tokens or account ids.
import { execSync } from "node:child_process";

const PROJECT = process.env.FIREBASE_PROJECT ?? "fighter-edge-app";

const args = process.argv.slice(2);
const emails = [];
let title = "Fighter Edge test";
let body = "Notifications work on this phone.";
let dryRun = false;
for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  if (arg === "--title") title = args[++i];
  else if (arg === "--body") body = args[++i];
  else if (arg === "--dry-run") dryRun = true;
  else emails.push(arg);
}
if (emails.length === 0) {
  console.error("Usage: node scripts/send-test-push.mjs <email> [<email> ...] [--title t] [--body b] [--dry-run]");
  process.exit(2);
}

const accessToken = execSync("gcloud auth print-access-token", {
  encoding: "utf8",
}).trim();
const headers = {
  Authorization: `Bearer ${accessToken}`,
  "x-goog-user-project": PROJECT,
  "Content-Type": "application/json",
};

const mask = (email) => email.replace(/^(.).*(@.*)$/, "$1***$2");

async function api(url, init = {}) {
  const response = await fetch(url, { headers, ...init });
  const text = await response.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    // Not JSON: keep the status only.
  }
  return { ok: response.ok, status: response.status, json };
}

async function uidFor(email) {
  const { ok, json } = await api(
    `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts:lookup`,
    { method: "POST", body: JSON.stringify({ email: [email] }) },
  );
  return ok ? (json?.users?.[0]?.localId ?? null) : null;
}

async function tokensFor(uid) {
  const { ok, json } = await api(
    `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/users/${uid}/pushTokens`,
  );
  if (!ok) return [];
  return (json?.documents ?? []).map((doc) => ({
    name: doc.name,
    token: doc.fields?.token?.stringValue,
  })).filter((entry) => entry.token);
}

for (const email of emails) {
  const label = mask(email);
  const uid = await uidFor(email);
  if (!uid) {
    console.log(`${label}: no account with this email.`);
    continue;
  }
  const tokens = await tokensFor(uid);
  if (tokens.length === 0) {
    console.log(
      `${label}: account found, but no phone is registered. The athlete must ` +
        "install the build with push, sign in, allow notifications and open the app once.",
    );
    continue;
  }
  let sent = 0;
  let removed = 0;
  let failed = 0;
  for (const { name, token } of tokens) {
    if (dryRun) {
      sent++;
      continue;
    }
    const result = await api(
      `https://fcm.googleapis.com/v1/projects/${PROJECT}/messages:send`,
      {
        method: "POST",
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            android: { notification: { channel_id: "fe_push" } },
          },
        }),
      },
    );
    if (result.ok) {
      sent++;
    } else if (result.status === 404 || result.json?.error?.status === "NOT_FOUND") {
      // The phone's token is gone (app removed or token reset): tidy up.
      await api(`https://firestore.googleapis.com/v1/${name}`, { method: "DELETE" });
      removed++;
    } else {
      failed++;
      console.log(`${label}: send failed (${result.status} ${result.json?.error?.status ?? ""}).`);
    }
  }
  console.log(
    `${label}: ${dryRun ? "would send to" : "sent to"} ${sent} phone(s)` +
      (removed ? `, removed ${removed} stale` : "") +
      (failed ? `, ${failed} failed` : "") +
      ".",
  );
}
