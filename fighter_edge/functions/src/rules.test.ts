// Firestore security-rules tests. They need the Firestore emulator, so they
// run through `npm run test:rules` (which starts it) and are skipped by the
// plain `npm test` when no emulator is present.
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { after, before, beforeEach, describe, it } from "node:test";

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

  it("still denies collections the rules do not name", async () => {
    const db = ownerDb("alice");
    await assertFails(
      db.collection("users").doc("alice").collection("unknownThing").doc("x")
        .set({ a: 1 }),
    );
  });
});
