import assert from "node:assert/strict";
import { test } from "node:test";

import { DAILY_QUOTA, consumeQuota, refundQuota } from "./quota";

const now = new Date("2026-09-20T12:00:00.000Z");

/** Small transaction-capable Firestore double for quota transaction tests. */
function quotaDb(initialCount = 0) {
  let count = initialCount;
  const reference = {};
  const transaction = {
    get: async () => ({ data: () => ({ count }) }),
    set: (_ref: unknown, value: { count?: number }) => {
      if (typeof value.count === "number") count = value.count;
    },
  };
  const db = {
    collection: () => ({
      doc: () => ({
        collection: () => ({ doc: () => reference }),
      }),
    }),
    runTransaction: async (work: (tx: typeof transaction) => unknown) =>
      work(transaction),
  };
  return {
    db: db as never,
    get count() {
      return count;
    },
  };
}

test("refundQuota releases exactly one reservation", async () => {
  const store = quotaDb();

  const reserved = await consumeQuota(store.db, "athlete", now);
  const refunded = await refundQuota(store.db, "athlete", now);

  assert.equal(reserved.allowed, true);
  assert.equal(store.count, 0);
  assert.equal(refunded.remaining, DAILY_QUOTA);
});

test("refundQuota preserves other successful reservations", async () => {
  const store = quotaDb();

  await consumeQuota(store.db, "athlete", now);
  await consumeQuota(store.db, "athlete", now);
  await refundQuota(store.db, "athlete", now);

  assert.equal(store.count, 1);
});

test("refundQuota never creates negative usage", async () => {
  const store = quotaDb();

  const result = await refundQuota(store.db, "athlete", now);

  assert.equal(store.count, 0);
  assert.equal(result.remaining, DAILY_QUOTA);
});
