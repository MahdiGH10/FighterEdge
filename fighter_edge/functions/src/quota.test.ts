import assert from "node:assert/strict";
import { test } from "node:test";

import {
  DAILY_QUOTA,
  DEFAULT_DAILY_TOKEN_BUDGET,
  TASK_DAILY_LIMITS,
  consumeQuota,
  readAiConfig,
  refundQuota,
} from "./quota";

const now = new Date("2026-09-20T12:00:00.000Z");

interface Usage {
  count?: number;
  byTask?: Record<string, number>;
}

/**
 * Small transaction-capable Firestore double for the quota transactions. It
 * keeps one usage document and applies `set(..., {merge: true})` the way
 * Firestore does for the nested `byTask` map.
 */
function quotaDb(initial: Usage = {}) {
  let usage: Usage = { ...initial, byTask: { ...initial.byTask } };
  const reference = {};
  const transaction = {
    get: async () => ({ data: () => usage }),
    set: (_ref: unknown, value: Usage) => {
      usage = {
        ...usage,
        ...value,
        byTask: { ...usage.byTask, ...value.byTask },
      };
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
      return usage.count ?? 0;
    },
    byTask(task: string) {
      return usage.byTask?.[task] ?? 0;
    },
  };
}

test("each task has its own allowance within the daily total", async () => {
  const store = quotaDb({ count: 5, byTask: { fighterBrief: TASK_DAILY_LIMITS.fighterBrief } });

  const brief = await consumeQuota(store.db, "athlete", now, "fighterBrief");
  const chat = await consumeQuota(store.db, "athlete", now, "chat");

  assert.equal(brief.allowed, false, "the brief allowance is spent");
  assert.equal(chat.allowed, true, "chat still has room");
  assert.equal(store.byTask("chat"), 1);
  assert.equal(store.count, 6);
  assert.equal(chat.remaining, TASK_DAILY_LIMITS.chat - 1);
});

test("the daily total caps every task", async () => {
  const store = quotaDb({ count: DAILY_QUOTA });
  for (const task of ["chat", "fighterBrief", "summarizeTrend"] as const) {
    const result = await consumeQuota(store.db, "athlete", now, task);
    assert.equal(result.allowed, false, task);
  }
  assert.equal(store.count, DAILY_QUOTA);
});

test("remaining reports the tighter of the two limits", async () => {
  const store = quotaDb({ count: DAILY_QUOTA - 2 });
  const result = await consumeQuota(store.db, "athlete", now, "chat");
  assert.equal(result.remaining, 1);
});

test("refundQuota releases exactly one reservation", async () => {
  const store = quotaDb();

  const reserved = await consumeQuota(store.db, "athlete", now, "chat");
  const refunded = await refundQuota(store.db, "athlete", now, "chat");

  assert.equal(reserved.allowed, true);
  assert.equal(store.count, 0);
  assert.equal(store.byTask("chat"), 0);
  assert.equal(refunded.remaining, TASK_DAILY_LIMITS.chat);
});

test("refundQuota preserves other successful reservations", async () => {
  const store = quotaDb();

  await consumeQuota(store.db, "athlete", now, "chat");
  await consumeQuota(store.db, "athlete", now, "fighterBrief");
  await refundQuota(store.db, "athlete", now, "chat");

  assert.equal(store.count, 1);
  assert.equal(store.byTask("chat"), 0);
  assert.equal(store.byTask("fighterBrief"), 1);
});

test("refundQuota never creates negative usage", async () => {
  const store = quotaDb();

  const result = await refundQuota(store.db, "athlete", now, "summarizeTrend");

  assert.equal(store.count, 0);
  assert.equal(store.byTask("summarizeTrend"), 0);
  assert.equal(result.remaining, TASK_DAILY_LIMITS.summarizeTrend);
});

test("no task allowance is larger than the daily total", () => {
  for (const limit of Object.values(TASK_DAILY_LIMITS)) {
    assert.ok(limit > 0 && limit <= DAILY_QUOTA);
  }
});

function configDb(data: Record<string, unknown> | undefined) {
  return {
    collection: () => ({ doc: () => ({ get: async () => ({ data: () => data }) }) }),
  } as never;
}

test("AI config defaults to enabled with the default token budget", async () => {
  assert.deepEqual(await readAiConfig(configDb(undefined)), {
    enabled: true,
    dailyTokenBudget: DEFAULT_DAILY_TOKEN_BUDGET,
  });
});

test("AI config reads the kill switch and a valid budget only", async () => {
  assert.deepEqual(
    await readAiConfig(configDb({ enabled: false, dailyTokenBudget: 500_000 })),
    { enabled: false, dailyTokenBudget: 500_000 },
  );
  for (const bad of [0, -1, "lots", Number.NaN]) {
    const config = await readAiConfig(configDb({ dailyTokenBudget: bad }));
    assert.equal(config.dailyTokenBudget, DEFAULT_DAILY_TOKEN_BUDGET);
  }
});
