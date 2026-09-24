import { Firestore } from "firebase-admin/firestore";

import { AiTaskType } from "./types";

/**
 * Per-account daily allowance for each AI task (audit D-8), applied after
 * the server-owned entitlement gate. A Fighter Brief is written once a day
 * and refreshed after new logs; chat is the open-ended one. `summarizeTrend`
 * is the only task a free account can call, so it gets the smallest share.
 */
export const TASK_DAILY_LIMITS: Readonly<Record<AiTaskType, number>> = {
  fighterBrief: 6,
  chat: 20,
  summarizeTrend: 3,
};

/** All tasks together, per account per day. */
export const DAILY_QUOTA = 25;

export interface QuotaResult {
  allowed: boolean;
  remaining: number;
}

interface UsageDoc {
  count?: number;
  byTask?: Partial<Record<AiTaskType, number>>;
}

function todayKey(now: Date): string {
  return now.toISOString().slice(0, 10); // YYYY-MM-DD (UTC)
}

function usageRef(db: Firestore, uid: string, now: Date) {
  return db.collection("users").doc(uid).collection("aiUsage").doc(todayKey(now));
}

/**
 * Atomically checks and reserves one request for [task] today. Refused when
 * either the task's own allowance or the daily total is spent.
 */
export async function consumeQuota(
  db: Firestore,
  uid: string,
  now: Date,
  task: AiTaskType,
): Promise<QuotaResult> {
  const ref = usageRef(db, uid, now);
  return db.runTransaction(async (tx) => {
    const usage = ((await tx.get(ref)).data() ?? {}) as UsageDoc;
    const used = usage.count ?? 0;
    const usedByTask = usage.byTask?.[task] ?? 0;
    const taskLimit = TASK_DAILY_LIMITS[task];

    if (used >= DAILY_QUOTA || usedByTask >= taskLimit) {
      return { allowed: false, remaining: 0 };
    }

    tx.set(
      ref,
      {
        count: used + 1,
        byTask: { [task]: usedByTask + 1 },
        updatedAt: now.toISOString(),
      },
      { merge: true },
    );
    return {
      allowed: true,
      remaining: Math.min(DAILY_QUOTA - used - 1, taskLimit - usedByTask - 1),
    };
  });
}

/**
 * Releases one reservation for [task] after the server could not produce a
 * validated answer. [consumeQuota] reserves capacity before provider I/O so
 * concurrent requests cannot overrun the limit; this compensating
 * transaction makes that reservation invisible to the athlete when the model,
 * provider, or schema validator fails.
 *
 * Only trusted server code calls this. Counts are clamped at zero so a retry
 * or an operational replay can never create negative usage.
 */
export async function refundQuota(
  db: Firestore,
  uid: string,
  now: Date,
  task: AiTaskType,
): Promise<QuotaResult> {
  const ref = usageRef(db, uid, now);
  return db.runTransaction(async (tx) => {
    const usage = ((await tx.get(ref)).data() ?? {}) as UsageDoc;
    const used = usage.count ?? 0;
    const usedByTask = usage.byTask?.[task] ?? 0;
    const next = Math.max(0, used - 1);
    const nextByTask = Math.max(0, usedByTask - 1);

    if (next !== used || nextByTask !== usedByTask) {
      tx.set(
        ref,
        {
          count: next,
          byTask: { [task]: nextByTask },
          updatedAt: now.toISOString(),
        },
        { merge: true },
      );
    }
    return {
      allowed: true,
      remaining: Math.min(DAILY_QUOTA - next, TASK_DAILY_LIMITS[task] - nextByTask),
    };
  });
}

/** Tokens per UTC day across all accounts before the AI pauses itself. */
export const DEFAULT_DAILY_TOKEN_BUDGET = 2_000_000;

export interface AiConfig {
  enabled: boolean;
  dailyTokenBudget: number;
}

/**
 * Server-side switches (master prompt §13.4), read from `config/edgeFuelAi`
 * so they change without a redeploy:
 * - `enabled: false` turns the AI off.
 * - `dailyTokenBudget` caps total tokens per UTC day (see usage.ts).
 * A missing doc means enabled with the default budget, so a first deploy
 * needs no extra setup.
 */
export async function readAiConfig(db: Firestore): Promise<AiConfig> {
  const data = (await db.collection("config").doc("edgeFuelAi").get()).data();
  const budget = data?.dailyTokenBudget;
  return {
    enabled: data?.enabled !== false,
    dailyTokenBudget:
      typeof budget === "number" && Number.isFinite(budget) && budget > 0
        ? budget
        : DEFAULT_DAILY_TOKEN_BUDGET,
  };
}
