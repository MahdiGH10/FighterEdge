import { Firestore } from "firebase-admin/firestore";

/**
 * Per-user daily quota (master prompt §13.4). The quota is deliberately
 * conservative and applies after the server-owned entitlement gate. Premium
 * users can be given a higher tier later without moving this trust boundary.
 */
export const DAILY_QUOTA = 20;

export interface QuotaResult {
  allowed: boolean;
  remaining: number;
}

function todayKey(now: Date): string {
  return now.toISOString().slice(0, 10); // YYYY-MM-DD (UTC)
}

/** Atomically checks and increments today's usage in one transaction. */
export async function consumeQuota(
  db: Firestore,
  uid: string,
  now: Date,
): Promise<QuotaResult> {
  const ref = db
    .collection("users")
    .doc(uid)
    .collection("aiUsage")
    .doc(todayKey(now));

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const used = (snap.data()?.count as number | undefined) ?? 0;

    if (used >= DAILY_QUOTA) {
      return { allowed: false, remaining: 0 };
    }

    tx.set(
      ref,
      { count: used + 1, updatedAt: now.toISOString() },
      { merge: true },
    );
    return { allowed: true, remaining: DAILY_QUOTA - used - 1 };
  });
}

/**
 * Server-side kill switch (master prompt §13.4). Reads a single config doc
 * so the AI feature can be disabled without a redeploy. Defaults to enabled
 * if the doc is missing, so first deploy doesn't require extra setup.
 */
export async function isAiEnabled(db: Firestore): Promise<boolean> {
  const snap = await db.collection("config").doc("edgeFuelAi").get();
  const enabled = snap.data()?.enabled;
  return enabled !== false;
}
