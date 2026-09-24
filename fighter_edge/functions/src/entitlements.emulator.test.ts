// Entitlement handler tests against the Firestore emulator (audit M-3/4/5,
// T-3). Run through `npm run test:rules`, which starts the emulator; skipped
// by plain `npm test` when no emulator is present.
import assert from "node:assert/strict";
import { after, before, describe, it } from "node:test";

import { deleteApp, initializeApp, App } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";

import { ENTITLEMENT_LEEWAY_MS } from "./billing";
import {
  FetchLike,
  processRevenueCatEvent,
  reconcileExpiredEntitlements,
  syncEntitlement,
  SYNC_THROTTLE_MS,
} from "./entitlements";

const emulator = process.env.FIRESTORE_EMULATOR_HOST;
const NOW = Date.parse("2026-09-24T12:00:00Z");
const DAY = 86_400_000;
let seq = 0;
const uid = (label: string) => `${label}-${++seq}-${Math.random().toString(36).slice(2, 8)}`;

/** A RevenueCat API double: answers from a map of uid -> pro expiry. */
function fakeRevenueCat(state: Record<string, number | null | "none" | "down">) {
  const calls: string[] = [];
  const fetchImpl: FetchLike = async (url) => {
    const id = decodeURIComponent(url.split("/").pop() ?? "");
    calls.push(id);
    const value = state[id] ?? "none";
    if (value === "down") return { ok: false, status: 503, json: async () => ({}) };
    const entitlements =
      value === "none"
        ? {}
        : {
            pro: {
              expires_date: value === null ? null : new Date(value).toISOString(),
              product_identifier: "fighter_edge_pro_annual",
            },
          };
    return {
      ok: true,
      status: 200,
      json: async () => ({
        subscriber: {
          entitlements,
          subscriptions: { fighter_edge_pro_annual: { store: "play_store" } },
        },
      }),
    };
  };
  return { fetchImpl, calls };
}

