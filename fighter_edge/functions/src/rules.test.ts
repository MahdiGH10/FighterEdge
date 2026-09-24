// Firestore security-rules tests. They need the Firestore emulator, so they
// run through `npm run test:rules` (which starts it) and are skipped by the
// plain `npm test` when no emulator is present.
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { after, before, beforeEach, describe, it } from "node:test";

import firebase from "firebase/compat/app";
import "firebase/compat/firestore";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";

const emulator = process.env.FIRESTORE_EMULATOR_HOST;

describe("firestore.rules", { skip: !emulator && "no Firestore emulator" }, () => {
  let env: RulesTestEnvironment;

  before(async () => {
    env = await initializeTestEnvironment({
      projectId: "fighter-edge-rules-test",
      firestore: {
        rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8"),
      },
    });
  });

  beforeEach(async () => {
    await env.clearFirestore();
  });

  after(async () => {
    await env?.cleanup();
  });

  const entry = {
    id: "plan-Tue-Wrestling-2026-09-15",
    completedAtMs: 1789488000000,
    source: "planned",
    title: "Wrestling",
    rpe: 7,
  };

  const logDoc = (uid: string, db: ReturnType<typeof ownerDb>) =>
    db.collection("users").doc(uid).collection("trainingLog").doc(entry.id);

  const ownerDb = (uid: string) => env.authenticatedContext(uid).firestore();

  it("lets an athlete write, read and delete their own training log", async () => {
    const db = ownerDb("alice");
    await assertSucceeds(logDoc("alice", db).set(entry));
    await assertSucceeds(logDoc("alice", db).get());
    await assertSucceeds(
      db.collection("users").doc("alice").collection("trainingLog").get(),
    );
    await assertSucceeds(logDoc("alice", db).delete());
  });

  it("keeps another athlete out of the training log", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore()
        .collection("users").doc("alice")
        .collection("trainingLog").doc(entry.id).set(entry);
    });
    const mallory = ownerDb("mallory");
    await assertFails(logDoc("alice", mallory).get());
    await assertFails(logDoc("alice", mallory).set({ ...entry, rpe: 1 }));
    await assertFails(logDoc("alice", mallory).delete());
  });

  it("keeps signed-out visitors out of the training log", async () => {
    const anon = env.unauthenticatedContext().firestore();
    await assertFails(
      anon.collection("users").doc("alice")
        .collection("trainingLog").doc(entry.id).get(),
    );
  });

  // --- Billing is server-owned (audit T-3): the client must never be able
  // to grant, extend, or fake a paid entitlement, only the Admin SDK.

  const profile = (uid: string, db: ReturnType<typeof ownerDb>) =>
    db.collection("users").doc(uid);

  const seedProfile = async (uid: string, data: Record<string, unknown>) => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("users").doc(uid).set(data);
    });
  };

  it("lets a new athlete create a free profile", async () => {
    const db = ownerDb("alice");
    await assertSucceeds(
      profile("alice", db).set({ email: "a@example.test", plan: "free" }),
    );
  });

  it("refuses a profile created as Pro or with billing fields", async () => {
    const db = ownerDb("alice");
    await assertFails(profile("alice", db).set({ plan: "pro" }));
    await assertFails(
      profile("alice", db).set({ plan: "free", entitlement: "pro" }),
    );
    await assertFails(
      profile("alice", db).set({ plan: "free", billing: { expiresAtMs: 1 } }),
    );
  });

  it("refuses every client change to plan and billing fields", async () => {
    await seedProfile("alice", {
      plan: "free",
      billing: { provider: "revenuecat", expiresAtMs: 0 },
    });
    const db = ownerDb("alice");
    await assertFails(profile("alice", db).update({ plan: "pro" }));
    await assertFails(profile("alice", db).update({ entitlement: "pro" }));
    await assertFails(
      profile("alice", db).update({ "billing.expiresAtMs": 4102444800000 }),
    );
    await assertFails(profile("alice", db).update({ expiresAt: 1 }));
    await assertFails(profile("alice", db).update({ billingProvider: "x" }));
  });

  it("refuses downgrading or removing a server-granted Pro plan", async () => {
    await seedProfile("alice", { plan: "pro", billing: { expiresAtMs: 1 } });
    const db = ownerDb("alice");
    await assertFails(profile("alice", db).update({ plan: "free" }));
    await assertFails(profile("alice", db).set({ goal: "x" }));
  });

  it("still lets an athlete edit their own profile fields", async () => {
    await seedProfile("alice", { plan: "free", goal: "" });
    const db = ownerDb("alice");
    await assertSucceeds(
      profile("alice", db).update({ goal: "Make weight", onboardingComplete: true }),
    );
  });

  // --- Explicit consents (Art. 9 GDPR): the athlete's own declaration, but
  // stamped with the server's clock so it can't be backdated.

  const serverTime = () => firebase.firestore.FieldValue.serverTimestamp();

  it("lets an athlete give and withdraw consent with the server's time", async () => {
    await seedProfile("alice", { plan: "free" });
    const db = ownerDb("alice");
    await assertSucceeds(
      profile("alice", db).set(
        { consents: { healthData: { version: 1, grantedAt: serverTime() } } },
        { merge: true },
      ),
    );
    await assertSucceeds(
      profile("alice", db).set(
        { consents: { aiCoach: { version: 1, grantedAt: serverTime() } } },
        { merge: true },
      ),
    );
    // Other profile edits leave recorded consents alone and still pass.
    await assertSucceeds(profile("alice", db).update({ goal: "Make weight" }));
    await assertSucceeds(
      profile("alice", db).update({
        "consents.aiCoach": firebase.firestore.FieldValue.delete(),
      }),
    );
  });

  it("records consent on a profile that doesn't exist yet", async () => {
    const db = ownerDb("alice");
    await assertSucceeds(
      profile("alice", db).set(
        { consents: { healthData: { version: 1, grantedAt: serverTime() } } },
        { merge: true },
      ),
    );
  });

  it("refuses backdated, malformed or unknown consents", async () => {
    await seedProfile("alice", { plan: "free" });
    const db = ownerDb("alice");
    const backdated = new Date("2020-01-01T00:00:00Z");
    await assertFails(
      profile("alice", db).update({
        "consents.healthData": { version: 1, grantedAt: backdated },
      }),
    );
    await assertFails(
      profile("alice", db).update({
        "consents.healthData": { version: "1", grantedAt: serverTime() },
      }),
    );
    await assertFails(
      profile("alice", db).update({
        "consents.healthData": { version: 0, grantedAt: serverTime() },
      }),
    );
    await assertFails(
      profile("alice", db).update({
        "consents.healthData": {
          version: 1,
          grantedAt: serverTime(),
          grantedBy: "support",
        },
      }),
    );
    await assertFails(
      profile("alice", db).update({
        "consents.marketing": { version: 1, grantedAt: serverTime() },
      }),
    );
    await assertFails(profile("alice", db).update({ consents: "all" }));
  });

  it("keeps other athletes from recording consent for someone", async () => {
    await seedProfile("alice", { plan: "free" });
    await assertFails(
      profile("alice", ownerDb("mallory")).set(
        { consents: { healthData: { version: 1, grantedAt: serverTime() } } },
        { merge: true },
      ),
    );
  });

  it("never lets a client delete the profile document", async () => {
    await seedProfile("alice", { plan: "free" });
    await assertFails(profile("alice", ownerDb("alice")).delete());
  });

  it("keeps other athletes and visitors out of a profile", async () => {
    await seedProfile("alice", { plan: "pro" });
    await assertFails(profile("alice", ownerDb("mallory")).get());
    await assertFails(profile("alice", ownerDb("mallory")).update({ goal: "x" }));
    const anon = env.unauthenticatedContext().firestore();
    await assertFails(anon.collection("users").doc("alice").get());
  });

  it("lets an athlete read but never write their AI quota", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("users").doc("alice")
        .collection("aiUsage").doc("2026-09-24").set({ count: 20 });
    });
    const usage = ownerDb("alice").collection("users").doc("alice")
      .collection("aiUsage").doc("2026-09-24");
    await assertSucceeds(usage.get());
    await assertFails(usage.set({ count: 0 }));
    await assertFails(usage.delete());
  });

  it("keeps server config and the billing ledger closed to clients", async () => {
    const db = ownerDb("alice");
    await assertFails(db.collection("config").doc("edgeFuelAi").get());
    await assertFails(
      db.collection("config").doc("edgeFuelAi").set({ enabled: true }),
    );
    await assertFails(db.collection("billingEvents").doc("evt").get());
    await assertFails(
      db.collection("billingEvents").doc("evt").set({ applied: true }),
    );
  });

  it("keeps each athlete's nutrition and weights private", async () => {
    const mallory = ownerDb("mallory");
    for (const sub of ["weights", "nutritionDays", "nutritionTargets", "nutritionProfile", "sessions", "meals"]) {
      await assertFails(
        mallory.collection("users").doc("alice").collection(sub).doc("x").get(),
      );
      await assertSucceeds(
        ownerDb("alice").collection("users").doc("alice").collection(sub)
          .doc("x").set({ v: 1 }),
      );
    }
  });

  it("still denies collections the rules do not name", async () => {
    const db = ownerDb("alice");
    await assertFails(
      db.collection("users").doc("alice").collection("unknownThing").doc("x")
        .set({ a: 1 }),
    );
  });
});
