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

  const seedPaid = async (uid: string, overrides: Record<string, unknown> = {}) => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("users").doc(uid).set({
        plan: "pro",
        onboardingComplete: true,
        billing: { expiresAtMs: Date.now() + 86_400_000 },
        consents: {
          healthData: {
            version: 1,
            grantedAt: firebase.firestore.FieldValue.serverTimestamp(),
          },
        },
        ...overrides,
      });
    });
  };

  it("lets an athlete write, read and delete their own training log", async () => {
    await seedPaid("alice");
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

  const fight = {
    fightDate: "2026-12-12",
    weighInDate: "2026-12-11",
    weightLimitKg: 70.3,
    category: "professional",
    campWeeks: 8,
  };
  const fightDoc = (uid: string, db: ReturnType<typeof ownerDb>) =>
    db.collection("users").doc(uid).collection("fightCamp").doc("current");

  it("lets an athlete save, read and remove their own fight", async () => {
    await seedPaid("alice");
    const db = ownerDb("alice");
    await assertSucceeds(fightDoc("alice", db).set(fight));
    await assertSucceeds(fightDoc("alice", db).get());
    await assertSucceeds(fightDoc("alice", db).delete());
  });

  it("keeps everyone else out of an athlete's fight", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore()
        .collection("users").doc("alice")
        .collection("fightCamp").doc("current").set(fight);
    });
    const mallory = ownerDb("mallory");
    await assertFails(fightDoc("alice", mallory).get());
    await assertFails(fightDoc("alice", mallory).set({ ...fight, weightLimitKg: 99 }));
    const anon = env.unauthenticatedContext().firestore();
    await assertFails(
      anon.collection("users").doc("alice")
        .collection("fightCamp").doc("current").get(),
    );
  });

  const pushToken = (uid: string, db: ReturnType<typeof ownerDb>) =>
    db.collection("users").doc(uid).collection("pushTokens").doc("installid");
  const pushBody = () => ({
    token: "installid:" + "x".repeat(60),
    platform: "android",
    updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
  });

  it("lets an athlete file, read and remove their own push token", async () => {
    const db = ownerDb("alice");
    await assertSucceeds(pushToken("alice", db).set(pushBody()));
    await assertSucceeds(pushToken("alice", db).get());
    await assertSucceeds(pushToken("alice", db).delete());
  });

  it("keeps push tokens private and well-formed", async () => {
    await assertSucceeds(pushToken("alice", ownerDb("alice")).set(pushBody()));
    const mallory = ownerDb("mallory");
    await assertFails(pushToken("alice", mallory).get());
    await assertFails(pushToken("alice", mallory).set(pushBody()));
    await assertFails(pushToken("alice", mallory).delete());
    const anon = env.unauthenticatedContext().firestore();
    await assertFails(pushToken("alice", anon).get());

    const db = ownerDb("alice");
    await assertFails(pushToken("alice", db).set({ ...pushBody(), extra: 1 }));
    await assertFails(pushToken("alice", db).set({ ...pushBody(), token: "short" }));
    await assertFails(pushToken("alice", db).set({ ...pushBody(), platform: "web" }));
    await assertFails(pushToken("alice", db).set({ ...pushBody(), updatedAt: new Date(0) }));
  });

  const plan = {
    schemaVersion: 1,
    origin: "onboarding",
    inputs: {
      disciplines: [],
      goal: "buildFitness",
      level: "beginner",
      weekdays: [1, 3, 5],
      gymClassWeekdays: [],
      sessionMinutes: null,
      startDate: "2026-10-19",
    },
    adjustments: [],
  };
  const planDoc = (uid: string, db: ReturnType<typeof ownerDb>) =>
    db.collection("users").doc(uid).collection("trainingPlan").doc("current");

  it("lets an athlete save and read their own training plan", async () => {
    await seedPaid("alice");
    const db = ownerDb("alice");
    await assertSucceeds(planDoc("alice", db).set(plan));
    await assertSucceeds(planDoc("alice", db).get());
  });

  it("keeps everyone else out of an athlete's training plan", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore()
        .collection("users").doc("alice")
        .collection("trainingPlan").doc("current").set(plan);
    });
    const mallory = ownerDb("mallory");
    await assertFails(planDoc("alice", mallory).get());
    await assertFails(planDoc("alice", mallory).set({ ...plan, origin: "x" }));
    const anon = env.unauthenticatedContext().firestore();
    await assertFails(
      anon.collection("users").doc("alice")
        .collection("trainingPlan").doc("current").get(),
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
    await seedProfile("alice", {
      plan: "free", goal: "", onboardingComplete: false,
      consents: { healthData: { version: 1, grantedAt: serverTime() } },
    });
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

  it("never lets an athlete grant themselves a rewarded brief", async () => {
    const reward = ownerDb("alice").collection("users").doc("alice")
      .collection("adRewards").doc("2026-09-30");
    await assertSucceeds(reward.get());
    await assertFails(reward.set({ granted: 5, used: 0 }));
    await assertFails(ownerDb("bob").collection("users").doc("alice")
      .collection("adRewards").doc("2026-09-30").get());
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
      await assertFails(
        mallory.collection("users").doc("alice").collection(sub).doc("x").set({ v: 1 }),
      );
    }
  });

  it("allows only the owner to edit individual food entries", async () => {
    await seedPaid("alice");
    const owner = ownerDb("alice").collection("users").doc("alice")
      .collection("nutritionDays").doc("2026-10-25")
      .collection("entries").doc("entry-a");
    const other = ownerDb("mallory").collection("users").doc("alice")
      .collection("nutritionDays").doc("2026-10-25")
      .collection("entries").doc("entry-a");
    await assertSucceeds(owner.set({
      schemaVersion: 1, id: "entry-a", name: "Lunch", notes: "",
      calories: 300, proteinGrams: 25, carbGrams: 30, fatGrams: 10,
      consumed: true, saved: false, source: "manual",
      loggedAt: "2026-10-25T12:00:00.000", deleted: false,
    }));
    await assertSucceeds(owner.get());
    await assertFails(other.get());
    await assertFails(other.set({ id: "entry-a", calories: 0 }));
  });

  it("denies new health records to free, expired and unconsented accounts", async () => {
    await seedPaid("free", { plan: "free" });
    await seedPaid("expired", { billing: { expiresAtMs: Date.now() - 3_600_001 } });
    await seedPaid("unconsented", { consents: {} });
    for (const uid of ["free", "expired", "unconsented"]) {
      const db = ownerDb(uid);
      await assertFails(db.collection("users").doc(uid).collection("weights")
        .doc("first").set({ date: "2026-10-26T00:00:00Z", kg: 72 }));
      await assertFails(planDoc(uid, db).set(plan));
      await assertFails(logDoc(uid, db).set(entry));
      await assertFails(fightDoc(uid, db).set(fight));
      await assertFails(db.collection("users").doc(uid).collection("nutritionTargets")
        .doc("current").set({ status: "success", policyVersion: 1, calculatedAt: "2026-10-26" }));
    }
  });

  it("requires paid access for every post-onboarding health collection", async () => {
    await seedPaid("free", { plan: "free" });
    const db = ownerDb("free");
    const base = db.collection("users").doc("free");
    await assertFails(base.collection("meals").doc("2026-10-26")
      .set({ date: "2026-10-26", meals: [], updatedAt: serverTime() }));
    await assertFails(base.collection("sessions").doc("slot")
      .set({ id: "slot", day: "Mon", title: "Training", completed: false }));
    await assertFails(base.collection("nutritionProfile").doc("current")
      .set({ schemaVersion: 1, confirmed: false, screeningStatus: "unanswered", safetyFlags: {} }));
    await assertFails(base.collection("nutritionDays").doc("2026-10-26")
      .set({ schemaVersion: 1, localDate: "2026-10-26", updatedAt: serverTime() }));
    await assertFails(base.collection("nutritionDays").doc("2026-10-26")
      .collection("entries").doc("food").set({
        schemaVersion: 1, id: "food", name: "Lunch", deleted: false,
        calories: 300, proteinGrams: 25, carbGrams: 30, fatGrams: 10,
        loggedAt: "2026-10-26T12:00:00Z",
      }));
  });

  it("accepts valid ongoing records for a paid, consented account", async () => {
    await seedPaid("alice");
    const db = ownerDb("alice");
    const base = db.collection("users").doc("alice");
    await assertSucceeds(base.collection("weights").doc("first")
      .set({ date: "2026-10-26T00:00:00Z", kg: 72 }));
    await assertSucceeds(base.collection("meals").doc("2026-10-26")
      .set({ date: "2026-10-26", meals: [], updatedAt: serverTime() }));
    await assertSucceeds(base.collection("sessions").doc("slot")
      .set({ id: "slot", day: "Mon", title: "Training", completed: false }));
    await assertSucceeds(base.collection("nutritionProfile").doc("current")
      .set({ schemaVersion: 1, confirmed: false, screeningStatus: "unanswered", safetyFlags: {} }));
    await assertSucceeds(base.collection("nutritionTargets").doc("current")
      .set({ status: "success", policyVersion: 1, calculatedAt: "2026-10-26" }));
    await assertSucceeds(base.collection("nutritionDays").doc("2026-10-26")
      .set({ schemaVersion: 1, localDate: "2026-10-26", updatedAt: serverTime() }));
  });

  it("permits only the initial onboarding records with health consent", async () => {
    await seedPaid("new", { plan: "free", onboardingComplete: false });
    const db = ownerDb("new");
    const base = db.collection("users").doc("new");
    await assertSucceeds(base.collection("weights").doc("first")
      .set({ date: "2026-10-26T00:00:00Z", kg: 72 }));
    await assertSucceeds(base.collection("meals").doc("2026-10-26")
      .set({ date: "2026-10-26", meals: [], updatedAt: serverTime() }));
    await assertSucceeds(planDoc("new", db).set(plan));
    await assertSucceeds(base.collection("nutritionProfile").doc("current")
      .set({ schemaVersion: 1, confirmed: false, screeningStatus: "unanswered", safetyFlags: {} }));
    await assertSucceeds(base.collection("nutritionTargets").doc("current")
      .set({ status: "success", policyVersion: 1, calculatedAt: "2026-10-26" }));
    await assertFails(logDoc("new", db).set(entry));
    await assertFails(fightDoc("new", db).set(fight));
    await assertFails(base.collection("meals").doc("2026-10-27")
      .set({ date: "2026-10-27", meals: [{ name: "Lunch" }], updatedAt: serverTime() }));
    await assertFails(base.collection("nutritionDays").doc("2026-10-26")
      .collection("entries").doc("first").set({ id: "first", deleted: false }));
  });

  it("denies malformed records even when paid and consented", async () => {
    await seedPaid("alice");
    const db = ownerDb("alice");
    const base = db.collection("users").doc("alice");
    await assertFails(base.collection("weights").doc("bad")
      .set({ date: "2026-10-26", kg: -4 }));
    await assertFails(base.collection("weights").doc("extra")
      .set({ date: "2026-10-26", kg: 72, admin: true }));
    await assertFails(planDoc("alice", db).set({ ...plan, inputs: { goal: "buildFitness" } }));
    await assertFails(logDoc("alice", db).set({ ...entry, rpe: 99 }));
    await assertFails(fightDoc("alice", db).set({ ...fight, weightLimitKg: -1 }));
    await assertFails(base.collection("nutritionTargets").doc("current")
      .set({ status: "success", policyVersion: "1", calculatedAt: "2026-10-26" }));
    await assertFails(base.collection("nutritionTargets").doc("current")
      .set({ status: "success", policyVersion: 1, calculatedAt: "2026-10-26", targetCalories: -50 }));
    await assertFails(base.collection("nutritionProfile").doc("current")
      .set({ schemaVersion: 1, confirmed: false, screeningStatus: "unanswered", safetyFlags: {}, currentWeightKg: -2 }));
    await assertFails(base.collection("nutritionDays").doc("2026-10-26")
      .collection("entries").doc("bad").set({ id: "bad", calories: -1 }));
  });

  it("does not reopen onboarding or accept health profile edits after consent withdrawal", async () => {
    await seedPaid("alice", { plan: "free", onboardingComplete: true, consents: {} });
    const db = ownerDb("alice");
    await assertFails(profile("alice", db).update({ onboardingComplete: false }));
    await assertFails(profile("alice", db).update({ startingWeightKg: 72 }));
    await assertSucceeds(profile("alice", db).update({ displayName: "Alice" }));
  });

  it("still denies collections the rules do not name", async () => {
    const db = ownerDb("alice");
    await assertFails(
      db.collection("users").doc("alice").collection("unknownThing").doc("x")
        .set({ a: 1 }),
    );
  });
});
