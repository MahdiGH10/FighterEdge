// Rewarded-video credits against the Firestore emulator. Run through
// `npm run test:rules`; skipped by plain `npm test` without it.
import assert from "node:assert/strict";
import { after, before, describe, it } from "node:test";

import { deleteApp, initializeApp, App } from "firebase-admin/app";
import { Firestore, getFirestore } from "firebase-admin/firestore";

import {
  createRewardToken,
  grantReward,
  hasUnusedReward,
  refundReward,
  REWARD_TOKEN_TTL_MS,
  rewardState,
  useReward,
} from "./adRewards";

const emulator = process.env.FIRESTORE_EMULATOR_HOST;

describe("rewarded briefs (emulator)", { skip: !emulator && "no Firestore emulator" }, () => {
  let app: App;
  let db: Firestore;

  before(() => {
    app = initializeApp({ projectId: "demo-fighter-edge-rewards" }, "rewards-test");
    db = getFirestore(app);
  });

  after(async () => {
    if (app) await deleteApp(app);
  });

  it("grants one reward a day, ignores a replayed callback, and is used once", async () => {
    const now = new Date("2031-03-04T10:00:00Z");
    assert.equal(await rewardState(db, "ria", now), "available");

    const token = await createRewardToken(db, "ria", now);
    assert.equal(await grantReward(db, token, "tx-1", now), "granted");
    assert.equal(await grantReward(db, token, "tx-2", now), "unknownToken", "a token works once");
    const second = await createRewardToken(db, "ria", now);
    assert.equal(await grantReward(db, second, "tx-1", now), "duplicate");
    assert.equal(await grantReward(db, second, "tx-3", now), "dailyLimit");
    assert.equal(await rewardState(db, "ria", now), "unused");
    assert.equal(await hasUnusedReward(db, "ria", now), true);

    assert.equal(await useReward(db, "ria", now), true);
    assert.equal(await useReward(db, "ria", now), false, "one video, one brief");
    assert.equal(await rewardState(db, "ria", now), "usedToday");
  });

  it("refuses an old or made-up token", async () => {
    const then = new Date("2031-03-08T08:00:00Z");
    const token = await createRewardToken(db, "lee", then);
    const late = new Date(then.getTime() + REWARD_TOKEN_TTL_MS + 1000);
    assert.equal(await grantReward(db, token, "tx-late", late), "unknownToken");
    assert.equal(await grantReward(db, "made-up", "tx-x", then), "unknownToken");
    assert.equal(await rewardState(db, "lee", then), "available");
  });

  it("gives a reward back when the brief could not be written", async () => {
    const now = new Date("2031-03-05T10:00:00Z");
    await grantReward(db, await createRewardToken(db, "sam", now), "tx-9", now);
    assert.equal(await useReward(db, "sam", now), true);

    await refundReward(db, "sam", now);
    assert.equal(await hasUnusedReward(db, "sam", now), true);

    await refundReward(db, "sam", now);
    await refundReward(db, "sam", now);
    assert.equal(await useReward(db, "sam", now), true);
    assert.equal(await useReward(db, "sam", now), false, "never below zero");
  });

  it("a reward is for its own UTC day only", async () => {
    const night = new Date("2031-03-06T23:00:00Z");
    await grantReward(db, await createRewardToken(db, "kai", night), "tx-a", night);
    assert.equal(
      await hasUnusedReward(db, "kai", new Date("2031-03-07T01:00:00Z")),
      false,
    );
  });
});
