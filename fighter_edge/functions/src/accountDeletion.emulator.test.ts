// Account deletion against the Firestore emulator (audit D-9). Run through
// `npm run test:rules`, which starts the emulator; skipped by plain
// `npm test` when no emulator is present.
import assert from "node:assert/strict";
import { after, before, describe, it } from "node:test";

import { deleteApp, initializeApp, App } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";

import { deleteAccountData } from "./accountDeletion";
import { FetchLike, processRevenueCatEvent, RevenueCatUnavailable } from "./entitlements";

const emulator = process.env.FIRESTORE_EMULATOR_HOST;
const NOW = Date.parse("2026-09-24T12:00:00Z");
const id = (label: string) => `${label}-${Math.random().toString(36).slice(2, 10)}`;

/** RevenueCat double that answers every call with [status]. */
function fakeRevenueCat(status: number) {
  const calls: { method: string; appUserId: string }[] = [];
  const fetchImpl: FetchLike = async (url, init) => {
    calls.push({
      method: init.method,
      appUserId: decodeURIComponent(url.split("/").pop() ?? ""),
    });
    return { ok: status >= 200 && status < 300, status, json: async () => ({}) };
  };
  return { fetchImpl, calls };
}

describe("account deletion (emulator)", { skip: !emulator && "no Firestore emulator" }, () => {
  let app: App;
  let db: Firestore;

  before(() => {
    app = initializeApp({ projectId: "demo-fighter-edge-deletion" }, "deletion-test");
    db = getFirestore(app);
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  /** An account with profile, consents, logs and billing history. */
  async function seedAccount(uid: string, other: string) {
    const profile = db.collection("users").doc(uid);
    await profile.set({
      plan: "pro",
      billing: { expiresAtMs: NOW + 86_400_000 },
      consents: { healthData: { version: 1 } },
    });
    await profile.collection("weights").doc("w1").set({ kg: 77.2 });
    await profile.collection("trainingLog").doc("t1").set({ rpe: 7 });
    await profile.collection("aiUsage").doc("2026-09-24").set({ count: 3 });
    const ledger = db.collection("billingEvents");
    const own = id("evt-own");
    const others = id("evt-other");
    const transfer = id("evt-transfer");
    await ledger.doc(own).set({ provider: "revenuecat", type: "RENEWAL", userId: uid });
    await ledger.doc(others).set({ provider: "revenuecat", type: "RENEWAL", userId: other });
    await ledger.doc(transfer).set({ type: "TRANSFER", userIds: [uid, other] });
    return { own, others, transfer };
  }

  const exists = async (path: string) => (await db.doc(path).get()).exists;
  const data = async (path: string) => (await db.doc(path).get()).data();

  it("deletes the RevenueCat customer, unlinks billing and wipes the account", async () => {
    const uid = id("alice");
    const other = id("bob");
    const events = await seedAccount(uid, other);
    const revenueCat = fakeRevenueCat(200);

    const outcome = await deleteAccountData(db, uid, {
      apiKey: "sk_test",
      nowMs: NOW,
      fetchImpl: revenueCat.fetchImpl,
    });

    assert.deepEqual(outcome, { revenueCat: "deleted", ledgerEntriesUnlinked: 2 });
    assert.deepEqual(revenueCat.calls, [{ method: "DELETE", appUserId: uid }]);

    assert.equal(await exists(`users/${uid}`), false);
    for (const sub of ["weights/w1", "trainingLog/t1", "aiUsage/2026-09-24"]) {
      assert.equal(await exists(`users/${uid}/${sub}`), false, sub);
    }

    const own = await data(`billingEvents/${events.own}`);
    assert.equal(own?.userId, undefined);
    assert.equal(own?.accountDeleted, true);
    assert.equal(own?.type, "RENEWAL", "the event itself is kept for idempotency");
    assert.deepEqual((await data(`billingEvents/${events.transfer}`))?.userIds, [other]);
    assert.equal((await data(`billingEvents/${events.others}`))?.userId, other);
  });

  it("treats a customer RevenueCat doesn't know as already deleted", async () => {
    const uid = id("carol");
    await seedAccount(uid, id("dave"));
    const outcome = await deleteAccountData(db, uid, {
      apiKey: "sk_test",
      nowMs: NOW,
      fetchImpl: fakeRevenueCat(404).fetchImpl,
    });
    assert.equal(outcome.revenueCat, "not_found");
    assert.equal(await exists(`users/${uid}`), false);
  });

  it("deletes nothing while RevenueCat is unreachable, so a retry is clean", async () => {
    const uid = id("erin");
    const events = await seedAccount(uid, id("frank"));
    await assert.rejects(
      deleteAccountData(db, uid, {
        apiKey: "sk_test",
        nowMs: NOW,
        fetchImpl: fakeRevenueCat(503).fetchImpl,
      }),
      RevenueCatUnavailable,
    );
    assert.equal(await exists(`users/${uid}`), true);
    assert.equal(await exists(`users/${uid}/weights/w1`), true);
    assert.equal((await data(`billingEvents/${events.own}`))?.userId, uid);
  });

  it("still deletes everything it holds when RevenueCat isn't configured", async () => {
    const uid = id("gina");
    await seedAccount(uid, id("hank"));
    const revenueCat = fakeRevenueCat(200);
    const outcome = await deleteAccountData(db, uid, {
      apiKey: null,
      nowMs: NOW,
      fetchImpl: revenueCat.fetchImpl,
    });
    assert.deepEqual(outcome, { revenueCat: "skipped_no_key", ledgerEntriesUnlinked: 2 });
    assert.equal(revenueCat.calls.length, 0);
    assert.equal(await exists(`users/${uid}`), false);
  });

  it("records no identifier for a webhook about a deleted account", async () => {
    const uid = id("ivy");
    const eventId = id("evt-late");
    const result = await processRevenueCatEvent(
      db,
      {
        id: eventId,
        type: "RENEWAL",
        app_user_id: uid,
        event_timestamp_ms: NOW,
        expiration_at_ms: NOW + 86_400_000,
        product_id: "fighter_edge_pro_monthly",
        entitlement_ids: ["pro"],
        environment: "PRODUCTION",
        store: "PLAY_STORE",
      },
      { apiKey: null, nowMs: NOW },
    );
    assert.deepEqual(result, { status: "processed", applied: 0 });
    const ledger = await data(`billingEvents/${eventId}`);
    assert.equal(ledger?.ignored, "unknown_user");
    assert.equal(ledger?.userId, undefined);
    assert.equal(await exists(`users/${uid}`), false, "no profile is created");
  });
});