describe("entitlements (emulator)", { skip: !emulator && "no Firestore emulator" }, () => {
  let app: App;
  let db: Firestore;

  before(() => {
    app = initializeApp({ projectId: "demo-fighter-edge-billing" }, "entitlements-test");
    db = getFirestore(app);
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  const users = () => db.collection("users");
  const profile = async (id: string) => (await users().doc(id).get()).data();
  const seed = (id: string, data: Record<string, unknown> = { plan: "free" }) =>
    users().doc(id).set(data);

  const purchase = (id: string, overrides: Record<string, unknown> = {}) => ({
    id: `evt-${Math.random().toString(36).slice(2)}`,
    type: "INITIAL_PURCHASE",
    app_user_id: id,
    event_timestamp_ms: NOW,
    expiration_at_ms: NOW + 30 * DAY,
    product_id: "fighter_edge_pro_monthly",
    store: "APP_STORE",
    environment: "SANDBOX",
    ...overrides,
  });

  describe("webhook events", () => {
    it("grants Pro on a purchase and records the event", async () => {
      const id = uid("buyer");
      await seed(id);
      const event = purchase(id);
      const result = await processRevenueCatEvent(db, event, { apiKey: null, nowMs: NOW });
      assert.deepEqual(result, { status: "processed", applied: 1 });
      const data = await profile(id);
      assert.equal(data?.plan, "pro");
      assert.equal(data?.billing.expiresAtMs, NOW + 30 * DAY);
      assert.equal((await db.collection("billingEvents").doc(event.id).get()).exists, true);
    });

    it("is idempotent: a replayed event is a no-op", async () => {
      const id = uid("replay");
      await seed(id);
      const event = purchase(id);
      await processRevenueCatEvent(db, event, { apiKey: null, nowMs: NOW });
      const again = await processRevenueCatEvent(db, event, { apiKey: null, nowMs: NOW });
      assert.deepEqual(again, { status: "duplicate" });
    });

    it("never lets an older event overwrite a newer one", async () => {
      const id = uid("ordering");
      await seed(id);
      await processRevenueCatEvent(
        db,
        purchase(id, { type: "RENEWAL", event_timestamp_ms: NOW, expiration_at_ms: NOW + 60 * DAY }),
        { apiKey: null, nowMs: NOW },
      );
      // A delayed EXPIRATION from before the renewal arrives afterwards.
      const late = await processRevenueCatEvent(
        db,
        purchase(id, { type: "EXPIRATION", event_timestamp_ms: NOW - DAY, expiration_at_ms: NOW - DAY }),
        { apiKey: null, nowMs: NOW },
      );
      assert.deepEqual(late, { status: "processed", applied: 0 });
      assert.equal((await profile(id))?.plan, "pro");
    });

    it("revokes Pro on expiration", async () => {
      const id = uid("expiring");
      await seed(id);
      await processRevenueCatEvent(db, purchase(id), { apiKey: null, nowMs: NOW });
      await processRevenueCatEvent(
        db,
        purchase(id, { type: "EXPIRATION", event_timestamp_ms: NOW + DAY }),
        { apiKey: null, nowMs: NOW + DAY },
      );
      assert.equal((await profile(id))?.plan, "free");
    });

    it("never creates a profile for an unknown account", async () => {
      const id = uid("ghost");
      const result = await processRevenueCatEvent(db, purchase(id), { apiKey: null, nowMs: NOW });
      assert.deepEqual(result, { status: "processed", applied: 0 });
      assert.equal((await users().doc(id).get()).exists, false);
    });

    it("ignores TEST events and missing payloads", async () => {
      const id = uid("tester");
      await seed(id);
      assert.equal(
        (await processRevenueCatEvent(db, purchase(id, { type: "TEST" }), { apiKey: null, nowMs: NOW })).status,
        "ignored",
      );
      assert.equal((await processRevenueCatEvent(db, undefined, { apiKey: null, nowMs: NOW })).status, "ignored");
      assert.equal((await profile(id))?.plan, "free");
    });
  });

  describe("TRANSFER (restore on another account)", () => {
    it("moves Pro from the old account to the new one via RevenueCat", async () => {
      const from = uid("old");
      const to = uid("new");
      await seed(from, { plan: "pro", billing: { expiresAtMs: NOW + 30 * DAY, lastEventTimestampMs: NOW - DAY } });
      await seed(to);
      const rc = fakeRevenueCat({ [from]: "none", [to]: NOW + 30 * DAY });

      const result = await processRevenueCatEvent(
        db,
        { id: `evt-t-${from}`, type: "TRANSFER", event_timestamp_ms: NOW, transferred_from: [from], transferred_to: [to] },
        { apiKey: "sk_test", nowMs: NOW, fetchImpl: rc.fetchImpl },
      );

      assert.deepEqual(result, { status: "processed", applied: 2 });
      assert.equal((await profile(from))?.plan, "free");
      assert.equal((await profile(to))?.plan, "pro");
      assert.deepEqual(rc.calls.sort(), [from, to].sort());
    });

    it("without an API key still revokes the old account and flags the new one as pending", async () => {
      const from = uid("old-nokey");
      const to = uid("new-nokey");
      await seed(from, { plan: "pro", billing: { expiresAtMs: NOW + 30 * DAY } });
      await seed(to);
      const eventId = `evt-t-${from}`;
      await processRevenueCatEvent(
        db,
        { id: eventId, type: "TRANSFER", event_timestamp_ms: NOW, transferred_from: [from], transferred_to: [to] },
        { apiKey: null, nowMs: NOW },
      );
      assert.equal((await profile(from))?.plan, "free");
      assert.equal((await profile(to))?.plan, "free");
      const ledger = (await db.collection("billingEvents").doc(eventId).get()).data();
      assert.equal(ledger?.pendingWithoutApiKey, 1);
    });

    it("throws for a retry when RevenueCat is down, without writing the ledger", async () => {
      const from = uid("old-down");
      const to = uid("new-down");
      await seed(from);
      await seed(to);
      const eventId = `evt-t-${from}`;
      const rc = fakeRevenueCat({ [from]: "down", [to]: "down" });
      await assert.rejects(
        processRevenueCatEvent(
          db,
          { id: eventId, type: "TRANSFER", event_timestamp_ms: NOW, transferred_from: [from], transferred_to: [to] },
          { apiKey: "sk_test", nowMs: NOW, fetchImpl: rc.fetchImpl },
        ),
      );
      assert.equal((await db.collection("billingEvents").doc(eventId).get()).exists, false);
    });
  });

  describe("syncEntitlement (after purchase or restore)", () => {
    it("grants Pro straight from RevenueCat", async () => {
      const id = uid("sync");
      await seed(id);
      const rc = fakeRevenueCat({ [id]: NOW + 30 * DAY });
      const result = await syncEntitlement(db, id, { apiKey: "sk_test", nowMs: NOW, fetchImpl: rc.fetchImpl });
      assert.deepEqual(result, { status: "updated", isPro: true, expiresAtMs: NOW + 30 * DAY });
      const data = await profile(id);
      assert.equal(data?.plan, "pro");
      assert.equal(data?.billing.lastSyncAtMs, NOW);
    });

    it("is throttled per account", async () => {
      const id = uid("throttle");
      await seed(id);
      const rc = fakeRevenueCat({ [id]: NOW + DAY });
      await syncEntitlement(db, id, { apiKey: "sk_test", nowMs: NOW, fetchImpl: rc.fetchImpl });
      const again = await syncEntitlement(db, id, { apiKey: "sk_test", nowMs: NOW + 1000, fetchImpl: rc.fetchImpl });
      assert.deepEqual(again, { status: "throttled" });
      const later = await syncEntitlement(db, id, {
        apiKey: "sk_test",
        nowMs: NOW + SYNC_THROTTLE_MS,
        fetchImpl: rc.fetchImpl,
      });
      assert.equal(later.status, "updated");
      assert.equal(rc.calls.length, 2);
    });

    it("degrades to unavailable without a key, for unknown accounts, or when RevenueCat is down", async () => {
      const id = uid("unavailable");
      await seed(id);
      assert.deepEqual(await syncEntitlement(db, id, { apiKey: null, nowMs: NOW }), { status: "unavailable" });
      assert.deepEqual(
        await syncEntitlement(db, uid("missing"), { apiKey: "sk_test", nowMs: NOW, fetchImpl: fakeRevenueCat({}).fetchImpl }),
        { status: "unavailable" },
      );
      const down = fakeRevenueCat({ [id]: "down" });
      assert.deepEqual(
        await syncEntitlement(db, id, { apiKey: "sk_test", nowMs: NOW, fetchImpl: down.fetchImpl }),
        { status: "unavailable" },
      );
      assert.equal((await profile(id))?.plan, "free");
    });
  });

  describe("reconcileExpiredEntitlements", () => {
    const expiredLongAgo = NOW - ENTITLEMENT_LEEWAY_MS - DAY;

    it("recovers a renewal whose webhook never arrived, and expires the rest", async () => {
      const renewed = uid("renewed");
      const lapsed = uid("lapsed");
      await seed(renewed, { plan: "pro", billing: { expiresAtMs: expiredLongAgo } });
      await seed(lapsed, { plan: "pro", billing: { expiresAtMs: expiredLongAgo } });
      const rc = fakeRevenueCat({ [renewed]: NOW + 30 * DAY, [lapsed]: expiredLongAgo });

      await reconcileExpiredEntitlements(db, { apiKey: "sk_test", nowMs: NOW, fetchImpl: rc.fetchImpl });

      assert.equal((await profile(renewed))?.plan, "pro");
      assert.equal((await profile(renewed))?.billing.expiresAtMs, NOW + 30 * DAY);
      assert.equal((await profile(lapsed))?.plan, "free");
    });

    it("without a key, sets expired plans to free", async () => {
      const lapsed = uid("lapsed-nokey");
      await seed(lapsed, { plan: "pro", billing: { expiresAtMs: expiredLongAgo, productId: "p" } });
      await reconcileExpiredEntitlements(db, { apiKey: null, nowMs: NOW });
      const data = await profile(lapsed);
      assert.equal(data?.plan, "free");
      assert.equal(data?.billing.productId, "p");
    });

    it("leaves manual grants, active plans and in-leeway plans alone", async () => {
      const manual = uid("manual");
      const active = uid("active");
      const justExpired = uid("just-expired");
      await seed(manual, { plan: "pro" });
      await seed(active, { plan: "pro", billing: { expiresAtMs: NOW + DAY } });
      await seed(justExpired, { plan: "pro", billing: { expiresAtMs: NOW - 1000 } });
      await reconcileExpiredEntitlements(db, { apiKey: null, nowMs: NOW });
      assert.equal((await profile(manual))?.plan, "pro");
      assert.equal((await profile(active))?.plan, "pro");
      assert.equal((await profile(justExpired))?.plan, "pro");
    });
  });
});
