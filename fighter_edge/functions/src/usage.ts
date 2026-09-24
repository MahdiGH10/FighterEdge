/**
 * AI usage totals per UTC day, across all accounts (audit D-8). They show
 * what the AI costs, and they back the daily token budget that pauses the AI
 * when something goes wrong (a bug in a client loop, abuse, a price change).
 *
 * `aiStats/{YYYY-MM-DD}` holds counts only: no account IDs, prompts or
 * answers. Clients can't read or write it (the rules' catch-all denies it).
 * One document per day takes about one write per second sustained; shard it
 * if traffic ever gets near that.
 */
import { FieldValue, Firestore } from "firebase-admin/firestore";

import { AiTaskType } from "./types";

/** What one model call used, as OpenRouter reports it. */
export interface ModelUsage {
  promptTokens: number;
  completionTokens: number;
  /** In USD. OpenRouter includes it when the request asks for usage. */
  costUsd: number;
}

export const NO_USAGE: ModelUsage = { promptTokens: 0, completionTokens: 0, costUsd: 0 };

function count(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) && value > 0 ? value : 0;
}

/** Reads the `usage` block of an OpenRouter response; missing parts are 0. */
export function parseUsage(body: unknown): ModelUsage {
  const usage = (body as { usage?: Record<string, unknown> } | null)?.usage;
  if (!usage || typeof usage !== "object") return NO_USAGE;
  return {
    promptTokens: count(usage.prompt_tokens),
    completionTokens: count(usage.completion_tokens),
    costUsd: count(usage.cost),
  };
}

export function addUsage(a: ModelUsage, b: ModelUsage): ModelUsage {
  return {
    promptTokens: a.promptTokens + b.promptTokens,
    completionTokens: a.completionTokens + b.completionTokens,
    costUsd: a.costUsd + b.costUsd,
  };
}

function statsRef(db: Firestore, now: Date) {
  return db.collection("aiStats").doc(now.toISOString().slice(0, 10));
}

/**
 * Adds one AI request to today's totals: the model calls it made (a retry is
 * a second call), the tokens and cost, and whether an answer reached the
 * athlete.
 */
export async function recordUsage(
  db: Firestore,
  now: Date,
  entry: {
    task: AiTaskType;
    modelCalls: number;
    usage: ModelUsage;
    answered: boolean;
  },
): Promise<void> {
  const tokens = entry.usage.promptTokens + entry.usage.completionTokens;
  await statsRef(db, now).set(
    {
      requests: FieldValue.increment(1),
      answered: FieldValue.increment(entry.answered ? 1 : 0),
      modelCalls: FieldValue.increment(entry.modelCalls),
      promptTokens: FieldValue.increment(entry.usage.promptTokens),
      completionTokens: FieldValue.increment(entry.usage.completionTokens),
      totalTokens: FieldValue.increment(tokens),
      costUsd: FieldValue.increment(entry.usage.costUsd),
      byTask: { [entry.task]: FieldValue.increment(1) },
      updatedAt: now.toISOString(),
    },
    { merge: true },
  );
}

/** Whether today's tokens, across all accounts, have reached [budget]. */
export async function dailyBudgetReached(
  db: Firestore,
  now: Date,
  budget: number,
): Promise<boolean> {
  const used = (await statsRef(db, now).get()).data()?.totalTokens;
  return typeof used === "number" && used >= budget;
}
