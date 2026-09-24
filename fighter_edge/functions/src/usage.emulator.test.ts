// Daily AI usage totals against the Firestore emulator (audit D-8). Run
// through `npm run test:rules`; skipped by plain `npm test` without it.
import assert from "node:assert/strict";
import { after, before, describe, it } from "node:test";

import { deleteApp, initializeApp, App } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";

import { dailyBudgetReached, recordUsage } from "./usage";

const emulator = process.env.FIRESTORE_EMULATOR_HOST;

describe("AI usage totals (emulator)", { skip: !emulator && "no Firestore emulator" }, () => {
  let app: App;
  let db: Firestore;

  before(() => {
    app = initializeApp({ projectId: "demo-fighter-edge-usage" }, "usage-test");
    db = getFirestore(app);
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  it("adds each request to the day's totals without any account ID", async () => {
    const now = new Date("2031-01-02T10:00:00Z");
    await recordUsage(db, now, {
      task: "fighterBrief",
      modelCalls: 2,
      usage: { promptTokens: 1500, completionTokens: 300, costUsd: 0.002 },
      answered: true,
    });
    await recordUsage(db, now, {
      task: "chat",
      modelCalls: 1,
      usage: { promptTokens: 800, completionTokens: 100, costUsd: 0.001 },
      answered: false,
    });

    const stats = (await db.collection("aiStats").doc("2031-01-02").get()).data();
    assert.equal(stats?.requests, 2);
    assert.equal(stats?.answered, 1);
    assert.equal(stats?.modelCalls, 3);
    assert.equal(stats?.totalTokens, 2700);
    assert.ok(Math.abs((stats?.costUsd as number) - 0.003) < 1e-9);
    assert.deepEqual(stats?.byTask, { fighterBrief: 1, chat: 1 });
    assert.deepEqual(
      Object.keys(stats ?? {}).sort(),
      ["answered", "byTask", "completionTokens", "costUsd", "modelCalls", "promptTokens", "requests", "totalTokens", "updatedAt"],
    );
  });

  it("reports the budget as reached once the day's tokens meet it", async () => {
    const now = new Date("2031-02-03T10:00:00Z");
    assert.equal(await dailyBudgetReached(db, now, 1000), false, "no usage yet");
    await recordUsage(db, now, {
      task: "chat",
      modelCalls: 1,
      usage: { promptTokens: 900, completionTokens: 100, costUsd: 0 },
      answered: true,
    });
    assert.equal(await dailyBudgetReached(db, now, 1001), false);
    assert.equal(await dailyBudgetReached(db, now, 1000), true);
    assert.equal(
      await dailyBudgetReached(db, new Date("2031-02-04T00:00:01Z"), 1000),
      false,
      "a new UTC day starts from zero",
    );
  });
});
